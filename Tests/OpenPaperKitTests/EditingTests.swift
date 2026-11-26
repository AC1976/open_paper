import Foundation
import Testing
@testable import OpenPaperKit

private func form(_ fields: [(String, String)], files: [(String, String, String, Data)] = []) throws -> MultipartForm {
    var body = Data()
    for (name, value) in fields {
        body += Data("--B\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)
    }
    for (name, filename, type, data) in files {
        body += Data("--B\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(type)\r\n\r\n".utf8)
        body += data + Data("\r\n".utf8)
    }
    body += Data("--B--\r\n".utf8)
    return try MultipartForm(body: body, boundary: "B")
}

private func story(slug: String = "a-story") -> Story {
    Story(category: .news, priority: .high, title: "A story", summary: "s", slug: slug)
}

private let storyFields: [(String, String)] = [
    ("category", "news"), ("priority", "2"), ("title", "T"), ("slug", "t"), ("summary", "S"), ("body", "b"),
]

@Suite struct ItemFormTests {
    @Test func agendaPointFromForm() throws {
        let id = UUID()
        let point = try ItemForm.agendaPoint(from: form([
            ("id", id.uuidString), ("subject", "ECB"), ("place", "Frankfurt"), ("link", "https://x.org"),
            ("summary", "s"), ("eventDate", "2026-12-11T14:15"),
        ]))
        #expect(point.id == id && point.subject == "ECB")
        #expect(EditorDates.dateTime(point.eventDate!) == "2026-12-11T14:15")
    }

    @Test func quoteFromForm() throws {
        let item = try ItemForm.quotedItem(from: form([
            ("quote", "q"), ("speaker", "Lindeman"), ("context", "c"), ("sourceLink", "http://x.org"),
        ]))
        #expect(item.speaker == "Lindeman")
    }

    @Test func linksMustBeWebAddresses() throws {
        for bad in ["javascript:alert(1)", "data:text/html,x", "/relative", "ftp://x"] {
            #expect(throws: FormProblems.self) {
                try ItemForm.agendaPoint(from: form([
                    ("subject", "s"), ("place", "p"), ("link", bad), ("summary", "s"),
                ]))
            }
        }
        #expect(throws: FormProblems.self) {
            try ItemForm.quotedItem(from: form([("quote", "q"), ("speaker", "s"), ("context", "c"), ("sourceLink", "javascript:x")]))
        }
    }

    @Test func missingFieldsAreAllReported() throws {
        do {
            _ = try ItemForm.quotedItem(from: form([]))
            Issue.record("should fail")
        } catch let problems as FormProblems {
            #expect(problems.messages.count == 4)   // quote, speaker, context, source link
        }
    }

    @Test func advertisementKeepsItsImageUnlessANewOneIsChosen() throws {
        let existing = Advertisement(
            sponsorName: "V", imageSource: .blob(data: Data([7]), mimeType: "image/webp"),
            altText: "a", targetURL: "https://x"
        )
        let base: [(String, String)] = [
            ("id", existing.id.uuidString), ("sponsorName", "V2"), ("targetURL", "https://y"),
            ("priority", "2"), ("image.altText", "alt"),
        ]

        let kept = try ItemForm.advertisement(from: form(base), keeping: existing)
        guard case .blob(let kept, _) = kept.imageSource else { Issue.record("image lost"); return }
        #expect(kept == Data([7]))

        let replaced = try ItemForm.advertisement(
            from: form(base, files: [("imageFile", "n.png", "image/png", TestImage.png(5))]), keeping: existing
        )
        guard case .blob(let new, let type) = replaced.imageSource else { Issue.record("no blob"); return }
        #expect(new == TestImage.png(5) && type == "image/png")
    }

    @Test func advertisementWithoutAnyImageIsRejected() throws {
        #expect(throws: FormProblems.self) {
            try ItemForm.advertisement(from: form([
                ("sponsorName", "V"), ("targetURL", "https://x"), ("priority", "1"), ("image.altText", "a"),
            ]))
        }
    }
}

@Suite struct StoryEditingTests {
    private func change(_ extra: [(String, String)], files: [(String, String, String, Data)] = []) throws -> PictureChange {
        try StoryForm.story(from: form(storyFields + extra, files: files), keeping: story(), hasPicture: true).picture
    }

    @Test func anExistingPictureIsKeptWithItsNewWords() throws {
        #expect(try change([("altText", "alt"), ("credit", "me")]) == .describe(PictureText(altText: "alt", credit: "me")))
    }

    @Test func removeTickDropsThePicture() throws {
        #expect(try change([("altText", "alt"), ("removeImage", "yes")]) == .remove)
    }

    @Test func newFileReplacesThePicture() throws {
        let result = try change([("altText", "alt")], files: [("imageFile", "n.jpg", "image/jpeg", TestImage.jpeg(9))])
        #expect(result == .replace(NewPicture(data: TestImage.jpeg(9), mimeType: "image/jpeg", text: PictureText(altText: "alt"))))
    }

    @Test func aPictureNeedsAltText() {
        #expect(throws: FormProblems.self) { try change([]) }
    }
}

@Suite struct SavedItemTests {
    @Test func savedItemsLoadBackWithTheirBody() throws {
        let db = try PaperDatabase()
        let s = story()
        try db.save(s, body: "## Hello")
        guard case .story(let loaded, let markdown, let html)? = try db.item(s.id) else { Issue.record("not found"); return }
        #expect(loaded.id == s.id && markdown == "## Hello" && html.contains("<h2>Hello</h2>"))
        #expect(try db.item(UUID()) == nil)

        let point = AgendaPoint(subject: "x", place: "p", link: "https://x", summary: "s")
        try db.save(point)
        guard case .agendaPoint(let p)? = try db.item(point.id) else { Issue.record("not found"); return }
        #expect(p.subject == "x")
    }

    @Test func editingAStoryUpdatesItInPlace() throws {
        let db = try PaperDatabase()
        let s = story()
        try db.save(s, body: "old")
        let edited = Story(id: s.id, category: .opinion, priority: .normal, title: "New title", summary: "s2", slug: "a-story")
        #expect(try db.save(edited, body: "new") == .updated)
        #expect(try db.queue.read { try Story.fetchCount($0) } == 1)
        #expect(try db.body(ofStory: s.id) == "new")
    }

    @Test func changingTheSlugToAnotherStorysSlugIsAnError() throws {
        let db = try PaperDatabase()
        let a = story(slug: "alpha"), b = story(slug: "bravo")
        try db.save(a, body: ""); try db.save(b, body: "")

        let clash = Story(id: b.id, category: .news, priority: .high, title: "B", summary: "s", slug: "alpha")
        #expect(throws: SaveError.self) { try db.save(clash, body: "") }
        // Nothing changed.
        #expect(try db.queue.read { try String.fetchOne($0, sql: "SELECT slug FROM stories WHERE id = ?", arguments: [b.id.uuidString]) } == "bravo")
    }
}
