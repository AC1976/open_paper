import Elementary
import Foundation
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

/// Largest upload request the editor accepts (a markdown file plus one image).
let maxRequestBytes = 20 * 1024 * 1024

/// The editor.
///
///     GET  /editor                          news desk; ?folder=published or archive
///     POST /editor/uploads                  read the file, stage it, redirect to review
///     ...  /editor/uploads/{id}             review an upload (see "item pages" below)
///     ...  /editor/items/{id}               the news desk with this item open (see below)
///     POST /editor/items/{id}/file          save it and give it a publish date
///                                           (advertisements: a first and last day)
///     POST /editor/items/{id}/archive       take it out of the paper
///     POST /editor/items/{id}/desk          take it back to the news desk
///     GET  /editor/issues                   open an edition (today, or ?date=yyyy-MM-dd)
///     GET  /editor/issues/{date}            what is filed for that date, and its layout
///     POST /editor/issues/{date}/mode       set the layout (breaking, prominent, regular)
///     GET  /editor/issues/{date}/preview    the paper of that date, future dates included
///
/// Item pages, under both prefixes above:
///
///     GET  {prefix}           the news desk with the item open
///     POST {prefix}           save
///     POST {prefix}/preview   show the item with the edited fields (not saved)
///     POST {prefix}/cancel    discard an upload
func addEditorRoutes(to router: some RouterMethods<AppRequestContext>, database: PaperDatabase) {

    // MARK: Home and uploads

    router.get("/editor") { request, context -> Response in
        let folder = request.uri.queryParameters["folder"].flatMap { DeskFolder(rawValue: String($0)) } ?? .desk
        // Like a mail program, open the first item of the folder.
        let first = try entries(in: folder, database).first
        let target = try first.flatMap { try savedItem($0.id, database) }
        return try deskPage(
            database, request, context, folder: folder, selected: target?.deskItem(), autoSelected: true,
            notice: try notice(request, database, showing: target?.id)
        )
    }

    router.post("/editor/uploads") { request, context -> Response in
        let form = try await readForm(request)

        func reject(_ message: String) throws -> Response {
            try deskPage(database, request, context, uploadProblems: [message], status: .unprocessableContent)
        }

        guard let kind = form.text("kind").flatMap(ItemKind.init(rawValue:)) else {
            return try reject("Choose what kind of item this is.")
        }
        guard let file = form.file("file") else {
            return try reject("Choose a markdown file.")
        }
        let name = file.filename ?? "upload.md"
        guard let text = String(data: file.data, encoding: .utf8) else {
            return try reject("\(name) is not a UTF-8 text file.")
        }
        do {
            _ = try ParsedUpload(kind: kind, text: text, name: name)
        } catch {
            return try reject("\(name): \(error)")
        }

        let id = try database.stage(kind: kind, filename: name, source: text)
        return .redirect(to: "/editor/uploads/\(id.uuidString)")
    }

    // MARK: Item pages

    // An upload waiting for review.
    addItemRoutes(to: router, prefix: "/editor/uploads/:id", database: database) { context in
        let id = try context.parameters.require("id", as: UUID.self)
        guard let staged = try database.staged(id) else {
            throw HTTPError(.notFound, message: "This upload was not found. It may have been saved or cancelled.")
        }
        let parsed: ParsedUpload
        do {
            parsed = try ParsedUpload(kind: staged.kind, text: staged.source, name: staged.filename)
        } catch {
            throw HTTPError(.internalServerError, message: "\(staged.filename) could not be read again: \(error)")
        }
        return ItemTarget(
            id: id,
            base: "/editor/uploads/\(id.uuidString)",
            original: parsed,
            stagedID: id,
            received: staged.createdAt
        )
    }

    // A saved item.
    let saved: @Sendable (AppRequestContext) throws -> ItemTarget = { context in
        let id = try context.parameters.require("id", as: UUID.self)
        guard let target = try savedItem(id, database) else {
            throw HTTPError(.notFound, message: "This item was not found.")
        }
        return target
    }
    addItemRoutes(to: router, prefix: "/editor/items/:id", database: database, resolve: saved)

    // MARK: Publishing and archiving

    router.post("/editor/items/:id/file") { request, context -> Response in
        let target = try saved(context)
        let form = try await readForm(request)
        let date = form.text("publishDate") ?? ""
        // Only advertisements send a last day.
        let until = form.text("publishUntil")
        do {
            // Check the dates first, so a bad date saves nothing.
            try PaperDatabase.checkRun(from: date, until: until)
            try save(form, for: target, in: database)
            return try move(target.id, done: "published", in: database) {
                try database.file(target.id, on: date, until: until)
            }
        } catch let problems as FormProblems {
            return try render(target, database, request, context, problems: problems.messages)
        } catch let error as SaveError {
            return try render(target, database, request, context, problems: [error.description])
        }
    }

    router.post("/editor/items/:id/archive") { _, context -> Response in
        let id = try context.parameters.require("id", as: UUID.self)
        return try move(id, done: "archived", in: database) { try database.reject(id) }
    }

    router.post("/editor/items/:id/desk") { _, context -> Response in
        let id = try context.parameters.require("id", as: UUID.self)
        try database.returnToDesk(id)
        return .redirect(to: itemPath(id, done: "returned", about: id))
    }

    // MARK: Issues

    router.get("/editor/issues") { request, _ -> Response in
        let date = request.uri.queryParameters["date"].map(String.init) ?? EditorDates.today()
        guard EditorDates.parseDay(date) != nil else {
            throw HTTPError(.badRequest, message: "That is not a valid date.")
        }
        return .redirect(to: "/editor/issues/\(date)")
    }

    router.get("/editor/issues/:date") { request, context -> Response in
        let date = try issueDate(context)
        let edition = EditionPage(
            date: date,
            items: try database.filedItems(on: date),
            mode: try database.mode(ofIssue: date),
            today: EditorDates.today()
        )
        return try page(of: edition, request, context)
    }

    router.post("/editor/issues/:date/mode") { request, context -> Response in
        let date = try issueDate(context)
        guard let mode = try await readForm(request).text("mode").flatMap(EditionMode.init(rawValue:)) else {
            throw HTTPError(.badRequest, message: "Choose breaking, prominent or regular.")
        }
        try database.setMode(mode, forIssue: date)
        return done(request, redirectingTo: "/editor/issues/\(date)")
    }

    router.get("/editor/issues/:date/preview") { request, context -> Response in
        let date = try issueDate(context)
        return frontPage(try database.issue(on: date), request, context)
    }
}

