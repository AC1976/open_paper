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
    let tooLarge = "Wat je verstuurde is te groot."

    @Sendable func html(
        _ page: some HTML & Sendable, _ request: Request, _ context: AppRequestContext, status: HTTPResponse.Status = .ok
    ) -> Response {
        HTMLResponse(status: status) { page }.response(from: request, context: context)
    }

    @Sendable func kind(_ context: AppRequestContext) throws -> ContributionKind {
        guard let kind = ContributionKind(rawValue: try context.parameters.require("kind")) else {
            throw HTTPError(.notFound, message: "Je kunt een artikel, agendapunt of quote insturen.")
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
        let form = try await readForm(request, tooLarge: tooLarge)
        // A robot is told all went well, so it does not try another way.
        if SubmissionGuard.isRobot(form) { return .redirect(to: "/contribute/thanks") }

        let fields = ContributionFields(form: form)
        do {
            let contribution = try ContributionForm.read(kind, fields: fields, image: form.file("imageFile")?.data)
            // Counted only for acceptable submissions, so typing mistakes cost nothing.
            guard await submissions.allow(sender(of: request, context, trustProxy: trustProxy)) else {
                return html(
                    ContributePage(kind: kind, fields: fields, problems: ["Er is de laatste tijd te veel ingestuurd. Probeer het over een uur opnieuw."]),
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
        let fields = ContributionFields(form: try await readForm(request, limit: 400_000, tooLarge: tooLarge))
        return html(ContributionPreview(kind: kind, fields: fields), request, context)
    }

    router.post("/contribute/:kind/load") { request, context -> Response in
        let kind = try kind(context)
        let form = try await readForm(request, limit: 400_000, tooLarge: tooLarge)
        var fields = ContributionFields(form: form)

        func refuse(_ problem: String) -> Response {
            html(ContributePage(kind: kind, fields: fields, problems: [problem]), request, context, status: .unprocessableContent)
        }
        guard let file = form.file("file") else { return refuse("Kies je ingevulde sjabloon.") }
        guard let text = String(data: file.data, encoding: .utf8) else { return refuse("Dat is geen tekstbestand.") }
        do {
            fields.fill(from: try ParsedUpload(kind: kind.itemKind, text: text, name: file.filename ?? "template.md"))
        } catch let error as SubmissionError {
            return refuse(error.dutch)
        } catch let error as UploadError {
            return refuse(error.dutch)
        } catch {
            return refuse("Het bestand kon niet worden gelezen. Controleer of het nog op het sjabloon voor \(kind.phrase) lijkt.")
        }
        return html(
            ContributePage(kind: kind, fields: fields, notice: "Geladen. Controleer de velden en verstuur het dan naar de redactie. Er is nog niets verzonden."),
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
