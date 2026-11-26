import Elementary
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

/// The public contribute pages. No login; nothing sent here is visible to
/// readers until an editor files it.
///
///     GET  /contribute                      redirects to the story form
///     GET  /contribute/{kind}               the form (story, agenda or quote)
///     POST /contribute/{kind}               send it to the news desk
///     POST /contribute/{kind}/preview       the preview of what has been typed
///     POST /contribute/{kind}/load          put a filled-in template into the form
///     GET  /contribute/templates/{kind}.md  download a template
///     GET  /contribute/thanks
///
/// `trustProxy` takes the sender's address from `X-Forwarded-For`. Only set it
/// when a proxy you run is in front of the server and sets that header.
func addContributeRoutes(
    to router: some RouterMethods<AppRequestContext>,
    database: PaperDatabase,
    trustProxy: Bool
) {
    let submissions = SubmissionGuard()

    @Sendable func html(
        _ page: some HTML & Sendable, _ request: Request, _ context: AppRequestContext, status: HTTPResponse.Status = .ok
    ) -> Response {
        HTMLResponse(status: status) { page }.response(from: request, context: context)
    }

    @Sendable func kind(_ context: AppRequestContext) throws -> ContributionKind {
        guard let kind = ContributionKind(rawValue: try context.parameters.require("kind")) else {
            throw HTTPError(.notFound, message: "You can send in a story, an agenda point or a quote.")
        }
        return kind
    }

    router.get("/contribute") { _, _ -> Response in
        .redirect(to: "/contribute/story")
    }

    router.get("/contribute/thanks") { request, context -> Response in
        html(ThankYouPage(), request, context)
    }

    for option in ContributionKind.allCases {
        router.get(RouterPath("/contribute/templates/\(option.rawValue).md")) { _, _ -> Response in
            Response(
                status: .ok,
                headers: [
                    .contentType: "text/markdown; charset=utf-8",
                    .contentDisposition: "attachment; filename=\"\(option.rawValue).md\"",
                ],
                body: .init(byteBuffer: ByteBuffer(string: option.template))
            )
        }
    }

    router.get("/contribute/:kind") { request, context -> Response in
        html(ContributePage(kind: try kind(context)), request, context)
    }

    router.post("/contribute/:kind") { request, context -> Response in
        let kind = try kind(context)
        let form = try await readForm(request)
        // A robot is told all went well, so it does not try another way.
        if SubmissionGuard.isRobot(form) { return .redirect(to: "/contribute/thanks") }

        let fields = ContributionFields(form: form)
        do {
            let contribution = try ContributionForm.read(kind, fields: fields, image: form.file("imageFile")?.data)
            // Counted only for acceptable submissions, so typing mistakes cost nothing.
            guard await submissions.allow(sender(of: request, context, trustProxy: trustProxy)) else {
                return html(
                    ContributePage(kind: kind, fields: fields, problems: ["Too much has been sent in lately. Please try again in an hour."]),
                    request, context, status: .tooManyRequests
                )
            }
            try database.submit(contribution.item, from: contribution.contributor, picture: contribution.picture)
            return .redirect(to: "/contribute/thanks")
        } catch let problems as FormProblems {
            return html(
                ContributePage(kind: kind, fields: fields, problems: problems.messages),
                request, context, status: .unprocessableContent
            )
        }
    }

    router.post("/contribute/:kind/preview") { request, context -> Response in
        let kind = try kind(context)
        let fields = ContributionFields(form: try await readForm(request, limit: 400_000))
        return html(ContributionPreview(kind: kind, fields: fields), request, context)
    }

    router.post("/contribute/:kind/load") { request, context -> Response in
        let kind = try kind(context)
        let form = try await readForm(request, limit: 400_000)
        var fields = ContributionFields(form: form)

        func refuse(_ problem: String) -> Response {
            html(ContributePage(kind: kind, fields: fields, problems: [problem]), request, context, status: .unprocessableContent)
        }
        guard let file = form.file("file") else { return refuse("Choose your filled-in template.") }
        guard let text = String(data: file.data, encoding: .utf8) else { return refuse("That is not a text file.") }
        do {
            fields.fill(from: try ParsedUpload(kind: kind.itemKind, text: text, name: file.filename ?? "template.md"))
        } catch let error as SubmissionError {
            return refuse(error.description)
        } catch let error as UploadError {
            return refuse(error.description)
        } catch {
            return refuse("The file could not be read. Check that it still looks like the \(kind.label.lowercased()) template.")
        }
        return html(
            ContributePage(kind: kind, fields: fields, notice: "Loaded. Check the fields, then send it to the editors. Nothing has been sent yet."),
            request, context
        )
    }
}

/// The network address used to limit how much one sender can submit.
private func sender(of request: Request, _ context: AppRequestContext, trustProxy: Bool) -> String {
    if trustProxy, let header = HTTPField.Name("X-Forwarded-For"), let forwarded = request.headers[header],
       // The last entry is the one our own proxy added.
       let last = forwarded.split(separator: ",").last {
        return last.trimmingCharacters(in: .whitespaces)
    }
    return context.remoteAddress ?? "unknown"
}
