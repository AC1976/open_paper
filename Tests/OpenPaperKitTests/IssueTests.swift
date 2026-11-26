import Foundation
import GRDB
import Testing
@testable import OpenPaperKit

private func story(_ slug: String, priority: StoryPriority = .normal) -> Story {
    Story(category: .news, priority: priority, title: slug.capitalized, summary: "s", slug: slug)
}

@Suite struct FilingTests {
    @Test func itemsMoveBetweenDeskFiledAndRejected() throws {
        let db = try PaperDatabase()
        let a = story("alpha")
        try db.save(a, body: "")
        #expect(try db.entry(a.id)?.status == .submitted)

        try db.file(a.id, on: "2026-11-20")
        #expect(try db.newsDesk().isEmpty)
        #expect(try db.filedItems().map(\.publishDate) == ["2026-11-20"])

        try db.file(a.id, on: "2026-11-22")                    // filing again moves it
        #expect(try db.filedItems(on: "2026-11-20").isEmpty)
        #expect(try db.filedItems(on: "2026-11-22").count == 1)

        try db.reject(a.id)
        #expect(try db.rejectedItems().count == 1 && db.entry(a.id)?.publishDate == nil)
        #expect(try db.filedItems().isEmpty)

        try db.returnToDesk(a.id)
        #expect(try db.newsDesk().map(\.title) == ["Alpha"])
    }

    @Test func savingAFiledItemKeepsItsDate() throws {
        let db = try PaperDatabase()
        let a = story("alpha")
        try db.save(a, body: "old")
        try db.file(a.id, on: "2026-11-20")
        try db.save(a, body: "new")
        #expect(try db.entry(a.id)?.publishDate == "2026-11-20")
    }

    @Test func deskShowsTheStoryAuthor() throws {
        let db = try PaperDatabase()
        let s = Story(category: .news, priority: .normal, title: "T", summary: "s", slug: "t", author: "Jane")
        try db.save(s, body: "")
        #expect(try db.newsDesk().first?.author == "Jane")
    }

    @Test func badDatesAndUnknownItemsAreRefused() throws {
        let db = try PaperDatabase()
        let a = story("alpha")
        try db.save(a, body: "")
        for bad in ["", "tomorrow", "2026-13-01", "2026-1-5", "2026-11-20x"] {
            #expect(throws: SaveError.self, "\(bad)") { try db.file(a.id, on: bad) }
        }
        #expect(throws: SaveError.self) { try db.file(UUID(), on: "2026-11-20") }
        #expect(try db.entry(a.id)?.status == .submitted)
    }
}

@Suite struct IssueTests {
    @Test func aDatesPaperHoldsOnlyThatDatesItems() throws {
        let db = try PaperDatabase()
        let s = story("alpha", priority: .high)
        let agenda = AgendaPoint(subject: "ECB", place: "Frankfurt", link: "https://x", summary: "s",
                                 eventDate: Date(timeIntervalSince1970: 1_800_000_000))
        let quote = QuotedItem(quote: "q", speaker: "Lindeman", context: "c", sourceLink: "https://x")
        let ad = Advertisement(sponsorName: "Vacheron", imageSource: .endpoint(url: "/a.webp"), altText: "a",
                               targetURL: "https://x", priority: .high)
        let yesterday = story("yesterday"), waiting = story("waiting")
        try db.save(s, body: "body"); try db.save(agenda); try db.save(quote); try db.save(ad)
        try db.save(yesterday, body: ""); try db.save(waiting, body: "")
        for id in [s.id, agenda.id, quote.id, ad.id] { try db.file(id, on: "2026-11-20") }
        try db.file(yesterday.id, on: "2026-11-19")

        let issue = try db.issue(on: "2026-11-20")
        #expect(issue.stories.map(\.id) == [s.id])
        #expect(issue.agendaPoints.first?.eventDate == agenda.eventDate)
        #expect(issue.quotedItems.first?.speaker == "Lindeman")
        #expect(issue.advertisements.first?.priority == .high)
        #expect(issue.number == 2)

        let html = NYTFrontPage(metadata: issue.metadata, plan: issue.plan).render()
        #expect(html.contains("Alpha") && html.contains("Lindeman") && html.contains("ECB"))
        #expect(!html.contains("Yesterday") && !html.contains("Waiting"))
    }

