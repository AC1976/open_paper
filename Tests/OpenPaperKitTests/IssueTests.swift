import Foundation
import Testing
@testable import OpenPaperKit

@Suite struct IssueTests {
    private func story(_ slug: String, priority: StoryPriority = .normal, category: StoryCategory = .news) -> Story {
        Story(
            category: category, priority: priority, title: slug.capitalized, summary: "s", slug: slug,
            image: StoryImage(source: .blob(data: Data([9, 8]), mimeType: "image/png"), altText: "a", caption: nil, credit: nil)
        )
    }

    @Test func positionsFollowTheOrderItemsWerePlaced() throws {
        let db = try PaperDatabase()
        let a = story("alpha"), b = story("bravo"), c = story("charlie")
        for s in [a, b, c] { try db.save(s, body: "") }

        try db.place(c.id, inIssue: "2026-11-20")
        try db.place(a.id, inIssue: "2026-11-20")
        try db.place(b.id, inIssue: "2026-11-20")
        try db.place(c.id, inIssue: "2026-11-20")   // again: keeps its position

        #expect(try db.placed(inIssue: "2026-11-20").map(\.title) == ["Charlie", "Alpha", "Bravo"])
        #expect(try db.issue(on: "2026-11-20").stories.map(\.slug) == ["charlie", "alpha", "bravo"])
    }

    @Test func removingAnItemSendsItBackToTheInbox() throws {
        let db = try PaperDatabase()
        let a = story("alpha")
        try db.save(a, body: "")
        try db.place(a.id, inIssue: "2026-11-20")
        #expect(try db.inbox().isEmpty)

        try db.remove(a.id, fromIssue: "2026-11-20")
        #expect(try db.inbox().map(\.title) == ["Alpha"])
        #expect(try db.placed(inIssue: "2026-11-20").isEmpty)
    }

    @Test func itemStaysOutOfTheInboxWhileInAnyIssue() throws {
        let db = try PaperDatabase()
        let a = story("alpha")
        try db.save(a, body: "")
        try db.place(a.id, inIssue: "2026-11-20")
        try db.place(a.id, inIssue: "2026-11-21")
        try db.remove(a.id, fromIssue: "2026-11-20")
        #expect(try db.inbox().isEmpty)
        #expect(try db.placed(inIssue: "2026-11-21").count == 1)
    }

    @Test func issueLoadsEveryKindFromTheDatabase() throws {
        let db = try PaperDatabase()
        let s = story("alpha", priority: .high)
        let agenda = AgendaPoint(subject: "ECB", place: "Frankfurt", link: "https://x", summary: "s",
                                 eventDate: Date(timeIntervalSince1970: 1_800_000_000))
        let quote = QuotedItem(quote: "q", speaker: "Lindeman", context: "c", sourceLink: "https://x")
        let ad = Advertisement(sponsorName: "Vacheron", imageSource: .endpoint(url: "/a.webp"), altText: "a",
                               targetURL: "https://x", priority: .high)
        let notPlaced = story("other")

        try db.save(s, body: "body")
        try db.save(agenda); try db.save(quote); try db.save(ad); try db.save(notPlaced, body: "")
        for id in [s.id, agenda.id, quote.id, ad.id] { try db.place(id, inIssue: "2026-11-20") }

        let issue = try db.issue(on: "2026-11-20")
        #expect(issue.stories.map(\.id) == [s.id])
        #expect(issue.stories.first?.priority == .high)
        guard case .blob(let data, _)? = issue.stories.first?.image?.source else { Issue.record("image lost"); return }
        #expect(data == Data([9, 8]))
        #expect(issue.agendaPoints.first?.subject == "ECB")
        #expect(issue.agendaPoints.first?.eventDate == agenda.eventDate)
        #expect(issue.quotedItems.first?.speaker == "Lindeman")
        #expect(issue.advertisements.first?.priority == .high)
        #expect(!issue.isEmpty)

        // The loaded issue goes straight into the page.
        let html = NYTFrontPage(metadata: issue.metadata, plan: issue.plan).render()
        #expect(html.contains("Alpha") && html.contains("Lindeman") && html.contains("ECB"))
        #expect(!html.contains("Other"))
    }

    @Test func emptyIssueStillRenders() throws {
        let db = try PaperDatabase()
        let issue = try db.issue(on: "2026-11-20")
        #expect(issue.isEmpty)
        #expect(NYTFrontPage(metadata: issue.metadata, plan: issue.plan).render().contains("Het Grootboek"))
    }

