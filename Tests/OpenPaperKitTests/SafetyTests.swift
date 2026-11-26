import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import OpenPaperKit

private func storyFile(_ extra: String = "", title: String = "Global Summit", body: String = "Hello") -> String {
    "---\ncategory: news\ntitle: \(title)\nsummary: S\n\(extra)---\n\(body)\n"
}

@Suite struct SubmissionTests {
    @Test func contributorsCannotChooseIdSlugPriorityDatesOrImage() throws {
        let file = storyFile("""
            id: 11111111-1111-1111-1111-111111111111
            slug: front-page
            priority: 2
            publishedAt: 2020-01-01T00:00:00Z
            updatedAt: 2020-01-01T00:00:00Z
            image:
              source: { endpoint: { url: "https://tracker.example/pixel.png" } }
              altText: x

            """)
        guard case .story(let s, _, _) = try ParsedUpload(kind: .story, text: file, name: "x.md") else { Issue.record("not a story"); return }
        #expect(s.id.uuidString != "11111111-1111-1111-1111-111111111111")
        #expect(s.slug == "global-summit" && s.priority == .normal)
        #expect(s.publishedAt == nil && s.updatedAt == nil && s.image == nil)
    }

    @Test func aSubmissionNeverOverwritesAnExistingItem() throws {
        let db = try PaperDatabase()
        let original = try db.submit(ParsedUpload(kind: .story, text: storyFile(body: "original"), name: "a.md"))
        try db.file(original, on: "2026-11-20")
        // The attacker names the published story's id and slug.
        let attack = storyFile("id: \(original.uuidString)\nslug: global-summit\n", body: "defaced")
        let second = try db.submit(ParsedUpload(kind: .story, text: attack, name: "b.md"))

        #expect(second != original)
        #expect(try db.body(ofStory: original) == "original")
        #expect(try db.publishedStory(slug: "global-summit", asOf: "2026-11-20")?.story.id == original)
        #expect(try db.entry(second)?.status == .submitted)
        guard case .story(let s, _, _)? = try db.item(second) else { Issue.record("missing"); return }
        #expect(s.slug == "global-summit-2")
    }

    @Test func evenAHandMadeItemWithAnExistingIdBecomesANewOne() throws {
        let db = try PaperDatabase()
        let quote = QuotedItem(quote: "real", speaker: "A", context: "c", sourceLink: "https://x")
        try db.save(quote)
        let id = try db.submit(.quotedItem(QuotedItem(id: quote.id, quote: "fake", speaker: "A", context: "c", sourceLink: "https://x")))
        #expect(id != quote.id)
        guard case .quotedItem(let kept)? = try db.item(quote.id) else { Issue.record("missing"); return }
        #expect(kept.quote == "real")
    }

    @Test func editsGoToThePageBeingEditedOnly() throws {
        let db = try PaperDatabase()
        let a = QuotedItem(quote: "a", speaker: "A", context: "c", sourceLink: "https://x")
        let b = QuotedItem(quote: "b", speaker: "B", context: "c", sourceLink: "https://x")
        try db.save(a); try db.save(b)
        // A tampered hidden field names b, but the page is a's.
        try db.update(.quotedItem(QuotedItem(id: b.id, quote: "edited", speaker: "A", context: "c", sourceLink: "https://x")), id: a.id)
        guard case .quotedItem(let newA)? = try db.item(a.id), case .quotedItem(let newB)? = try db.item(b.id) else { return }
        #expect(newA.quote == "edited" && newB.quote == "b")
        #expect(throws: SaveError.self) { try db.update(.quotedItem(a), id: UUID()) }
    }

    @Test func linksMustBeWebAddresses() {
        for bad in ["javascript:alert(1)", "data:text/html,x", "//evil.example", "ftp://x"] {
            let agenda = "---\nsubject: s\nplace: p\nlink: \"\(bad)\"\nsummary: s\n---\n"
            let quote = "---\nquote: q\nspeaker: s\ncontext: c\nsourceLink: \"\(bad)\"\n---\n"
            #expect(throws: SubmissionError.self) { try ParsedUpload(kind: .agendaPoint, text: agenda, name: "a.md") }
            #expect(throws: SubmissionError.self) { try ParsedUpload(kind: .quotedItem, text: quote, name: "q.md") }
        }
    }

