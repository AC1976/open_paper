import Foundation
import Testing
@testable import OpenPaperKit

@Suite struct DatabaseTests {
    private func sampleStory(slug: String = "a-story", title: String = "A story") -> Story {
        Story(
            category: .news,
            priority: .high,
            title: title,
            summary: "Summary",
            slug: slug,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test func storyRoundTripsWithItsBody() throws {
        let db = try PaperDatabase()
        let story = sampleStory()
        #expect(try db.save(story, body: "Hello **world**") == .inserted)

        let loaded = try db.queue.read { try Story.fetchOne($0) }
        #expect(loaded?.id == story.id)
        #expect(loaded?.title == "A story")
        #expect(loaded?.priority == .high)
        #expect(loaded?.publishedAt == story.publishedAt)
        #expect(try db.body(ofStory: story.id) == "Hello **world**")
    }

    @Test func savingNeverTakesOverAnotherStorysSlug() throws {
        let db = try PaperDatabase()
        let first = sampleStory(title: "First")
        try db.save(first, body: "one")
        #expect(throws: SaveError.self) { try db.save(sampleStory(title: "Second"), body: "two") }   // new id, same slug

        let all = try db.queue.read { try Story.fetchAll($0) }
        #expect(all.map(\.title) == ["First"])
        #expect(try db.body(ofStory: first.id) == "one")
    }

    @Test func newsDeskHoldsNewItemsOfEveryKind() throws {
        let db = try PaperDatabase()
        let story = sampleStory()
        try db.save(story, body: "")
        try db.save(AgendaPoint(subject: "Rate decision", place: "Frankfurt", link: "https://x", summary: "s"))
        try db.save(QuotedItem(quote: "q", speaker: "Lindeman", context: "c", sourceLink: "https://x"))
        try db.save(Advertisement(sponsorName: "Vacheron", imageSource: .endpoint(url: "/a.webp"), altText: "a", targetURL: "https://x"))

        let inbox = try db.newsDesk()
        #expect(inbox.count == 4)
        #expect(Set(inbox.map(\.kind)) == [.story, .agendaPoint, .quotedItem, .advertisement])
        #expect(Set(inbox.map(\.title)) == ["A story", "Rate decision", "Lindeman", "Vacheron"])
    }

    @Test func filingAnItemTakesItOffTheNewsDesk() throws {
        let db = try PaperDatabase()
        let story = sampleStory()
        try db.save(story, body: "")
        try db.save(sampleStory(slug: "other", title: "Other"), body: "")

        try db.file(story.id, on: "2026-11-20")
        #expect(try db.newsDesk().map(\.title) == ["Other"])
    }

    @Test func failedSaveLeavesNothingBehind() throws {
        let db = try PaperDatabase()
        // `priority`/`category` are fine, but a duplicate slug on a *different* id
        // through the raw record API must roll the whole transaction back.
        let a = sampleStory(slug: "dup")
        try db.save(a, body: "")
        #expect(throws: (any Error).self) {
            try db.queue.write { db in
                try db.execute(sql: "INSERT INTO items (id, kind, uploadedAt) VALUES ('X', 'story', ?)", arguments: [Date()])
                try sampleStory(slug: "dup").save(db)   // new id, same slug → UNIQUE fails
            }
        }
        let itemCount = try db.queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM items") }
        #expect(itemCount == 1)
    }
}