// MARK: - Item pages

/// What an item page is working on: where it posts and the item's current values.
private struct ItemTarget: Sendable {
    /// The item's id, or the upload's.
    let id: UUID
    let base: String
    let original: ParsedUpload
    /// Set when the item is an upload that has not been saved yet.
    let stagedID: UUID?
    /// Set when the item is saved, so it can be published.
    var filing: Filing? = nil
    /// A story's current picture.
    var picture: Picture? = nil
    var received: Date? = nil

    func deskItem(problems: [String] = []) -> DeskItem {
        DeskItem(
            id: id, parsed: original, actionBase: base, filing: filing,
            picture: picture, received: received, problems: problems
        )
    }
}

private func savedItem(_ id: UUID, _ database: PaperDatabase) throws -> ItemTarget? {
    guard let item = try database.item(id), let entry = try database.entry(id) else { return nil }
    return ItemTarget(
        id: id,
        base: "/editor/items/\(id.uuidString)",
        original: item,
        stagedID: nil,
        filing: Filing(
            status: entry.status, publishDate: entry.publishDate,
            suggestedDate: EditorDates.today(), contributor: entry.contributor,
            takesRange: entry.kind == .advertisement, publishUntil: entry.publishUntil
        ),
        picture: try database.picture(ofItem: id),
        received: entry.uploadedAt
    )
}

