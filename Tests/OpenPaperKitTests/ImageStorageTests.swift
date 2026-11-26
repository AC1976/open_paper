import Foundation
import GRDB
import Testing
@testable import OpenPaperKit

private func picture(_ marker: UInt8, alt: String = "alt") -> NewPicture {
    NewPicture(data: TestImage.png(marker), mimeType: "image/png", text: PictureText(altText: alt, caption: "cap", credit: "me"))
}

private func story(_ slug: String = "a", priority: StoryPriority = .high) -> Story {
    Story(category: .news, priority: priority, title: slug.capitalized, summary: "s", slug: slug)
}

private func files(_ db: PaperDatabase) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: db.images.directory.path)) ?? []).sorted()
}

private func id(of picture: Picture?) throws -> UUID {
    try #require(picture.flatMap { UUID(uuidString: String($0.src.dropFirst("/images/".count))) })
}

@Suite struct ImageStorageTests {
    @Test func aSubmittedPictureBecomesAFileAndAnAddress() throws {
        let db = try PaperDatabase()
        let item = try db.submit(.story(story(), markdown: "", html: ""), picture: picture(1))
        let stored = try #require(try db.picture(ofItem: item))

        #expect(stored.src.hasPrefix("/images/") && stored.altText == "alt" && stored.caption == "cap" && stored.credit == "me")
        #expect(files(db).count == 1)
        let download = try #require(try db.image(id(of: stored)))
        #expect(download.data == TestImage.png(1) && download.mimeType == "image/png")
        // No picture data in the database.
        let columns = try db.queue.read { try $0.columns(in: "stories").map(\.name) }
        #expect(!columns.contains("image"))
    }

    @Test func picturesArePublicOnlyOnceTheItemIs() throws {
        let db = try PaperDatabase()
        let item = try db.submit(.story(story(), markdown: "", html: ""), picture: picture(1))
        let image = try id(of: db.picture(ofItem: item))
        func visible(on day: String) throws -> Bool { try #require(try db.image(image, asOf: day)).isPublic }

        #expect(try !visible(on: "2026-11-20"))                         // on the news desk
        try db.file(item, on: "2026-11-21")
        #expect(try !visible(on: "2026-11-20"))                         // not yet
        #expect(try visible(on: "2026-11-21"))
        try db.reject(item)
        #expect(try !visible(on: "2026-11-30"))
        #expect(try db.image(UUID()) == nil)
    }

    @Test func replacingAndRemovingCleanUpFiles() throws {
        let db = try PaperDatabase()
        let item = try db.submit(.story(story(), markdown: "", html: ""), picture: picture(1))
        let first = files(db)

        try db.update(.story(story(), markdown: "", html: ""), id: item, picture: .replace(picture(2)))
        #expect(files(db).count == 1 && files(db) != first)
        try db.update(.story(story(), markdown: "", html: ""), id: item, picture: .describe(PictureText(altText: "new words")))
        #expect(try db.picture(ofItem: item)?.altText == "new words")
        try db.update(.story(story(), markdown: "", html: ""), id: item)                    // unchanged
        #expect(try db.picture(ofItem: item) != nil)
        try db.update(.story(story(), markdown: "", html: ""), id: item, picture: .remove)
        #expect(try db.picture(ofItem: item) == nil && files(db).isEmpty)
    }

    @Test func aFailedSaveLeavesNoNewFileAndKeepsTheOldOne() throws {
        let db = try PaperDatabase()
        try db.submit(.story(story("taken"), markdown: "", html: ""))
        let item = try db.submit(.story(story("mine"), markdown: "", html: ""), picture: picture(1))
        let before = files(db)
        #expect(throws: SaveError.self) {
            try db.update(.story(story("taken"), markdown: "", html: ""), id: item, picture: .replace(picture(2)))
        }
        #expect(files(db) == before)
        #expect(try db.picture(ofItem: item) != nil)
    }

    @Test func pagesLinkToPicturesInsteadOfEmbeddingThem() throws {
        let db = try PaperDatabase()
        let item = try db.submit(.story(story(), markdown: "text", html: ""), picture: picture(1))
        try db.file(item, on: "2026-11-20")
        let src = try #require(try db.picture(ofItem: item)).src

        let issue = try db.issue(on: "2026-11-20")
        let items = try db.publishedItems(asOf: "2026-11-20")
        let read = try #require(try db.publishedStory(slug: "a", asOf: "2026-11-20"))
        let pages = [
            NYTFrontPage(metadata: issue.metadata, plan: issue.plan).render(),
            SectionPage(metadata: issue.metadata, section: .news, stories: items.stories, agendaPoints: [], quotedItems: [], pictures: items.pictures).render(),
            ArticlePage(metadata: issue.metadata, story: read.story, bodyHTML: "", picture: read.picture).render(),
        ]
        for page in pages {
            #expect(page.contains("src=\"\(src)\""))
            #expect(!page.contains("base64"))
        }
    }

