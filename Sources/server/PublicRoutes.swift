import Elementary
import Foundation
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

/// The paper itself, built from the issues the editor has published.
///
///     GET /                 the issue published most recently
///     GET /issues/{date}    a published issue, e.g. /issues/2026-11-20
func addPublicRoutes(to router: Router<BasicRequestContext>, database: PaperDatabase) {

    router.get("/") { request, context -> Response in
        guard let date = try database.latestPublishedIssueDate() else {
            return HTMLResponse { NoIssuePage() }.response(from: request, context: context)
        }
        return frontPage(try database.issue(on: date), request, context)
    }

    router.get("/issues/:date") { request, context -> Response in
        let date = try context.parameters.require("date")
        guard EditorDates.parseDay(date) != nil else {
            throw HTTPError(.notFound, message: "There is no issue with that date.")
        }
        let issue = try database.issue(on: date)
        guard issue.isPublished else {
            throw HTTPError(.notFound, message: "There is no issue with that date.")
        }
        return frontPage(issue, request, context)
    }
}

/// The front page of an issue. The editor also uses this to preview drafts.
func frontPage(_ issue: IssueContents, _ request: Request, _ context: BasicRequestContext) -> Response {
    let page = NYTFrontPage(metadata: issue.metadata, plan: issue.plan)
    return HTMLResponse { page }.response(from: request, context: context)
}
