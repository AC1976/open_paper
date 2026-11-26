import Elementary
import Foundation
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

/// Largest upload request the editor accepts (a markdown file plus one image).
let maxRequestBytes = 20 * 1024 * 1024

/// The editor.
///
///     GET  /editor                          news desk: submissions, upload form, filed and rejected
///     POST /editor/uploads                  read the file, stage it, redirect to review
///     ...  /editor/uploads/{id}             review an upload (see "item pages" below)
///     ...  /editor/items/{id}               edit a saved item (see "item pages" below)
///     POST /editor/items/{id}/file          save it and give it a publish date
///                                           (advertisements: a first and last day)
///     POST /editor/items/{id}/reject        reject it
///     POST /editor/items/{id}/desk          take it back to the news desk
///     GET  /editor/issues                   open an edition (today, or ?date=yyyy-MM-dd)
///     GET  /editor/issues/{date}            what is filed for that date, and its layout
///     POST /editor/issues/{date}/mode       set the layout (breaking, prominent, regular)
///     GET  /editor/issues/{date}/preview    the paper of that date, future dates included
///
/// Item pages, under both prefixes above:
///
///     GET  {prefix}           the review / edit page
///     POST {prefix}           save
///     POST {prefix}/preview   re-render a story with the edited fields (not saved)
///     POST {prefix}/cancel    discard the upload / leave the edit
func addEditorRoutes(to router: some RouterMethods<AppRequestContext>, database: PaperDatabase) {

    // MARK: Home and uploads

    router.get("/editor") { request, context -> Response in
        try page(of: try homePage(database), request, context)
    }

    router.post("/editor/uploads") { request, context -> Response in
        let form = try await readForm(request)

        func reject(_ message: String) throws -> Response {
            try page(of: try homePage(database, problems: [message]), request, context, status: .unprocessableContent)
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
            base: "/editor/uploads/\(id.uuidString)",
            returnTo: "/editor",
            heading: "Review \(staged.kind.label.lowercased())",
            original: parsed,
            stagedID: id
        )
    }

    // A saved item. Save and Cancel go back to where it lives now.
    let savedItem: @Sendable (AppRequestContext) throws -> ItemTarget = { context in
        let id = try context.parameters.require("id", as: UUID.self)
        guard let item = try database.item(id), let entry = try database.entry(id) else {
            throw HTTPError(.notFound, message: "This item was not found.")
        }
        return ItemTarget(
            base: "/editor/items/\(id.uuidString)",
            returnTo: entry.publishDate.map { "/editor/issues/\($0)" } ?? "/editor",
            heading: "Edit \(item.kind.label.lowercased())",
            original: item,
            stagedID: nil,
            filing: Filing(
                status: entry.status, publishDate: entry.publishDate,
                suggestedDate: EditorDates.today(), contributor: entry.contributor,
                takesRange: entry.kind == .advertisement, publishUntil: entry.publishUntil
            ),
            picture: try database.picture(ofItem: id)
        )
    }
    addItemRoutes(to: router, prefix: "/editor/items/:id", database: database, resolve: savedItem)

    // MARK: Filing

    router.post("/editor/items/:id/file") { request, context -> Response in
        let target = try savedItem(context)
        let form = try await readForm(request)
        let date = form.text("publishDate") ?? ""
        // Only the advertisement's edit page sends a last day.
        let until = form.text("publishUntil")
        do {
            // Check the dates first, so a bad date saves nothing.
            try PaperDatabase.checkRun(from: date, until: until)
            try save(form, for: target, in: database)
            try database.file(target.original.id, on: date, until: until)
            return .redirect(to: "/editor/issues/\(date)")
        } catch let problems as FormProblems {
            return try render(target, request, context, problems: problems.messages)
        } catch let error as SaveError {
            return try render(target, request, context, problems: [error.description])
        }
    }

    router.post("/editor/items/:id/reject") { _, context -> Response in
        try database.reject(try context.parameters.require("id", as: UUID.self))
        return .redirect(to: "/editor")
    }

    router.post("/editor/items/:id/desk") { _, context -> Response in
        try database.returnToDesk(try context.parameters.require("id", as: UUID.self))
        return .redirect(to: "/editor")
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

/// What an item page is working on: where it posts, where it returns to, and
/// the item's current values.
private struct ItemTarget: Sendable {
    let base: String
    let returnTo: String
    let heading: String
    let original: ParsedUpload
    /// Set when the item is an upload that has not been saved yet.
    let stagedID: UUID?
    /// Set when the item is saved, so it can be filed.
    var filing: Filing? = nil
    /// A story's current picture.
    var picture: Picture? = nil
}

/// Validates the submitted fields and saves the item.
private func save(_ form: MultipartForm, for target: ItemTarget, in database: PaperDatabase) throws {
    let edited: ParsedUpload
    var picture = PictureChange.unchanged
    switch target.original {
    case .story(let original, _, _):
        let result = try StoryForm.story(from: form, keeping: original, hasPicture: target.picture != nil)
        edited = .story(result.story, markdown: result.body, html: "")
        picture = result.picture
    case .agendaPoint:
        edited = .agendaPoint(try ItemForm.agendaPoint(from: form))
    case .quotedItem:
        edited = .quotedItem(try ItemForm.quotedItem(from: form))
    case .advertisement(let original):
        edited = .advertisement(try ItemForm.advertisement(from: form, keeping: original))
    }
    // An upload becomes a new item; only an edit page changes an existing one.
    if let staged = target.stagedID {
        let new: NewPicture? = if case .replace(let chosen) = picture { chosen } else { nil }
        try database.submit(edited, picture: new, discarding: staged)
    } else {
        try database.update(edited, id: target.original.id, picture: picture)
    }
}

private func addItemRoutes(
    to router: some RouterMethods<AppRequestContext>,
    prefix: String,
    database: PaperDatabase,
    resolve: @escaping @Sendable (AppRequestContext) throws -> ItemTarget
) {
    router.get(RouterPath(prefix)) { request, context -> Response in
        try render(try resolve(context), request, context)
    }

    router.post(RouterPath(prefix)) { request, context -> Response in
        let target = try resolve(context)
        let form = try await readForm(request)
        do {
            try save(form, for: target, in: database)
            return .redirect(to: target.returnTo)
        } catch let problems as FormProblems {
            return try render(target, request, context, problems: problems.messages)
        } catch let error as SaveError {
            return try render(target, request, context, problems: [error.description])
        }
    }

    router.post(RouterPath(prefix + "/preview")) { request, context -> Response in
        let target = try resolve(context)
        guard case .story(let original, _, _) = target.original else {
            return .redirect(to: target.base)
        }
        let form = try await readForm(request)
        do {
            let result = try StoryForm.story(from: form, keeping: original, hasPicture: target.picture != nil)
            return try page(
                of: ReviewCard(
                    story: result.story, markdown: result.body, bodyHTML: markdownToHTML(result.body),
                    actionBase: target.base, heading: target.heading, backHref: target.returnTo,
                    filing: target.filing, picture: result.picture.applied(to: target.picture)
                ),
                request, context
            )
        } catch let problems as FormProblems {
            return try render(target, request, context, problems: problems.messages)
        }
    }

    router.post(RouterPath(prefix + "/cancel")) { _, context -> Response in
        let target = try resolve(context)
        if let id = target.stagedID { try database.discardStaged(id) }
        return .redirect(to: target.returnTo)
    }
}

private func render(
    _ target: ItemTarget,
    _ request: Request,
    _ context: AppRequestContext,
    problems: [String] = []
) throws -> Response {
    let status: HTTPResponse.Status = problems.isEmpty ? .ok : .unprocessableContent
    switch target.original {
    case .story(let story, let markdown, let html):
        return try page(
            of: ReviewCard(
                story: story, markdown: markdown, bodyHTML: html, actionBase: target.base,
                problems: problems, heading: target.heading, backHref: target.returnTo, filing: target.filing,
                picture: target.picture
            ),
            request, context, status: status
        )
    default:
        return try page(
            of: ItemEditPage(
                parsed: target.original, actionBase: target.base, heading: target.heading,
                backHref: target.returnTo, problems: problems, filing: target.filing
            ),
            request, context, status: status
        )
    }
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

private func homePage(_ database: PaperDatabase, problems: [String] = []) throws -> EditorHomePage {
    EditorHomePage(
        desk: try database.newsDesk(),
        waiting: try database.stagedUploads(),
        filed: try database.filedItems(),
        rejected: try database.rejectedItems(),
        problems: problems
    )
}

func readForm(_ request: Request, limit: Int = maxRequestBytes) async throws -> MultipartForm {
    var request = request
    let body: ByteBuffer
    do {
        body = try await request.collectBody(upTo: limit)
    } catch {
        throw HTTPError(.contentTooLarge, message: "What was sent is too large.")
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