    @Test func oversizedAndEmptyFieldsAreRefused() {
        #expect(throws: SubmissionError.tooLong("title", 200)) {
            try ParsedUpload(kind: .story, text: storyFile(title: String(repeating: "x", count: 201)), name: "a.md")
        }
        #expect(throws: SubmissionError.missing("title")) {
            try ParsedUpload(kind: .story, text: storyFile(title: "\"  \""), name: "a.md")
        }
        #expect(throws: SubmissionError.fileTooLarge) {
            try ParsedUpload(kind: .story, text: storyFile(body: String(repeating: "x", count: 100_001)), name: "a.md")
        }
    }

    @Test func yamlAliasesAreRefusedButOrdinaryTextIsNot() throws {
        let bomb = "---\na: &a [x, x, x]\nb: &b [*a, *a, *a]\n? *b\n: 1\ncategory: news\ntitle: t\nsummary: s\n---\n"
        #expect(throws: SubmissionError.aliasesNotAllowed) { try ParsedUpload(kind: .story, text: bomb, name: "b.md") }
        for flow in ["x: [&n 1, *n]", "x: {\"a\":&n 1, b: *n}", "base: &d {k: 1}\nother:\n  <<: *d"] {
            #expect(throws: SubmissionError.aliasesNotAllowed) {
                try ParsedUpload(kind: .story, text: storyFile(flow + "\n"), name: "b.md")
            }
        }
        // Ampersands and asterisks in prose are fine, in the YAML and in the body.
        let fine = "---\ncategory: news\ntitle: Salt & pepper\nsummary: >\n  An *important* A&B story\n---\n&x and *x in the body\n"
        _ = try ParsedUpload(kind: .story, text: fine, name: "f.md")
    }

    @Test func slugsAreSafeAddresses() {
        #expect(Slug.make(from: "Café: the slow return!") == "cafe-the-slow-return")
        #expect(Slug.make(from: "../../etc <script>") == "etc-script")
        #expect(Slug.make(from: "漢字") == "article")
        #expect(Slug.make(from: String(repeating: "word ", count: 40)).count <= 80)
    }
}

@Suite struct SanitizerTests {
    @Test func ordinaryMarkdownSurvives() {
        let html = markdownToHTML("## Head\n\nSome **bold**, *soft* and [a link](https://example.com/a?b=1&c=2).\n\n- one\n- two\n\n> quoted\n\n`code`")
        for expected in ["<h2>Head</h2>", "<strong>bold</strong>", "<em>soft</em>", "<ul><li>one</li>", "<blockquote>", "<code>code</code>",
                         "<a href=\"https://example.com/a?b=1&amp;c=2\" rel=\"nofollow noopener\">a link</a>"] {
            #expect(html.contains(expected), "\(expected) in \(html)")
        }
    }

    @Test func nothingExecutableGetsThrough() {
        let attacks = [
            "<script>alert(1)</script>", "<SCRIPT SRC=//evil></SCRIPT>", "<img src=x onerror=alert(1)>",
            "<p onclick=\"alert(1)\">x</p>", "<a href=\"javascript:alert(1)\">x</a>", "[x](javascript:alert(1))",
            "[x](JaVaScRiPt:alert(1))", "[x](data:text/html;base64,PHN2Zz4=)", "<iframe src=\"https://evil\"></iframe>",
            "<svg><script>alert(1)</script></svg>", "<style>body{display:none}</style>", "<<script>script>alert(1)",
            "<a href=\"java&#x09;script:alert(1)\">x</a>", "[x](https://ok\" onmouseover=\"alert(1))",
            "<div\nonmouseover=alert(1)>x", "<math><mtext></p><img src onerror=alert(1)>", "![pic](https://tracker.example/p.png)",
            "<!--<script>-->", "<meta http-equiv=refresh content=0>", "<form action=//evil><button>go</button></form>",
        ]
        for attack in attacks {
            let html = markdownToHTML(attack)
            // Every "<" left in the output must start an allowed tag with no stray attributes.
            let tags = html.matches(of: /<[^>]*>/).map { String($0.output) }
            for tag in tags {
                let plain = tag.wholeMatch(of: /<\/?(p|h[1-6]|ul|ol|li|blockquote|strong|em|b|i|del|s|code|pre|br|hr|a|table|thead|tbody|tr|th|td|sup|sub)>/) != nil
                let link = tag.wholeMatch(of: /<a href="(https?:\/\/|mailto:|#|\/)[^"]*" rel="nofollow noopener">/) != nil
                #expect(plain || link, "\(attack) gave \(tag)")
            }
        }
    }

    @Test func unclosedAndStrayTagsCannotBreakThePage() {
        #expect(HTMLSanitizer.clean("<blockquote><em>x") == "<blockquote><em>x</em></blockquote>")
        #expect(HTMLSanitizer.clean("x</p></article>") == "x&lt;/article&gt;")
    }

    @Test func uploadsAreCleanedTheSameWay() throws {
        let upload = try ParsedUpload(kind: .story, text: storyFile(body: "<script>alert(1)</script>"), name: "a.md")
        guard case .story(_, _, let html) = upload else { return }
        #expect(!html.contains("<script>") && html.contains("&lt;script&gt;"))
    }
}

