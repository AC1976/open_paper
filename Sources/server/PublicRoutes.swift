import Elementary
import Foundation
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

/// The paper itself, built from the issues the editor has published.
///
///     GET /                 the issue published most recently
///     GET /issues/{date}    a published issue, e.g. /issues/2026-11-20
///     GET /sections/{name}  everything published in a section, newest first:
///                           news, background, opinion, agenda or quoted
func addPublicRoutes(to router: Router<BasicRequestContext>, database: PaperDatabase) {
    addSectionRoutes(to: router, database: database)

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

/// The route for each section is the one the masthead links to (`PaperSection.href`).
private func addSectionRoutes(to router: Router<BasicRequestContext>, database: PaperDatabase) {
    router.get("/sections/:name") { request, context -> Response in
        let name = try context.parameters.require("name")
        guard let section = PaperSection(rawValue: name) else {
            throw HTTPError(.notFound, message: "There is no section called \"\(name)\".")
        }
        if section == .frontPage { return .redirect(to: "/") }

        // The masthead shows the date and number of the issue on the front page.
        guard let latest = try database.latestPublishedIssueDate() else {
            return HTMLResponse { NoIssuePage() }.response(from: request, context: context)
        }
        let items = try database.publishedItems()
        let page = SectionPage(
            metadata: try database.issue(on: latest).metadata,
            section: section,
            stories: items.stories,
            agendaPoints: items.agendaPoints,
            quotedItems: items.quotedItems
        )
        return HTMLResponse { page }.response(from: request, context: context)
    }
}

/// The front page of an issue. The editor also uses this to preview drafts.
func frontPage(_ issue: IssueContents, _ request: Request, _ context: BasicRequestContext) -> Response {
    let page = NYTFrontPage(metadata: issue.metadata, plan: issue.plan)
    return HTMLResponse { page }.response(from: request, context: context)
}