/// The item as the form now describes it, and what happens to its picture.
private func edited(_ form: MultipartForm, for target: ItemTarget) throws -> (item: ParsedUpload, picture: PictureChange) {
    switch target.original {
    case .story(let original, _, _):
        let result = try StoryForm.story(from: form, keeping: original, hasPicture: target.picture != nil)
        return (.story(result.story, markdown: result.body, html: markdownToHTML(result.body)), result.picture)
    case .agendaPoint:
        return (.agendaPoint(try ItemForm.agendaPoint(from: form)), .unchanged)
    case .quotedItem:
        return (.quotedItem(try ItemForm.quotedItem(from: form)), .unchanged)
    case .advertisement(let original):
        return (.advertisement(try ItemForm.advertisement(from: form, keeping: original)), .unchanged)
    }
}

/// Validates the submitted fields and saves the item; returns its id.
@discardableResult
private func save(_ form: MultipartForm, for target: ItemTarget, in database: PaperDatabase) throws -> UUID {
    let (item, picture) = try edited(form, for: target)
    // An upload becomes a new item; only an edit page changes an existing one.
    if let staged = target.stagedID {
        let new: NewPicture? = if case .replace(let chosen) = picture { chosen } else { nil }
        return try database.submit(item, picture: new, discarding: staged)
    }
    try database.update(item, id: target.original.id, picture: picture)
    return target.original.id
}

private func addItemRoutes(
    to router: some RouterMethods<AppRequestContext>,
    prefix: String,
    database: PaperDatabase,
    resolve: @escaping @Sendable (AppRequestContext) throws -> ItemTarget
) {
    router.get(RouterPath(prefix)) { request, context -> Response in
        let target = try resolve(context)
        return try render(target, database, request, context,
                          notice: try notice(request, database, showing: target.id))
    }

    router.post(RouterPath(prefix)) { request, context -> Response in
        let target = try resolve(context)
        let form = try await readForm(request)
        do {
            let id = try save(form, for: target, in: database)
            return .redirect(to: itemPath(id, done: "saved", about: id))
        } catch let problems as FormProblems {
            return try render(target, database, request, context, problems: problems.messages)
        } catch let error as SaveError {
            return try render(target, database, request, context, problems: [error.description])
        }
    }

    router.post(RouterPath(prefix + "/preview")) { request, context -> Response in
        let target = try resolve(context)
        let form = try await readForm(request)
        do {
            let result = try edited(form, for: target)
            return try page(
                of: PreviewPage(parsed: result.item, picture: result.picture.applied(to: target.picture)),
                request, context
            )
        } catch let problems as FormProblems {
            return try page(of: PreviewPage(parsed: nil, problems: problems.messages), request, context)
        }
    }

    router.post(RouterPath(prefix + "/cancel")) { _, context -> Response in
        let target = try resolve(context)
        if let id = target.stagedID { try database.discardStaged(id) }
        return .redirect(to: "/editor")
    }
}

/// The news desk with `target` open.
private func render(
    _ target: ItemTarget,
    _ database: PaperDatabase,
    _ request: Request,
    _ context: AppRequestContext,
    problems: [String] = [],
    notice: DeskNotice? = nil
) throws -> Response {
    try deskPage(
        database, request, context,
        folder: DeskFolder(target.filing?.status ?? .submitted),
        selected: target.deskItem(problems: problems),
        notice: notice,
        status: problems.isEmpty ? .ok : .unprocessableContent
    )
}

private func deskPage(
    _ database: PaperDatabase,
    _ request: Request,
    _ context: AppRequestContext,
    folder: DeskFolder = .desk,
    selected: DeskItem? = nil,
    autoSelected: Bool = false,
    notice: DeskNotice? = nil,
    uploadProblems: [String] = [],
    status: HTTPResponse.Status = .ok
) throws -> Response {
    let desk = NewsDeskPage(
        folder: folder,
        desk: try database.newsDesk(),
        published: try database.filedItems(),
        archived: try database.rejectedItems(),
        uploads: try database.stagedUploads(),
        selected: selected,
        autoSelected: autoSelected,
        notice: notice,
        uploadProblems: uploadProblems
    )
    return try page(of: desk, request, context, status: status)
}

