import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import OpenPaperKit

private func size(_ data: Data) -> [Int] {
    ImageResizer.info(data).map { [$0.width, $0.height] } ?? []
}

@Suite struct ResizerTests {
    @Test func largePicturesAreScaledToTwoThousandWide() throws {
        let result = try #require(ImageResizer.accept(TestImage.make(.jpeg, 4032, 3024)))
        #expect(result.mimeType == "image/jpeg" && size(result.data) == [2000, 1500])
    }

    @Test func tallPicturesAreLimitedInHeight() throws {
        let result = try #require(ImageResizer.accept(TestImage.make(.jpeg, 1500, 4800)))
        #expect(size(result.data) == [750, 2400])
    }

    @Test func smallPicturesKeepTheirPixels() throws {
        let original = TestImage.jpeg(3)
        #expect(ImageResizer.accept(original)?.data == original)
        #expect(size(try #require(ImageResizer.accept(TestImage.make(.png, 900, 600))).data) == [900, 600])
    }

    @Test func rotationIsAppliedWhenScaling() throws {
        // Stored 3000 x 1000 with "turn a quarter": shown 1000 x 3000.
        let turned = TestImage.make(.jpeg, 3000, 1000, orientation: 6)
        #expect(size(turned) == [1000, 3000])
        let result = try #require(ImageResizer.accept(turned))
        #expect(size(result.data) == [800, 2400])
        let source = CGImageSourceCreateWithData(result.data as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 800)          // really turned, not just marked
    }

    @Test func transparencyStaysPNGAndOpaqueBecomesJPEG() throws {
        #expect(ImageResizer.accept(TestImage.make(.png, 2600, 900, transparent: true))?.mimeType == "image/png")
        #expect(ImageResizer.accept(TestImage.make(.png, 2600, 900))?.mimeType == "image/jpeg")
    }

    @Test func aHeavyOpaquePictureIsCompressed() throws {
        let heavy = TestImage.make(.png, 900, 600, noise: true)
        #expect(heavy.count > 800_000)
        let result = try #require(ImageResizer.accept(heavy))
        #expect(result.mimeType == "image/jpeg" && result.data.count < heavy.count && size(result.data) == [900, 600])
    }

    @Test func neverEnlarges() throws {
        #expect(try #require(ImageResizer.render(TestImage.jpeg(), width: 2000)).width == 8)
    }

    @Test func unreadableAndAbsurdlyLargePicturesAreRefused() {
        // A valid outline with no real pixels inside.
        func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
            [0, 0, 0, UInt8(data.count)] + Array(type.utf8) + data + [0, 0, 0, 0]
        }
        let hollow = Data(TestImage.pngHeader + chunk("IHDR", [UInt8](repeating: 0, count: 13)) + chunk("IDAT", [1]) + chunk("IEND", []))
        #expect(ImageResizer.accept(hollow) == nil)
        // A header claiming 40,000 x 40,000 pixels is refused before anything is unpacked.
        let huge = Data(TestImage.pngHeader + chunk("IHDR", [0, 0, 0x9C, 0x40, 0, 0, 0x9C, 0x40, 8, 2, 0, 0, 0]) + chunk("IDAT", [1]) + chunk("IEND", []))
        #expect(ImageResizer.accept(huge) == nil)
        #expect(ImageResizer.accept(Data("<svg/>".utf8)) == nil)
    }
}

@Suite struct ImageSizeStorageTests {
    private func story() -> Story { Story(category: .news, priority: .high, title: "A", summary: "s", slug: "a") }

    private func store(_ width: Int, _ height: Int) throws -> (PaperDatabase, UUID, Picture) {
        let db = try PaperDatabase()
        let accepted = try #require(ImageResizer.accept(TestImage.make(.jpeg, width, height)))
        let item = try db.submit(
            .story(story(), markdown: "", html: ""),
            picture: NewPicture(data: accepted.data, mimeType: accepted.mimeType, text: PictureText(altText: "a"))
        )
        return (db, item, try #require(try db.picture(ofItem: item)))
    }

    private func files(_ db: PaperDatabase) throws -> Int {
        try FileManager.default.contentsOfDirectory(atPath: db.images.directory.path).count
    }

    @Test func smallerVersionsAreStoredAndOffered() throws {
        let (db, item, picture) = try store(4000, 3000)
        let id = try #require(UUID(uuidString: String(picture.src.dropFirst("/images/".count))))
        #expect(picture.width == 2000 && picture.height == 1500)
        #expect(picture.srcset == "\(picture.src)?w=480 480w, \(picture.src)?w=960 960w, \(picture.src)?w=1600 1600w, \(picture.src) 2000w")
        #expect(try files(db) == 4)
        #expect(size(try #require(try db.image(id)).data) == [2000, 1500])
        #expect(size(try #require(try db.image(id, width: 480)).data) == [480, 360])
        #expect(size(try #require(try db.image(id, width: 123)).data) == [2000, 1500])     // unknown width: the main file

        try db.update(.story(story(), markdown: "", html: ""), id: item, picture: .remove)
        #expect(try files(db) == 0)
    }

    @Test func onlySmallerWidthsThanThePictureAreMade() throws {
        let (db, _, picture) = try store(700, 500)
        #expect(try files(db) == 2)
        #expect(picture.srcset == "\(picture.src)?w=480 480w, \(picture.src) 700w")
        let (tiny, _, small) = try store(300, 200)
        #expect(try files(tiny) == 1 && small.srcset == nil && small.width == 300)
    }

    @Test func pagesOfferTheSizes() throws {
        let (db, item, picture) = try store(2400, 1600)
        try db.file(item, on: "2026-11-20")
        let issue = try db.issue(on: "2026-11-20")
        let front = NYTFrontPage(metadata: issue.metadata, plan: issue.plan).render()
        #expect(front.contains("srcset=\"\(picture.src)?w=480 480w"))
        #expect(front.contains("sizes=") && front.contains("width=\"2000\"") && front.contains("loading=\"lazy\""))
        let article = ArticlePage(metadata: issue.metadata, story: story(), bodyHTML: "", picture: picture).render()
        #expect(article.contains("1000px") && !article.contains("loading=\"lazy\""))
    }
}