    @Test func issueNumbersCountIssueDates() throws {
        let db = try PaperDatabase()
        let a = story("alpha")
        try db.save(a, body: "")
        try db.place(a.id, inIssue: "2026-11-21")
        try db.place(a.id, inIssue: "2026-11-20")
        try db.place(a.id, inIssue: "2026-11-25")

        #expect(try db.issue(on: "2026-11-20").number == 1)
        #expect(try db.issue(on: "2026-11-21").number == 2)
        #expect(try db.issue(on: "2026-11-25").number == 3)
    }

    @Test func dayParsingAcceptsOnlyRealDates() {
        #expect(EditorDates.parseDay("2026-11-20") != nil)
        #expect(EditorDates.parseDay("2026-13-45") == nil)
        #expect(EditorDates.parseDay("tomorrow") == nil)
        #expect(EditorDates.parseDay("../etc") == nil)
        #expect(EditorDates.day(EditorDates.parseDay("2026-11-20")!) == "2026-11-20")
    }

    @Test func multipartReturnsEveryCheckedBox() throws {
        let body = Data("""
            --B\r\nContent-Disposition: form-data; name="item"\r\n\r\none\r\n\
            --B\r\nContent-Disposition: form-data; name="item"\r\n\r\ntwo\r\n\
            --B--\r\n
            """.utf8)
        let form = try MultipartForm(body: body, boundary: "B")
        #expect(form.values("item") == ["one", "two"])
        #expect(form.values("nothing").isEmpty)
    }

    // MARK: Edition mode and publishing

    @Test func newIssueIsADraftWithProminentLayout() throws {
        let db = try PaperDatabase()
        let issue = try db.issue(on: "2026-11-20")
        #expect(issue.mode == .prominent)
        #expect(!issue.isPublished)
        #expect(try db.latestPublishedIssueDate() == nil)
    }

    @Test func modeIsSavedPerIssueAndShapesTheFrontPage() throws {
        let db = try PaperDatabase()
        let lead = story("lead", priority: .high)
        try db.save(lead, body: "")
        try db.place(lead.id, inIssue: "2026-11-20")
        try db.place(lead.id, inIssue: "2026-11-21")

        try db.setMode(.breaking, forIssue: "2026-11-20")
        #expect(try db.issue(on: "2026-11-20").mode == .breaking)
        #expect(try db.issue(on: "2026-11-21").mode == .prominent)   // other issues are not affected

        // Breaking puts the lead in the banner across all columns; the others keep it in the grid.
        #expect(try db.issue(on: "2026-11-20").plan.breakingBanner?.columnSpan == 4)
        let regular = try { try db.setMode(.regular, forIssue: "2026-11-20"); return try db.issue(on: "2026-11-20").plan }()
        #expect(regular.breakingBanner == nil)
        #expect(regular.editorialStories.first?.columnSpan == 1)
        #expect(try db.issue(on: "2026-11-21").plan.editorialStories.first?.columnSpan == 2)
    }

    @Test func publishNeedsAtLeastOneItem() throws {
        let db = try PaperDatabase()
        #expect(try db.publish(issue: "2026-11-20", mode: .prominent) == false)
        #expect(try db.latestPublishedIssueDate() == nil)
    }

    @Test func publishingMakesTheIssueTheFrontPage() throws {
        let db = try PaperDatabase()
        let a = story("alpha")
        try db.save(a, body: "")
        try db.place(a.id, inIssue: "2026-11-20")
        try db.place(a.id, inIssue: "2026-11-21")

        #expect(try db.publish(issue: "2026-11-20", mode: .breaking))
        #expect(try db.latestPublishedIssueDate() == "2026-11-20")
        let published = try db.issue(on: "2026-11-20")
        #expect(published.isPublished && published.mode == .breaking)
        #expect(try db.issue(on: "2026-11-21").isPublished == false)   // still a draft

        // The most recent publication wins, whatever its date.
        Thread.sleep(forTimeInterval: 0.01)
        #expect(try db.publish(issue: "2026-11-21", mode: .regular))
        #expect(try db.latestPublishedIssueDate() == "2026-11-21")
        Thread.sleep(forTimeInterval: 0.01)
        #expect(try db.publish(issue: "2026-11-20", mode: .breaking))   // publishing again brings it back
        #expect(try db.latestPublishedIssueDate() == "2026-11-20")
    }

    @Test func settingTheModeDoesNotPublishOrUnpublish() throws {
        let db = try PaperDatabase()
        let a = story("alpha")
        try db.save(a, body: "")
        try db.place(a.id, inIssue: "2026-11-20")
        try db.setMode(.regular, forIssue: "2026-11-20")
        #expect(try db.latestPublishedIssueDate() == nil)

        try db.publish(issue: "2026-11-20", mode: .regular)
        try db.setMode(.breaking, forIssue: "2026-11-20")
        #expect(try db.issue(on: "2026-11-20").isPublished)
    }
}
