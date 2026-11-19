import Foundation
import Testing
@testable import OpenPaperKit

@Suite struct ArchiveTests {
    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func story(_ title: String, _ category: StoryCategory = .news, published: String? = nil) -> Story {
        Story(
            category: category, priority: .normal, title: title, summary: "s", slug: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            publishedAt: published.map(date)
        )
    }

    /// Saves the items, places each in the given issues, and publishes the listed issues.
    private func setUp(_ db: PaperDatabase, placements: [(id: UUID, issues: [String])], published: [String]) throws {
        for (id, issues) in placements {
            for issue in issues { try db.place(id, inIssue: issue) }
        }
        for issue in published { try db.publish(issue: issue, mode: .prominent) }
    }

    @Test func storiesAreNewestFirstByTheirOwnDateThenTheirIssue() throws {
        let db = try PaperDatabase()
        let old = story("Old", published: "2026-11-18T08:00:00Z")
        let newest = story("Newest", published: "2026-11-20T06:00:00Z")
        let undated = story("Undated")                      // follows its issue: 19 November
        for s in [old, newest, undated] { try db.save(s, body: "") }
        try setUp(db, placements: [(old.id, ["2026-11-19"]), (newest.id, ["2026-11-19"]), (undated.id, ["2026-11-19"])],
                  published: ["2026-11-19"])

        #expect(try db.publishedItems().stories.map(\.title) == ["Newest", "Undated", "Old"])
    }

    @Test func draftsAndTheInboxNeverAppear() throws {
        let db = try PaperDatabase()
        let live = story("Live"), draft = story("Draft"), inbox = story("Inbox")
        for s in [live, draft, inbox] { try db.save(s, body: "") }
        try setUp(db, placements: [(live.id, ["2026-11-19"]), (draft.id, ["2026-11-20"])], published: ["2026-11-19"])

        #expect(try db.publishedItems().stories.map(\.title) == ["Live"])
    }

    @Test func anItemInSeveralIssuesAppearsOnce() throws {
        let db = try PaperDatabase()
        let s = story("Repeated")
        try db.save(s, body: "")
        try setUp(db, placements: [(s.id, ["2026-11-19", "2026-11-20"])], published: ["2026-11-19", "2026-11-20"])
        #expect(try db.publishedItems().stories.count == 1)
    }

    @Test func unpublishedIssueDoesNotRevealItsItemsEvenIfAnotherIssueIsPublished() throws {
        let db = try PaperDatabase()
        let s = story("Only in draft")
        let other = story("Elsewhere")
        try db.save(s, body: ""); try db.save(other, body: "")
        try setUp(db, placements: [(s.id, ["2026-11-20"]), (other.id, ["2026-11-19"])], published: ["2026-11-19"])
        #expect(try db.publishedItems().stories.map(\.title) == ["Elsewhere"])
    }

    @Test func agendaFollowsEventDateAndQuotesFollowTheirIssue() throws {
        let db = try PaperDatabase()
        let soon = AgendaPoint(subject: "Soon", place: "p", link: "https://x", summary: "s", eventDate: date("2026-12-01T10:00:00Z"))
        let later = AgendaPoint(subject: "Later", place: "p", link: "https://x", summary: "s", eventDate: date("2026-12-20T10:00:00Z"))
        let q1 = QuotedItem(quote: "first", speaker: "A", context: "c", sourceLink: "https://x")
        let q2 = QuotedItem(quote: "second", speaker: "B", context: "c", sourceLink: "https://x")
        try db.save(soon); try db.save(later); try db.save(q1); try db.save(q2)
        try setUp(db, placements: [(soon.id, ["2026-11-19"]), (later.id, ["2026-11-19"]), (q1.id, ["2026-11-19"]), (q2.id, ["2026-11-21"])],
                  published: ["2026-11-19", "2026-11-21"])

        let items = try db.publishedItems()
        #expect(items.agendaPoints.map(\.subject) == ["Later", "Soon"])
        #expect(items.quotedItems.map(\.quote) == ["second", "first"])
    }

    @Test func advertisementsAreNotPartOfTheArchive() throws {
        let db = try PaperDatabase()
        let ad = Advertisement(sponsorName: "V", imageSource: .endpoint(url: "/a"), altText: "a", targetURL: "https://x")
        try db.save(ad)
        try setUp(db, placements: [(ad.id, ["2026-11-19"])], published: ["2026-11-19"])
        let items = try db.publishedItems()
        #expect(items.stories.isEmpty && items.agendaPoints.isEmpty && items.quotedItems.isEmpty)
    }

    // MARK: Pages

    @Test func sectionPagesShowOnlyTheirOwnCategoryInTheGivenOrder() throws {
        let db = try PaperDatabase()
        let n1 = story("News One", .news, published: "2026-11-20T06:00:00Z")
        let n2 = story("News Two", .news, published: "2026-11-18T06:00:00Z")
        let op = story("Opinion One", .opinion, published: "2026-11-19T06:00:00Z")
        for s in [n1, n2, op] { try db.save(s, body: "") }
        try setUp(db, placements: [(n1.id, ["2026-11-20"]), (n2.id, ["2026-11-20"]), (op.id, ["2026-11-20"])], published: ["2026-11-20"])

        let items = try db.publishedItems()
        let metadata = try db.issue(on: "2026-11-20").metadata
        func html(_ section: PaperSection) -> String {
            SectionPage(metadata: metadata, section: section, stories: items.stories,
                        agendaPoints: items.agendaPoints, quotedItems: items.quotedItems).render()
        }

        let news = html(.news)
        #expect(news.contains("News One") && news.contains("News Two") && !news.contains("Opinion One"))
        #expect(news.range(of: "News One")!.lowerBound < news.range(of: "News Two")!.lowerBound)   // newest first
        let opinion = html(.opinion)
        #expect(opinion.contains("Opinion One") && !opinion.contains("News One"))
    }

    @Test func everyMastheadLinkLeadsToARealSection() {
        for section in PaperSection.allCases where section != .frontPage {
            #expect(section.href == "/sections/\(section.rawValue)")
            #expect(PaperSection(rawValue: section.rawValue) == section)
        }
    }
}
