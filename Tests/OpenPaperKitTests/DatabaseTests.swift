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
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            image: StoryImage(
                source: .blob(data: Data([1, 2, 3]), mimeType: "image/png"),
                altText: "alt",
                caption: "cap",
                credit: nil
            )
        )
    }

    @Test func storyRoundTripsWithImageAndBody() throws {
        let db = try PaperDatabase()
        let story = sampleStory()
        #expect(try db.save(story, body: "Hello **world**") == .inserted)

        let loaded = try db.queue.read { try Story.fetchOne($0) }
        #expect(loaded?.id == story.id)
        #expect(loaded?.title == "A story")
        #expect(loaded?.priority == .high)
        #expect(loaded?.publishedAt == story.publishedAt)
        guard case .blob(let data, let mime)? = loaded?.image?.source else {
            Issue.record("image source lost"); return
        }
        #expect(data == Data([1, 2, 3]) && mime == "image/png")
        #expect(try db.body(ofStory: story.id) == "Hello **world**")
    }

    @Test func reuploadWithSameSlugUpdatesInsteadOfDuplicating() throws {
        let db = try PaperDatabase()
        let first = sampleStory(title: "First")
        try db.save(first, body: "one")
        let outcome = try db.save(sampleStory(title: "Second"), body: "two")   // new random id, same slug

        #expect(outcome == .updated)
        let all = try db.queue.read { try Story.fetchAll($0) }
        #expect(all.count == 1)
        #expect(all[0].id == first.id)
        #expect(all[0].title == "Second")
        #expect(try db.body(ofStory: first.id) == "two")
        #expect(try db.inbox().count == 1)
    }

    @Test func inboxHoldsUnplacedItemsOfEveryKind() throws {
        let db = try PaperDatabase()
        let story = sampleStory()
        try db.save(story, body: "")
        try db.save(AgendaPoint(subject: "Rate decision", place: "Frankfurt", link: "https://x", summary: "s"))
        try db.save(QuotedItem(quote: "q", speaker: "Lindeman", context: "c", sourceLink: "https://x"))
        try db.save(Advertisement(sponsorName: "Vacheron", imageSource: .endpoint(url: "/a.webp"), altText: "a", targetURL: "https://x"))

        let inbox = try db.inbox()
        #expect(inbox.count == 4)
        #expect(Set(inbox.map(\.kind)) == [.story, .agendaPoint, .quotedItem, .advertisement])
        #expect(Set(inbox.map(\.title)) == ["A story", "Rate decision", "Lindeman", "Vacheron"])
    }

    @Test func placingAnItemTakesItOutOfTheInbox() throws {
        let db = try PaperDatabase()
        let story = sampleStory()
        try db.save(story, body: "")
        try db.save(sampleStory(slug: "other", title: "Other"), body: "")

        try db.place(story.id, inIssue: "2026-11-20")
        try db.place(story.id, inIssue: "2026-11-21")   // one item, two issues
        #expect(try db.inbox().map(\.title) == ["Other"])
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