    @Test func advertisementImagesAreStoredTheSameWay() throws {
        let db = try PaperDatabase()
        let ad = Advertisement(sponsorName: "V", imageSource: .blob(data: TestImage.png(7), mimeType: "image/png"),
                               altText: "ad", targetURL: "https://x")
        try db.save(ad)
        guard case .advertisement(let saved)? = try db.item(ad.id), case .endpoint(let url) = saved.imageSource else { Issue.record("not stored"); return }
        #expect(url.hasPrefix("/images/") && files(db).count == 1)
        try db.update(.advertisement(saved), id: ad.id)                  // editing keeps the file
        #expect(files(db).count == 1)
        let elsewhere = Advertisement(id: ad.id, sponsorName: "V", imageSource: .endpoint(url: "https://cdn/x.png"), altText: "ad", targetURL: "https://x")
        try db.update(.advertisement(elsewhere), id: ad.id)
        #expect(files(db).isEmpty)
    }
}

@Suite struct ImageMigrationTests {
    @Test func embeddedPicturesMoveToFilesAndTheColumnGoes() throws {
        let queue = try DatabaseQueue()
        let folder = ImageFiles(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let migrator = PaperDatabase.migrator(images: folder)
        try migrator.migrate(queue, upTo: "v6-contributors")

        let embedded = UUID(), addressOnly = UUID(), ad = UUID()
        func json(_ source: ImageSource) throws -> String { String(decoding: try JSONEncoder().encode(source), as: UTF8.self) }
        let blob = try json(.blob(data: TestImage.png(5), mimeType: "image/png"))
        let address = try json(.endpoint(url: "images/missing.jpg"))
        try queue.write { db in
            for (id, kind) in [(embedded, "story"), (addressOnly, "story"), (ad, "advertisement")] {
                try db.execute(sql: "INSERT INTO items (id, kind, uploadedAt) VALUES (?, ?, ?)", arguments: [id.uuidString, kind, Date()])
            }
            for (id, source, slug) in [(embedded, blob, "one"), (addressOnly, address, "two")] {
                try db.execute(sql: """
                    INSERT INTO stories (id, category, priority, title, summary, slug, image, body)
                    VALUES (?, 'news', 1, 'T', 's', ?, ?, 'body')
                    """, arguments: [id.uuidString, slug, "{\"source\":\(source),\"altText\":\"old alt\",\"credit\":\"c\"}"])
            }
            try db.execute(sql: "INSERT INTO advertisements VALUES (?, 'V', ?, 'ad alt', 'https://x', 1)", arguments: [ad.uuidString, blob])
        }

        try migrator.migrate(queue)

        try queue.read { db in
            #expect(try !db.columns(in: "stories").map(\.name).contains("image"))
            #expect(try String.fetchAll(db, sql: "SELECT body FROM stories") == ["body", "body"])      // stories survive
            let rows = try Row.fetchAll(db, sql: "SELECT itemId, altText FROM images")
            #expect(Set(rows.map { $0["itemId"] as String }) == [embedded.uuidString, ad.uuidString])
            let adSource = try String.fetchOne(db, sql: "SELECT imageSource FROM advertisements") ?? ""
            #expect(adSource.contains("images") && !adSource.contains("blob"))
        }
        let written = try FileManager.default.contentsOfDirectory(at: folder.directory, includingPropertiesForKeys: nil)
        #expect(written.count == 2)
        #expect(try written.allSatisfy { try Data(contentsOf: $0) == TestImage.png(5) })
    }

    @Test func anExistingDatabaseIsBackedUpFirst() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent("paper.sqlite").path
        do {
            let queue = try DatabaseQueue(path: path)
            try PaperDatabase.migrator(images: ImageFiles(directory: folder)).migrate(queue, upTo: "v6-contributors")
        }
        let db = try PaperDatabase(path: path)
        #expect(FileManager.default.fileExists(atPath: path + ".before-images.sqlite"))
        #expect(db.images.directory.lastPathComponent == "paper-images")

        // A brand new database needs no backup.
        let fresh = folder.appendingPathComponent("fresh.sqlite").path
        _ = try PaperDatabase(path: fresh)
        #expect(!FileManager.default.fileExists(atPath: fresh + ".before-images.sqlite"))
    }
}
