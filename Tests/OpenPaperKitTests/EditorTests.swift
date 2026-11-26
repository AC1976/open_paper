import Foundation
import Testing
@testable import OpenPaperKit

/// Builds a multipart body the way a browser does.
private func multipart(
    boundary: String = "XyZ",
    fields: [(String, String)] = [],
    files: [(name: String, filename: String, type: String, data: Data)] = []
) -> Data {
    var body = Data()
    for (name, value) in fields {
        body += Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)
    }
    for file in files {
        body += Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\nContent-Type: \(file.type)\r\n\r\n".utf8)
        body += file.data
        body += Data("\r\n".utf8)
    }
    body += Data("--\(boundary)--\r\n".utf8)
    return body
}

private let storyFields: [(String, String)] = [
    ("id", "11111111-1111-1111-1111-111111111111"),
    ("category", "news"),
    ("priority", "2"),
    ("title", "A title"),
    ("slug", "a-title"),
    ("author", ""),
    ("publishedAt", "2026-11-20T06:00"),
    ("updatedAt", ""),
    ("summary", "A summary"),
    ("extendedSummary", ""),
    ("body", "Line one\r\n\r\nLine two"),
]

@Suite struct MultipartTests {
    @Test func readsTextFieldsAndFiles() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x00, 0xFF])   // includes CRLF and NUL bytes
        let body = multipart(
            fields: [("kind", "story"), ("note", "  spaced  ")],
            files: [("file", "story.md", "text/markdown", Data("---\nx\n---".utf8)), ("image", "a.png", "image/png", png)]
        )
        let form = try MultipartForm(body: body, contentType: "multipart/form-data; boundary=XyZ")

        #expect(form.text("kind") == "story")
        #expect(form.text("note") == "spaced")
        #expect(form.file("file")?.filename == "story.md")
        #expect(form.file("file")?.text == "---\nx\n---")
        #expect(form.file("image")?.data == png)
        #expect(form.file("image")?.contentType == "image/png")
        #expect(form.file("missing") == nil)
    }

    @Test func emptyFilePartMeansNoFileChosen() throws {
        let body = multipart(files: [("imageFile", "", "application/octet-stream", Data())])
        let form = try MultipartForm(body: body, boundary: "XyZ")
        #expect(form.file("imageFile") == nil)
    }

    @Test func rawTextKeepsWhitespaceAndEmptyTextIsNil() throws {
        let form = try MultipartForm(body: multipart(fields: [("body", "  a\n\n  b  "), ("empty", "")]), boundary: "XyZ")
        #expect(form.rawText("body") == "  a\n\n  b  ")
        #expect(form.text("empty") == nil)
    }

    @Test func boundaryMayBeQuoted() {
        #expect(MultipartForm.boundary(fromContentType: "multipart/form-data; boundary=\"abc-123\"") == "abc-123")
        #expect(MultipartForm.boundary(fromContentType: "application/json") == nil)
    }

    @Test func rejectsBodiesThatAreNotMultipart() {
        #expect(throws: MultipartForm.ParseError.self) {
            try MultipartForm(body: Data("hello".utf8), contentType: "text/plain")
        }
        #expect(throws: MultipartForm.ParseError.self) {
            try MultipartForm(body: Data("hello".utf8), boundary: "XyZ")
        }
    }
}

@Suite struct StoryFormTests {
    @Test func buildsAStoryFromTheForm() throws {
        let form = try MultipartForm(body: multipart(fields: storyFields), boundary: "XyZ")
        let (story, body, _) = try StoryForm.story(from: form)

        #expect(story.id.uuidString == "11111111-1111-1111-1111-111111111111")
        #expect(story.category == .news && story.priority == .high)
        #expect(story.title == "A title" && story.slug == "a-title")
        #expect(story.author == nil && story.extendedSummary == nil)
        #expect(story.publishedAt != nil && story.updatedAt == nil)
        #expect(EditorDates.dateTime(story.publishedAt!) == "2026-11-20T06:00")
        #expect(body == "Line one\r\n\r\nLine two")
    }

