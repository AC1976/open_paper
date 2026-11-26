import Elementary
import Foundation
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

/// Largest upload request the editor accepts (a markdown file plus one image).
private let maxRequestBytes = 8 * 1024 * 1024

/// The editor.
///
///     GET  /editor                                  upload form, waiting uploads, inbox
///     POST /editor/uploads                          read the file, stage it, redirect to review
///     ...  /editor/uploads/{id}                     review an upload (see "item pages" below)
///     GET  /editor/issues                           open an issue (today, or ?date=yyyy-MM-dd)
///     GET  /editor/issues/{date}                    compose it: inbox on the left, the issue on the right
///     POST /editor/issues/{date}/place              move the ticked items into the issue
///     POST /editor/issues/{date}/remove             move them back to the inbox
///     POST /editor/issues/{date}/mode               set the edition (breaking, prominent, regular)
///     POST /editor/issues/{date}/publish            publish: the issue becomes the front page
///     GET  /editor/issues/{date}/preview            the front page of the issue, draft or not
///     ...  /editor/issues/{date}/items/{id}         edit a saved item (see "item pages" below)
///
/// Item pages, under both prefixes above:
///
///     GET  {prefix}           the review / edit page
///     POST {prefix}           save
///     POST {prefix}/preview   re-render a story with the edited fields (not saved)
///     POST {prefix}/cancel    discard the upload / leave the edit
func addEditorRoutes(to router: some RouterMethods<BasicRequestContext>, database: PaperDatabase) {

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

    // A saved item, opened from an issue page (so Save and Cancel go back to that issue).
    addItemRoutes(to: router, prefix: "/editor/issues/:date/items/:id", database: database) { context in
        let date = try issueDate(context)
        let id = try context.parameters.require("id", as: UUID.self)
        guard let item = try database.item(id) else {
            throw HTTPError(.notFound, message: "This item was not found.")
        }
        return ItemTarget(
            base: "/editor/issues/\(date)/items/\(id.uuidString)",
            returnTo: "/editor/issues/\(date)",
            heading: "Edit \(item.kind.label.lowercased())",
            original: item,
            stagedID: nil
        )
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
        return try page(of: try issuePage(database, date: date), request, context)
    }

    router.post("/editor/issues/:date/place") { request, context -> Response in
        let date = try issueDate(context)
        for id in try await readForm(request).values("item").compactMap(UUID.init(uuidString:)) {
            try database.place(id, inIssue: date)
        }
        return done(request, redirectingTo: "/editor/issues/\(date)")
    }

    router.post("/editor/issues/:date/remove") { request, context -> Response in
        let date = try issueDate(context)
        for id in try await readForm(request).values("item").compactMap(UUID.init(uuidString:)) {
            try database.remove(id, fromIssue: date)
        }
        return done(request, redirectingTo: "/editor/issues/\(date)")
    }

    router.post("/editor/issues/:date/mode") { request, context -> Response in
        let date = try issueDate(context)
        guard let mode = try await readForm(request).text("mode").flatMap(EditionMode.init(rawValue:)) else {
            throw HTTPError(.badRequest, message: "Choose breaking, prominent or regular.")
        }
        try database.setMode(mode, forIssue: date)
        return done(request, redirectingTo: "/editor/issues/\(date)")
    }

    router.post("/editor/issues/:date/publish") { request, context -> Response in
        let date = try issueDate(context)
        let form = try await readForm(request)
        let mode = try form.text("mode").flatMap(EditionMode.init(rawValue:)) ?? database.settings(ofIssue: date).mode

        guard try database.publish(issue: date, mode: mode) else {
            let notPublished = try issuePage(database, date: date, problems: ["Put at least one item in the issue first."])
            return try page(of: notPublished, request, context, status: .unprocessableContent)
        }
        return .redirect(to: "/")
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
}

private func addItemRoutes(
    to router: some RouterMethods<BasicRequestContext>,
    prefix: String,
    database: PaperDatabase,
    resolve: @escaping @Sendable (BasicRequestContext) throws -> ItemTarget
) {
    router.get(RouterPath(prefix)) { request, context -> Response in
        try render(try resolve(context), request, context)
    }

    router.post(RouterPath(prefix)) { request, context -> Response in
        let target = try resolve(context)
        let form = try await readForm(request)
        do {
            switch target.original {
            case .story(let original, _, _):
                let (story, body) = try StoryForm.story(from: form, keeping: original)
                try database.save(story, body: body, discarding: target.stagedID)
            case .agendaPoint:
                try database.save(try ItemForm.agendaPoint(from: form), discarding: target.stagedID)
            case .quotedItem:
                try database.save(try ItemForm.quotedItem(from: form), discarding: target.stagedID)
            case .advertisement(let original):
                try database.save(try ItemForm.advertisement(from: form, keeping: original), discarding: target.stagedID)
            }
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
            let (story, body) = try StoryForm.story(from: form, keeping: original)
            return try page(
                of: ReviewCard(
                    story: story, markdown: body, bodyHTML: markdownToHTML(body),
                    actionBase: target.base, heading: target.heading, backHref: target.returnTo
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
    _ context: BasicRequestContext,
    problems: [String] = []
) throws -> Response {
    let status: HTTPResponse.Status = problems.isEmpty ? .ok : .unprocessableContent
    switch target.original {
    case .story(let story, let markdown, let html):
        return try page(
            of: ReviewCard(
                story: story, markdown: markdown, bodyHTML: html, actionBase: target.base,
                problems: problems, heading: target.heading, backHref: target.returnTo
            ),
            request, context, status: status
        )
    default:
        return try page(
            of: ItemEditPage(
                parsed: target.original, actionBase: target.base, heading: target.heading,
                backHref: target.returnTo, problems: problems
            ),
            request, context, status: status
        )
    }
}

// MARK: - Helpers

private func issueDate(_ context: BasicRequestContext) throws -> String {
    let date = try context.parameters.require("date")
    guard EditorDates.parseDay(date) != nil else {
        throw HTTPError(.notFound, message: "There is no issue with that date.")
    }
    return date
}

private func issuePage(_ database: PaperDatabase, date: String, problems: [String] = []) throws -> IssuePage {
    let settings = try database.settings(ofIssue: date)
    return IssuePage(
        date: date,
        inbox: try database.inbox(),
        placed: try database.placed(inIssue: date),
        mode: settings.mode,
        publishedAt: settings.publishedAt,
        problems: problems
    )
}

/// The page script saves in the background (`?fetch=1`) and wants no page back; a plain form post gets a redirect.
private func done(_ request: Request, redirectingTo path: String) -> Response {
    if request.uri.queryParameters["fetch"] != nil {
        return Response(status: .noContent)
    }
    return .redirect(to: path)
}

private func homePage(_ database: PaperDatabase, problems: [String] = []) throws -> EditorHomePage {
    EditorHomePage(inbox: try database.inbox(), waiting: try database.stagedUploads(), problems: problems)
}

func readForm(_ request: Request) async throws -> MultipartForm {
    var request = request
    let body: ByteBuffer
    do {
        body = try await request.collectBody(upTo: maxRequestBytes)
    } catch {
        throw HTTPError(.contentTooLarge, message: "The upload is larger than \(maxRequestBytes / 1024 / 1024) MB.")
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
    _ context: BasicRequestContext,
    status: HTTPResponse.Status = .ok
) throws -> Response {
    HTMLResponse(status: status) { html }.response(from: request, context: context)
}