private func entries(in folder: DeskFolder, _ database: PaperDatabase) throws -> [DeskEntry] {
    switch folder {
    case .desk: try database.newsDesk()
    case .published: try database.filedItems()
    case .archive: try database.rejectedItems()
    }
}

/// Changes an item's status. When that takes it out of its folder, the next
/// item of the folder opens, so an editor can work down the list; otherwise
/// the item stays open.
private func move(
    _ id: UUID, done: String, in database: PaperDatabase, _ change: () throws -> Void
) throws -> Response {
    guard let before = try database.entry(id) else {
        throw HTTPError(.notFound, message: "This item was not found.")
    }
    let folder = DeskFolder(before.status)
    let list = try entries(in: folder, database)
    try change()
    guard let after = try database.entry(id), DeskFolder(after.status) != folder else {
        return .redirect(to: itemPath(id, done: done, about: id))
    }
    let index = list.firstIndex { $0.id == id } ?? 0
    let others = list.filter { $0.id != id }
    if others.isEmpty {
        let query = folder == .desk ? "" : "folder=\(folder.rawValue)&"
        return .redirect(to: "/editor?\(query)done=\(done)&item=\(id.uuidString)")
    }
    return .redirect(to: itemPath(others[min(index, others.count - 1)].id, done: done, about: id))
}

private func itemPath(_ id: UUID, done: String, about: UUID) -> String {
    "/editor/items/\(id.uuidString)?done=\(done)&item=\(about.uuidString)"
}

/// The confirmation asked for by `?done=…&item=…`. The words are made here from
/// the item itself; nothing from the address is shown.
private func notice(_ request: Request, _ database: PaperDatabase, showing: UUID?) throws -> DeskNotice? {
    let query = request.uri.queryParameters
    guard let done = query["done"].map(String.init),
          let id = query["item"].flatMap({ UUID(uuidString: String($0)) }),
          let entry = try database.entry(id)
    else { return nil }
    let name = "“\(entry.title)”"
    let text: String
    switch done {
    case "saved": text = "Saved \(name)."
    case "published" where entry.status == .filed:
        text = "\(name): " + DeskStatus.sentence(
            entry.status, publishDate: entry.publishDate, until: entry.publishUntil, today: EditorDates.today())
    case "archived" where entry.status == .rejected: text = "\(name) was archived."
    case "returned" where entry.status == .submitted: text = "\(name) is back on the news desk."
    default: return nil
    }
    return DeskNotice(text: text, link: id == showing ? nil : "/editor/items/\(id.uuidString)")
}

// MARK: - Helpers

private func issueDate(_ context: AppRequestContext) throws -> String {
    let date = try context.parameters.require("date")
    guard EditorDates.parseDay(date) != nil else {
        throw HTTPError(.notFound, message: "There is no issue with that date.")
    }
    return date
}

/// The page script saves in the background (`?fetch=1`) and wants no page back; a plain form post gets a redirect.
private func done(_ request: Request, redirectingTo path: String) -> Response {
    if request.uri.queryParameters["fetch"] != nil {
        return Response(status: .noContent)
    }
    return .redirect(to: path)
}

func readForm(
    _ request: Request, limit: Int = maxRequestBytes, tooLarge: String = "What was sent is too large."
) async throws -> MultipartForm {
    var request = request
    let body: ByteBuffer
    do {
        body = try await request.collectBody(upTo: limit)
    } catch {
        throw HTTPError(.contentTooLarge, message: tooLarge)
    }
    do {
        return try MultipartForm(body: Data(body.readableBytesView), contentType: request.headers[.contentType])
    } catch {
        throw HTTPError(.badRequest, message: "\(error)")
    }
}

private func page(
    of html: some HTML & Sendable,
    _ request: Request,
    _ context: AppRequestContext,
    status: HTTPResponse.Status = .ok
) throws -> Response {
    HTMLResponse(status: status) { html }.response(from: request, context: context)
}