    @Test func aChosenFileBecomesTheNewPicture() throws {
        let fields = storyFields + [("altText", "Alt"), ("caption", "Cap")]
        let body = multipart(fields: fields, files: [("imageFile", "p.png", "image/png", TestImage.png(3))])
        let result = try StoryForm.story(from: MultipartForm(body: body, boundary: "XyZ"))
        #expect(result.picture == .replace(NewPicture(data: TestImage.png(3), mimeType: "image/png",
                                                      text: PictureText(altText: "Alt", caption: "Cap"))))
    }

    @Test func withoutAFileOrAPictureNothingChanges() throws {
        let form = try MultipartForm(body: multipart(fields: storyFields + [("altText", "unused")]), boundary: "XyZ")
        #expect(try StoryForm.story(from: form).picture == .unchanged)
    }

    @Test func reportsEveryProblemAtOnce() throws {
        let fields: [(String, String)] = [
            ("category", "sports"), ("priority", "9"), ("title", ""), ("slug", "Has Spaces"),
            ("summary", ""), ("publishedAt", "yesterday"),
        ]
        let form = try MultipartForm(body: multipart(fields: fields), boundary: "XyZ")
        do {
            _ = try StoryForm.story(from: form, hasPicture: true)
            Issue.record("should have failed")
        } catch let problems as StoryForm.Problems {
            let text = problems.messages.joined(separator: "\n")
            for expected in ["Title is required", "Summary is required", "Choose a category", "Choose a priority",
                             "Slug may only", "Published is not a valid", "Alt text is required"] {
                #expect(text.contains(expected), "missing: \(expected)")
            }
        }
    }

    @Test func rejectsNonImageFiles() throws {
        let body = multipart(fields: storyFields + [("altText", "a")],
                             files: [("imageFile", "x.pdf", "application/pdf", Data([1]))])
        #expect(throws: StoryForm.Problems.self) {
            try StoryForm.story(from: MultipartForm(body: body, boundary: "XyZ"))
        }
    }
}

@Suite struct StagingTests {
    private let source = """
        ---
        subject: Rate decision
        place: Frankfurt
        link: https://example.com
        summary: s
        ---
        """

    @Test func stagedUploadSurvivesUntilSavedThenDisappears() throws {
        let db = try PaperDatabase()
        let id = try db.stage(kind: .agendaPoint, filename: "ecb.md", source: source)

        #expect(try db.stagedUploads().map(\.filename) == ["ecb.md"])
        let staged = try #require(try db.staged(id))
        let parsed = try ParsedUpload(kind: staged.kind, text: staged.source, name: staged.filename)

        try db.submit(parsed, discarding: id)
        #expect(try db.staged(id) == nil)
        #expect(try db.newsDesk().map(\.title) == ["Rate decision"])
    }

    @Test func cancelRemovesTheStagedUpload() throws {
        let db = try PaperDatabase()
        let id = try db.stage(kind: .agendaPoint, filename: "ecb.md", source: source)
        try db.discardStaged(id)
        #expect(try db.staged(id) == nil)
        #expect(try db.newsDesk().isEmpty)
    }

    @Test func oldStagedUploadsAreRemovedWhenStagingAgain() throws {
        let db = try PaperDatabase()
        let old = try db.stage(kind: .agendaPoint, filename: "old.md", source: source)
        try db.queue.write { db in
            try db.execute(sql: "UPDATE staged_uploads SET createdAt = ?", arguments: [Date().addingTimeInterval(-25 * 3600)])
        }
        _ = try db.stage(kind: .agendaPoint, filename: "new.md", source: source)
        #expect(try db.staged(old) == nil)
        #expect(try db.stagedUploads().map(\.filename) == ["new.md"])
    }

    @Test func fileWithoutFrontMatterIsRejected() {
        #expect(throws: UploadError.self) {
            try ParsedUpload(kind: .story, text: "just text", name: "x.md")
        }
    }
}