@Suite struct ImageCleanerTests {
    /// A real picture written by macOS, with location, camera data and a turn.
    private func photo(_ type: UTType) -> Data {
        let context = CGContext(data: nil, width: 8, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 4))
        let out = NSMutableData()
        let destination = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 52.37, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "SECRET-COMMENT"],
        ]
        CGImageDestinationAddImage(destination, context.makeImage()!, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return out as Data
    }

    private func properties(_ data: Data) -> [CFString: Any] {
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        #expect(CGImageSourceCreateImageAtIndex(source, 0, nil) != nil, "picture no longer opens")
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    }

    @Test func jpegLosesLocationButKeepsItsOrientation() throws {
        var original = photo(.jpeg)
        #expect(properties(original)[kCGImagePropertyGPSDictionary] != nil)
        original.append(Data("APPENDED-SECRET".utf8))

        let cleaned = try #require(ImageCleaner.clean(original))
        let after = properties(cleaned.data)
        #expect(cleaned.mimeType == "image/jpeg")
        #expect(after[kCGImagePropertyGPSDictionary] == nil)
        #expect(after[kCGImagePropertyOrientation] as? Int == 6)
        for secret in ["SECRET-COMMENT", "APPENDED-SECRET"] { #expect(cleaned.data.range(of: Data(secret.utf8)) == nil) }
    }

    @Test func pngLosesMetadata() throws {
        let cleaned = try #require(ImageCleaner.clean(photo(.png)))
        #expect(cleaned.mimeType == "image/png")
        #expect(properties(cleaned.data)[kCGImagePropertyGPSDictionary] == nil)
        for hidden in ["eXIf", "tEXt", "iTXt", "SECRET-COMMENT"] { #expect(cleaned.data.range(of: Data(hidden.utf8)) == nil) }
    }

    @Test func webpDropsExifAndXmpChunks() throws {
        func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
            Array(type.utf8) + [UInt8(data.count), 0, 0, 0] + data + (data.count % 2 == 1 ? [0] : [])
        }
        let chunks = chunk("VP8X", [0x0C, 0, 0, 0, 0, 0, 0, 0, 0, 0]) + chunk("VP8 ", [1, 2, 3])
            + chunk("EXIF", Array("GPSDATA".utf8)) + chunk("XMP ", Array("XMPDATA".utf8))
        let file = Data(Array("RIFF".utf8) + [UInt8(chunks.count + 4), 0, 0, 0] + Array("WEBP".utf8) + chunks)

        let cleaned = try #require(ImageCleaner.clean(file))
        #expect(cleaned.mimeType == "image/webp")
        for hidden in ["GPSDATA", "XMPDATA"] { #expect(cleaned.data.range(of: Data(hidden.utf8)) == nil) }
        let bytes = [UInt8](cleaned.data)
        #expect(bytes[20] == 0)                                           // metadata flags cleared
        #expect(Int(bytes[4]) == cleaned.data.count - 8)
    }

    @Test func otherAndDamagedFilesAreRefused() {
        for bad in [Data(), Data("<svg onload=alert(1)>".utf8), Data("GIF89a".utf8), Data([0xFF, 0xD8, 0xFF]),
                    Data(TestImage.pngHeader), TestImage.jpeg().dropLast(2), TestImage.png().dropLast(6),
                    Data("RIFF\u{FF}\0\0\0WEBP".utf8)] {
            #expect(ImageCleaner.clean(Data(bad)) == nil)
        }
        // Truncations of real files must never crash.
        let real = photo(.jpeg)
        for length in stride(from: 0, to: real.count, by: 7) { _ = ImageCleaner.clean(Data(real.prefix(length))) }
    }
}

@Suite struct SubmissionGuardTests {
    @Test func eachSenderAndEveryoneTogetherAreLimited() async {
        let guardian = SubmissionGuard()
        let start = Date()
        for _ in 0..<SubmissionGuard.perSender { #expect(await guardian.allow("a", now: start)) }
        #expect(await guardian.allow("a", now: start) == false)
        #expect(await guardian.allow("b", now: start))
        #expect(await guardian.allow("a", now: start.addingTimeInterval(SubmissionGuard.window + 1)))

        let busy = SubmissionGuard()
        for n in 0..<SubmissionGuard.overall { #expect(await busy.allow("sender \(n)", now: start)) }
        #expect(await busy.allow("one more", now: start) == false)
    }

    @Test func theHiddenFieldGivesRobotsAway() throws {
        func form(_ value: String) throws -> MultipartForm {
            try MultipartForm(body: Data("--B\r\nContent-Disposition: form-data; name=\"website\"\r\n\r\n\(value)\r\n--B--\r\n".utf8), boundary: "B")
        }
        #expect(try !SubmissionGuard.isRobot(form("")))
        #expect(try SubmissionGuard.isRobot(form("http://spam.example")))
    }
}
