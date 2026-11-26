import Elementary
import Foundation
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

/// The paper itself, built from the items filed for each date. Nothing filed
/// for a later date is visible.
///
///     GET /                 the newest date, up to today, that has items
///     GET /issues/{date}    the paper of one date, e.g. /issues/2026-11-20
///     GET /sections/{name}  everything published in a section, newest first:
///                           news, background, opinion, agenda or quoted
///     GET /articles/{slug}  a published story
func addPublicRoutes(to router: Router<AppRequestContext>, database: PaperDatabase) {
    addSectionRoutes(to: router, database: database)
    addArticleRoutes(to: router, database: database)

    router.get("/") { request, context -> Response in
        guard let date = try database.latestIssueDate() else {
            return HTMLResponse { NoIssuePage() }.response(from: request, context: context)
        }
        return frontPage(try database.issue(on: date), request, context)
    }

    router.get("/issues/:date") { request, context -> Response in
        let date = try context.parameters.require("date")
        guard EditorDates.isDay(date), date <= EditorDates.today() else {
            throw HTTPError(.notFound, message: "There is no paper for that date.")
        }
        let issue = try database.issue(on: date)
        guard !issue.isEmpty else {
            throw HTTPError(.notFound, message: "There is no paper for that date.")
        }
        return frontPage(issue, request, context)
    }
}

/// The page behind every headline: `/articles/{slug}`. Only stories filed for
/// today or earlier can be read.
private func addArticleRoutes(to router: Router<AppRequestContext>, database: PaperDatabase) {
    router.get("/articles/:slug") { request, context -> Response in
        let slug = try context.parameters.require("slug")
        guard let (story, markdown, publishDate) = try database.publishedStory(slug: slug),
              let latest = try database.latestIssueDate()
        else {
            throw HTTPError(.notFound, message: "There is no article with that address.")
        }
        let related = try database.publishedItems().stories
            .filter { $0.category == story.category && $0.id != story.id }
            .prefix(3)
        let page = ArticlePage(
            metadata: try database.issue(on: latest).metadata,
            story: story,
            bodyHTML: markdownToHTML(markdown),
            publishDate: publishDate,
            related: Array(related)
        )
        return HTMLResponse { page }.response(from: request, context: context)
    }
}

/// The route for each section is the one the masthead links to (`PaperSection.href`).
private func addSectionRoutes(to router: Router<AppRequestContext>, database: PaperDatabase) {
    router.get("/sections/:name") { request, context -> Response in
        let name = try context.parameters.require("name")
        guard let section = PaperSection(rawValue: name) else {
            throw HTTPError(.notFound, message: "There is no section called \"\(name)\".")
        }
        if section == .frontPage { return .redirect(to: "/") }

        // The masthead shows the date and number of the issue on the front page.
        guard let latest = try database.latestIssueDate() else {
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
func frontPage(_ issue: IssueContents, _ request: Request, _ context: AppRequestContext) -> Response {
    let page = NYTFrontPage(metadata: issue.metadata, plan: issue.plan)
    return HTMLResponse { page }.response(from: request, context: context)
}
