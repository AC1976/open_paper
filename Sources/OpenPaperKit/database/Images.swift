import Foundation
import GRDB

/// The folder with the picture files. A file is named by its image id.
package struct ImageFiles: Sendable {
    package let directory: URL

    package static func fileExtension(for mimeType: String) -> String? {
        ["image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"][mimeType]
    }

    package func url(id: UUID, mimeType: String) -> URL {
        directory.appendingPathComponent("\(id.uuidString).\(Self.fileExtension(for: mimeType) ?? "bin")")
    }

    /// A smaller version of a picture.
    package func url(id: UUID, width: Int, mimeType: String) -> URL {
        directory.appendingPathComponent("\(id.uuidString)-\(width).\(Self.fileExtension(for: mimeType) ?? "bin")")
    }

    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Files written and files made obsolete by one transaction, so the folder can
/// follow the database whether it succeeds or not.
final class FileChanges {
    var written: [URL] = []
    var obsolete: [URL] = []
}

/// A picture file ready to be sent to a browser.
package struct ImageDownload: Sendable {
    package let data: Data
    package let mimeType: String
    /// True when the item it belongs to is visible to readers.
    package let isPublic: Bool
}

// Pictures: a row in `images` and a file in the image folder. One per item.
extension PaperDatabase {
    package static func imagePath(_ id: UUID) -> String { "/images/\(id.uuidString)" }

    /// The picture of an item, if it has one.
    package func picture(ofItem id: UUID) throws -> Picture? {
        try queue.read { db in try Self.pictures(of: [id], in: db)[id] }
    }

    /// The file behind `/images/{id}`, or its smaller version `?w={width}` when
    /// there is one; nil if there is no such picture.
    package func image(_ id: UUID, width: Int? = nil, asOf today: String = EditorDates.today()) throws -> ImageDownload? {
        let row = try queue.read { db in
            try Row.fetchOne(db, sql: """
                SELECT m.mimeType, m.widths, m.variantType, i.status = 'filed' AND i.publishDate <= ? AS visible
                FROM images m JOIN items i ON i.id = m.itemId WHERE m.id = ?
                """, arguments: [today, id.uuidString])
        }
        guard let row else { return nil }
        var mimeType: String = row["mimeType"]
        var url = images.url(id: id, mimeType: mimeType)
        if let width, Self.widths(row["widths"]).contains(width), let variantType: String = row["variantType"] {
            mimeType = variantType
            url = images.url(id: id, width: width, mimeType: variantType)
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return ImageDownload(data: data, mimeType: mimeType, isPublic: row["visible"] ?? false)
    }

    /// Runs a transaction that may add or drop picture files.
    func writeWithImages<T>(_ work: (Database, FileChanges) throws -> T) throws -> T {
        let changes = FileChanges()
        do {
            let result = try queue.write { db in try work(db, changes) }
            changes.obsolete.forEach(images.remove)
            return result
        } catch {
            changes.written.forEach(images.remove)
            throw error
        }
    }

    static func pictures(of items: [UUID], in db: Database) throws -> [UUID: Picture] {
        guard !items.isEmpty else { return [:] }
        let marks = databaseQuestionMarks(count: items.count)
        let rows = try Row.fetchAll(
            db, sql: "SELECT * FROM images WHERE itemId IN (\(marks))",
            arguments: StatementArguments(items.map(\.uuidString))
        )
        var result: [UUID: Picture] = [:]
        for row in rows {
            guard let id = UUID(uuidString: row["id"]), let item = UUID(uuidString: row["itemId"]) else { continue }
            let src = imagePath(id)
            let width: Int? = row["width"]
            var srcset: String?
            let smaller = widths(row["widths"])
            if let width, !smaller.isEmpty {
                srcset = (smaller.map { "\(src)?w=\($0) \($0)w" } + ["\(src) \(width)w"]).joined(separator: ", ")
            }
            result[item] = Picture(
                src: src, altText: row["altText"], caption: row["caption"], credit: row["credit"],
                width: width, height: row["height"], srcset: srcset
            )
        }
        return result
    }

    /// Gives the item this picture, replacing any it had. Returns the new image id.
    @discardableResult
    func setPicture(_ new: NewPicture, of item: UUID, in db: Database, _ changes: FileChanges) throws -> UUID {
        try removePicture(of: item, in: db, changes)
        let id = try Self.insertImage(new, item: item, into: images, in: db, changes)
        try Self.addSizes(to: id, data: new.data, into: images, in: db, changes)
        return id
    }

    /// Records the picture's size and writes its smaller versions.
    private static func addSizes(
        to id: UUID, data: Data, into files: ImageFiles, in db: Database, _ changes: FileChanges
    ) throws {
        guard let info = ImageResizer.info(data) else { return }
        var made: [Int] = []
        var variantType: String?
        for width in ImageResizer.smallerWidths where width < info.width {
            guard let version = ImageResizer.render(data, width: width) else { continue }
            let url = files.url(id: id, width: width, mimeType: version.mimeType)
            try files.write(version.data, to: url)
            changes.written.append(url)
            made.append(width)
            variantType = version.mimeType
        }
        try db.execute(
            sql: "UPDATE images SET width = ?, height = ?, widths = ?, variantType = ? WHERE id = ?",
            arguments: [info.width, info.height, made.map(String.init).joined(separator: ","), variantType, id.uuidString]
        )
    }

    private static func widths(_ list: String?) -> [Int] {
        (list ?? "").split(separator: ",").compactMap { Int($0) }
    }

    static func addSizesToStoredImages(_ db: Database, _ files: ImageFiles) throws {
        for row in try Row.fetchAll(db, sql: "SELECT id, mimeType FROM images") {
            guard let id = UUID(uuidString: row["id"]),
                  let data = try? Data(contentsOf: files.url(id: id, mimeType: row["mimeType"]))
            else { continue }
            try addSizes(to: id, data: data, into: files, in: db, FileChanges())
        }
    }

    static func insertImage(
        _ new: NewPicture, item: UUID, into files: ImageFiles, in db: Database, _ changes: FileChanges
    ) throws -> UUID {
        let id = UUID()
        let url = files.url(id: id, mimeType: new.mimeType)
        try files.write(new.data, to: url)
        changes.written.append(url)
        try db.execute(sql: """
            INSERT INTO images (id, itemId, mimeType, altText, caption, credit, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, arguments: [id.uuidString, item.uuidString, new.mimeType, new.text.altText, new.text.caption, new.text.credit, Date()])
        return id
    }

    func removePicture(of item: UUID, in db: Database, _ changes: FileChanges) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM images WHERE itemId = ?", arguments: [item.uuidString])
        for row in rows {
            guard let id = UUID(uuidString: row["id"]) else { continue }
            changes.obsolete.append(images.url(id: id, mimeType: row["mimeType"]))
            if let variantType: String = row["variantType"] {
                changes.obsolete += Self.widths(row["widths"]).map { images.url(id: id, width: $0, mimeType: variantType) }
            }
        }
        try db.execute(sql: "DELETE FROM images WHERE itemId = ?", arguments: [item.uuidString])
    }

    func apply(_ change: PictureChange, to item: UUID, in db: Database, _ changes: FileChanges) throws {
        switch change {
        case .unchanged: break
        case .remove: try removePicture(of: item, in: db, changes)
        case .replace(let new): try setPicture(new, of: item, in: db, changes)
        case .describe(let text):
            try db.execute(
                sql: "UPDATE images SET altText = ?, caption = ?, credit = ? WHERE itemId = ?",
                arguments: [text.altText, text.caption, text.credit, item.uuidString]
            )
        }
    }

    /// Moves an advertisement's uploaded bytes into a file and returns the
    /// advertisement pointing at it. An image given by another address drops
    /// any file the advertisement had.
    func storingImage(of ad: Advertisement, in db: Database, _ changes: FileChanges) throws -> Advertisement {
        let source: ImageSource
        switch ad.imageSource {
        case .blob(let data, let mimeType):
            let id = try setPicture(
                NewPicture(data: data, mimeType: mimeType, text: PictureText(altText: ad.altText)),
                of: ad.id, in: db, changes
            )
            source = .endpoint(url: Self.imagePath(id))
        case .endpoint(let url):
            if !url.hasPrefix("/images/") { try removePicture(of: ad.id, in: db, changes) }
            source = ad.imageSource
        }
        return Advertisement(
            id: ad.id, sponsorName: ad.sponsorName, imageSource: source,
            altText: ad.altText, targetURL: ad.targetURL, priority: ad.priority
        )
    }

    // MARK: Migration

    /// Moves pictures that were stored inside rows into files, and removes the
    /// picture column from stories. Pictures a story only named by address are
    /// not carried over.
    static func moveImagesToFiles(_ db: Database, _ files: ImageFiles) throws {
        struct OldStoryImage: Decodable {
            let source: ImageSource
            let altText: String
            let caption: String?
            let credit: String?
        }
        let changes = FileChanges()   // a failed migration leaves unused files, which is harmless

        func store(_ data: Data, _ mimeType: String, _ text: PictureText, item: UUID) throws -> UUID? {
            // Older uploads were not cleaned; do that now.
            let cleaned = ImageCleaner.clean(data)
            let type = cleaned?.mimeType ?? mimeType
            guard ImageFiles.fileExtension(for: type) != nil else { return nil }
            return try insertImage(
                NewPicture(data: cleaned?.data ?? data, mimeType: type, text: text),
                item: item, into: files, in: db, changes
            )
        }

        for row in try Row.fetchAll(db, sql: "SELECT id, image FROM stories WHERE image IS NOT NULL") {
            let json: String = row["image"]
            guard let item = UUID(uuidString: row["id"]),
                  let old = try? JSONDecoder().decode(OldStoryImage.self, from: Data(json.utf8)),
                  case .blob(let data, let mimeType) = old.source
            else { continue }
            _ = try store(data, mimeType, PictureText(altText: old.altText, caption: old.caption, credit: old.credit), item: item)
        }

        for row in try Row.fetchAll(db, sql: "SELECT id, imageSource, altText FROM advertisements") {
            let json: String = row["imageSource"]
            guard let item = UUID(uuidString: row["id"]),
                  let source = try? JSONDecoder().decode(ImageSource.self, from: Data(json.utf8)),
                  case .blob(let data, let mimeType) = source,
                  let id = try store(data, mimeType, PictureText(altText: row["altText"]), item: item)
            else { continue }
            let address = try JSONEncoder().encode(ImageSource.endpoint(url: imagePath(id)))
            try db.execute(
                sql: "UPDATE advertisements SET imageSource = ? WHERE id = ?",
                arguments: [String(decoding: address, as: UTF8.self), item.uuidString]
            )
        }

        try db.alter(table: "stories") { t in t.drop(column: "image") }
    }
}
