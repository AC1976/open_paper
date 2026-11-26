import Foundation
import Testing
@testable import OpenPaperKit

@Suite struct ArchiveTests {
    private func story(_ title: String, _ category: StoryCategory = .news) -> Story {
        Story(category: category, priority: .normal, title: title, summary: "s",
              slug: title.lowercased().replacingOccurrences(of: " ", with: "-"))
    }

    @Test func storiesAreNewestFirstByPublishDate() throws {
        let db = try PaperDatabase()
        let old = story("Old"), newest = story("Newest"), middle = story("Middle")
        for s in [old, newest, middle] { try db.save(s, body: "") }
        try db.file(old.id, on: "2026-11-18")
        try db.file(newest.id, on: "2026-11-20")
        try db.file(middle.id, on: "2026-11-19")
        #expect(try db.publishedItems(asOf: "2026-11-20").stories.map(\.title) == ["Newest", "Middle", "Old"])
    }

    @Test func futureRejectedAndDeskItemsNeverAppear() throws {
        let db = try PaperDatabase()
        let live = story("Live"), future = story("Future"), rejected = story("Rejected"), desk = story("Desk")
        for s in [live, future, rejected, desk] { try db.save(s, body: "") }
        try db.file(live.id, on: "2026-11-19")
        try db.file(future.id, on: "2026-11-21")
        try db.reject(rejected.id)

        #expect(try db.publishedItems(asOf: "2026-11-20").stories.map(\.title) == ["Live"])
        #expect(try db.publishedItems(asOf: "2026-11-21").stories.map(\.title) == ["Future", "Live"])
    }

    @Test func agendaFollowsEventDateAndQuotesTheirPublishDate() throws {
        let db = try PaperDatabase()
        let iso = ISO8601DateFormatter()
        let soon = AgendaPoint(subject: "Soon", place: "p", link: "https://x", summary: "s", eventDate: iso.date(from: "2026-12-01T10:00:00Z"))
        let later = AgendaPoint(subject: "Later", place: "p", link: "https://x", summary: "s", eventDate: iso.date(from: "2026-12-20T10:00:00Z"))
        let q1 = QuotedItem(quote: "first", speaker: "A", context: "c", sourceLink: "https://x")
        let q2 = QuotedItem(quote: "second", speaker: "B", context: "c", sourceLink: "https://x")
        let ad = Advertisement(sponsorName: "V", imageSource: .endpoint(url: "/a"), altText: "a", targetURL: "https://x")
        try db.save(soon); try db.save(later); try db.save(q1); try db.save(q2); try db.save(ad)
        for id in [soon.id, later.id, q1.id, ad.id] { try db.file(id, on: "2026-11-19") }
        try db.file(q2.id, on: "2026-11-20")

        let items = try db.publishedItems(asOf: "2026-11-20")
        #expect(items.agendaPoints.map(\.subject) == ["Later", "Soon"])
        #expect(items.quotedItems.map(\.quote) == ["second", "first"])
        #expect(items.stories.isEmpty)
    }

    // MARK: Pages

    @Test func sectionPagesShowOnlyTheirOwnCategoryInTheGivenOrder() throws {
        let db = try PaperDatabase()
        let n1 = story("News One"), n2 = story("News Two"), op = story("Opinion One", .opinion)
        for s in [n1, n2, op] { try db.save(s, body: "") }
        try db.file(n1.id, on: "2026-11-20"); try db.file(n2.id, on: "2026-11-18"); try db.file(op.id, on: "2026-11-19")

        let items = try db.publishedItems(asOf: "2026-11-20")
        let metadata = try db.issue(on: "2026-11-20").metadata
        func html(_ section: PaperSection) -> String {
            SectionPage(metadata: metadata, section: section, stories: items.stories,
                        agendaPoints: items.agendaPoints, quotedItems: items.quotedItems).render()
        }

        let news = html(.news)
        #expect(news.contains("News One") && news.contains("News Two") && !news.contains("Opinion One"))
        #expect(news.range(of: "News One")!.lowerBound < news.range(of: "News Two")!.lowerBound)
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