    @Test func theFrontPageIsTheLatestDateThatHasArrived() throws {
        let db = try PaperDatabase()
        #expect(try db.latestIssueDate(asOf: "2026-11-20") == nil)
        let a = story("alpha"), b = story("bravo")
        try db.save(a, body: ""); try db.save(b, body: "")
        try db.file(a.id, on: "2026-11-18")
        try db.file(b.id, on: "2026-11-23")

        #expect(try db.latestIssueDate(asOf: "2026-11-17") == nil)
        #expect(try db.latestIssueDate(asOf: "2026-11-20") == "2026-11-18")   // quiet days show the last paper
        #expect(try db.latestIssueDate(asOf: "2026-11-23") == "2026-11-23")   // future items appear on their day
    }

    @Test func layoutIsSetPerDate() throws {
        let db = try PaperDatabase()
        let a = story("lead", priority: .high)
        try db.save(a, body: "")
        try db.file(a.id, on: "2026-11-20")
        #expect(try db.issue(on: "2026-11-20").mode == .prominent)

        try db.setMode(.breaking, forIssue: "2026-11-20")
        #expect(try db.issue(on: "2026-11-20").plan.breakingBanner?.columnSpan == 4)
        try db.setMode(.regular, forIssue: "2026-11-20")
        #expect(try db.issue(on: "2026-11-20").plan.editorialStories.first?.columnSpan == 1)
        #expect(try db.mode(ofIssue: "2026-11-21") == .prominent)
    }

    @Test func emptyIssueStillRenders() throws {
        let issue = try PaperDatabase().issue(on: "2026-11-20")
        #expect(issue.isEmpty)
        #expect(NYTFrontPage(metadata: issue.metadata, plan: issue.plan).render().contains("Het Grootboek"))
    }

    @Test func dayParsingAcceptsOnlyRealDates() {
        #expect(EditorDates.isDay("2026-11-20"))
        for bad in ["2026-13-45", "tomorrow", "../etc", "2026-1-2"] { #expect(!EditorDates.isDay(bad), "\(bad)") }
        #expect(EditorDates.longDay("2026-11-20") == "Friday, November 20, 2026")
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
}

@Suite struct PublishDateMigrationTests {
    @Test func publishedItemsAreFiledWithTheirFirstPublishedDate() throws {
        let queue = try DatabaseQueue()
        let files = ImageFiles(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try PaperDatabase.migrator(images: files).migrate(queue, upTo: "v4-editors")
        try queue.write { db in
            for id in ["live", "draft", "loose"] {
                try db.execute(sql: "INSERT INTO items (id, kind, uploadedAt) VALUES (?, 'story', ?)", arguments: [id, Date()])
            }
            try db.execute(sql: """
                INSERT INTO issues (issueDate, publishedAt) VALUES ('2026-11-18', NULL), ('2026-11-19', '2026-11-19'),
                    ('2026-11-21', '2026-11-21');
                INSERT INTO edition_items (issueDate, itemId) VALUES
                    ('2026-11-18', 'live'), ('2026-11-21', 'live'), ('2026-11-19', 'live'), ('2026-11-18', 'draft');
                """)
        }

        try PaperDatabase.migrator(images: files).migrate(queue)

        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT id, status, publishDate FROM items ORDER BY id")
                .map { "\($0["id"] as String) \($0["status"] as String) \($0["publishDate"] as String? ?? "-")" }
        }
        // The 18th was never published, so the first *published* date is the 19th.
        #expect(rows == ["draft submitted -", "live filed 2026-11-19", "loose submitted -"])
        // Nothing is thrown away.
        #expect(try queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM edition_items") } == 4)
    }
}
