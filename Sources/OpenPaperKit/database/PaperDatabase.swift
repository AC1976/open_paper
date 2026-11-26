import Foundation
import GRDB

/// What kind of item an upload is. One row per item in `items`, whatever its kind.
package enum ItemKind: String, Sendable {
    case story, agendaPoint, quotedItem, advertisement
}

package enum SaveOutcome: Sendable, Equatable {
    case inserted, updated
}

/// Where an item is on its way into the paper.
package enum ItemStatus: String, Sendable {
    case submitted   // on the news desk
    case filed       // has a publish date
    case rejected
}

/// One line on the news desk or in an edition.
package struct DeskEntry: Sendable, Equatable {
    package let id: UUID
    package let kind: ItemKind
    package let title: String
    /// The story's byline.
    package let author: String?
    /// Who sent it in through the contribute pages; nil for editors' uploads.
    /// The email address is for editors only and is never published.
    package let contributor: Contributor?
    package let uploadedAt: Date
    package let status: ItemStatus
    /// "yyyy-MM-dd"; set exactly when the item is filed.
    package let publishDate: String?
    /// The last day of a filed advertisement's run, which starts on
    /// `publishDate`. Nil for everything else: it is in one day's paper.
    package let publishUntil: String?
}

package enum SaveError: Error, CustomStringConvertible, Sendable {
    case slugTaken(String)
    case noSuchItem
    case invalidDate(String)
    case endsBeforeStart

    package var description: String {
        switch self {
        case .slugTaken(let slug): "Another story already uses the slug \"\(slug)\"."
        case .noSuchItem: "That item no longer exists."
        case .invalidDate(let text): text.isEmpty ? "Choose a publish date." : "\"\(text)\" is not a valid date."
        case .endsBeforeStart: "The last day cannot be before the first day."
        }
    }
}

/// An upload that was read but not saved yet (the editor is reviewing it).
package struct StagedUpload: Sendable, Equatable {
    package let id: UUID
    package let kind: ItemKind
    package let filename: String
    package let source: String     // the file as uploaded
    package let createdAt: Date
}

/// The SQLite database.
///
/// Workflow: `save` puts an item on the news desk (a row in `items` plus a row
/// in the item's own table). An editor files it with a publish date (`file`);
/// the paper of a date is made of the items filed for it. Each `save` / `file`
/// is one transaction.
package final class PaperDatabase: Sendable {
    package let queue: DatabaseQueue
    /// Where the picture files are.
    package let images: ImageFiles

    /// The pictures go in `imageDirectory`, by default a folder next to the
    /// database: `open_paper.sqlite` → `open_paper-images/`.
    package init(path: String, imageDirectory: URL? = nil) throws {
        queue = try DatabaseQueue(path: path)
        let file = URL(fileURLWithPath: path)
        images = ImageFiles(directory: imageDirectory
            ?? file.deletingPathExtension().deletingLastPathComponent()
                .appendingPathComponent(file.deletingPathExtension().lastPathComponent + "-images"))
        let migrator = Self.migrator(images: images)
        try Self.backUpBeforeMovingImages(queue, path: path, migrator: migrator)
        try migrator.migrate(queue)
    }

    package init() throws {
        queue = try DatabaseQueue()   // in memory, for tests
        images = ImageFiles(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("open-paper-test-\(UUID().uuidString)"))
        try Self.migrator(images: images).migrate(queue)
    }

    /// Moving the pictures rewrites rows, so an existing database is copied first.
    private static func backUpBeforeMovingImages(_ queue: DatabaseQueue, path: String, migrator: DatabaseMigrator) throws {
        let applied = try queue.read { try migrator.appliedIdentifiers($0) }
        let backup = path + ".before-images.sqlite"
        guard !applied.isEmpty, !applied.contains("v7-image-files"), !FileManager.default.fileExists(atPath: backup) else { return }
        try queue.backup(to: try DatabaseQueue(path: backup))
    }

    // MARK: Migrations
    //
    // Never edit a migration that has shipped; add a new one.

    static func migrator(images: ImageFiles) -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            // Every uploaded item, whatever its kind. The inbox is a query on this.
            try db.create(table: "items") { t in
                t.column("id", .text).primaryKey()
                t.column("kind", .text).notNull()
                t.column("uploadedAt", .datetime).notNull()
            }

            try db.create(table: "stories") { t in
                t.column("id", .text).primaryKey().references("items", onDelete: .cascade)
                t.column("category", .text).notNull()
                t.column("priority", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("summary", .text).notNull()
                t.column("extendedSummary", .text)
                t.column("slug", .text).notNull().unique()
                t.column("publishedAt", .datetime)
                t.column("updatedAt", .datetime)
                t.column("author", .text)
                t.column("image", .text)                      // JSON
                t.column("body", .text).notNull().defaults(to: "")   // markdown
            }

            try db.create(table: "agenda_points") { t in
                t.column("id", .text).primaryKey().references("items", onDelete: .cascade)
                t.column("subject", .text).notNull()
                t.column("place", .text).notNull()
                t.column("link", .text).notNull()
                t.column("summary", .text).notNull()
                t.column("eventDate", .datetime)
            }

            try db.create(table: "quoted_items") { t in
                t.column("id", .text).primaryKey().references("items", onDelete: .cascade)
                t.column("quote", .text).notNull()
                t.column("speaker", .text).notNull()
                t.column("context", .text).notNull()
                t.column("sourceLink", .text).notNull()
            }

            try db.create(table: "advertisements") { t in
                t.column("id", .text).primaryKey().references("items", onDelete: .cascade)
                t.column("sponsorName", .text).notNull()
                t.column("imageSource", .text).notNull()      // JSON
                t.column("altText", .text).notNull()
                t.column("targetURL", .text).notNull()
                t.column("priority", .integer).notNull()
            }

            // Placement: which items are in which issue. An item can be in
            // several issues. `issueDate` is "yyyy-MM-dd".
            try db.create(table: "edition_items") { t in
                t.column("issueDate", .text).notNull()
                t.column("itemId", .text).notNull().indexed().references("items", onDelete: .cascade)
                t.column("position", .integer).notNull().defaults(to: 0)
                t.primaryKey(["issueDate", "itemId"])
            }
        }

        migrator.registerMigration("v2-staged-uploads") { db in
            // Uploaded files waiting for the editor to review and save them.
            try db.create(table: "staged_uploads") { t in
                t.column("id", .text).primaryKey()
                t.column("kind", .text).notNull()
                t.column("filename", .text).notNull()
                t.column("source", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v3-issues") { db in
            // Per-issue settings. A row exists once the editor sets the
            // edition mode or publishes; no row means "prominent, not published".
            try db.create(table: "issues") { t in
                t.column("issueDate", .text).primaryKey()
                t.column("mode", .text).notNull().defaults(to: "prominent")
                t.column("publishedAt", .datetime)
            }
        }

        migrator.registerMigration("v4-editors") { db in
            try db.create(table: "editors") { t in
                t.column("id", .text).primaryKey()
                t.column("email", .text).notNull().unique()      // stored lower-case
                t.column("passwordHash", .text).notNull()        // bcrypt
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "sessions") { t in
                t.column("tokenHash", .text).primaryKey()        // SHA-256 of the cookie value
                t.column("editorId", .text).notNull().indexed().references("editors", onDelete: .cascade)
                t.column("expiresAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v5-publish-dates") { db in
            try db.alter(table: "items") { t in
                t.add(column: "status", .text).notNull().defaults(to: "submitted")
                t.add(column: "publishDate", .text)             // "yyyy-MM-dd"
            }
            try db.create(index: "items_on_status_publishDate", on: "items", columns: ["status", "publishDate"])

            // Items that readers could already see are filed, dated with the first
            // published issue they were in. Everything else waits on the news desk.
            // `edition_items` and `issues.publishedAt` are no longer used, but are
            // kept so that nothing is lost.
            let firstPublished = """
                SELECT MIN(e.issueDate) FROM edition_items e
                JOIN issues i ON i.issueDate = e.issueDate
                WHERE e.itemId = items.id AND i.publishedAt IS NOT NULL
                """
            try db.execute(sql: """
                UPDATE items SET status = 'filed', publishDate = (\(firstPublished))
                WHERE (\(firstPublished)) IS NOT NULL
                """)
        }

        migrator.registerMigration("v6-contributors") { db in
            try db.alter(table: "items") { t in
                t.add(column: "contributorName", .text)
                t.add(column: "contributorEmail", .text)
            }
        }

        migrator.registerMigration("v7-image-files") { db in
            try db.create(table: "images") { t in
                t.column("id", .text).primaryKey()
                t.column("itemId", .text).notNull().unique().references("items", onDelete: .cascade)
                t.column("mimeType", .text).notNull()
                t.column("altText", .text).notNull()
                t.column("caption", .text)
                t.column("credit", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try moveImagesToFiles(db, images)
        }

        migrator.registerMigration("v8-image-sizes") { db in
            try db.alter(table: "images") { t in
                t.add(column: "width", .integer)
                t.add(column: "height", .integer)
                t.add(column: "widths", .text)          // smaller versions, "480,960"
                t.add(column: "variantType", .text)     // their file type
            }
            try addSizesToStoredImages(db, images)
        }

        migrator.registerMigration("v9-advertisement-ranges") { db in
            try db.alter(table: "items") { t in
                t.add(column: "publishUntil", .text)            // "yyyy-MM-dd", advertisements only
            }
            // Advertisements filed so far ran for one day, and still do.
            try db.execute(sql: """
                UPDATE items SET publishUntil = publishDate WHERE kind = 'advertisement' AND status = 'filed'
                """)
        }

        return migrator
    }

    // MARK: Saving (new items land on the news desk)

    /// Saves a story and its markdown body, updating the story with the same
    /// `id`. A slug that belongs to another story is refused. (New uploads go
    /// through `submit`, which never changes an existing item.)
    @discardableResult
    package func save(
        _ story: Story, body: String, picture: PictureChange = .unchanged, discarding stagedID: UUID? = nil
    ) throws -> SaveOutcome {
        try writeWithImages { db, changes in
            let clash = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM stories WHERE slug = ? AND id <> ?",
                arguments: [story.slug, story.id.uuidString]
            ) ?? 0
            guard clash == 0 else { throw SaveError.slugTaken(story.slug) }
            let isNew = try Self.register(story.id, kind: .story, in: db)
            try story.save(db)
            try db.execute(sql: "UPDATE stories SET body = ? WHERE id = ?", arguments: [body, story.id.uuidString])
            try apply(picture, to: story.id, in: db, changes)
            try Self.discard(stagedID, in: db)
            return isNew ? .inserted : .updated
        }
    }

    @discardableResult
    package func save(_ point: AgendaPoint, discarding stagedID: UUID? = nil) throws -> SaveOutcome {
        try queue.write { db in
            let isNew = try Self.register(point.id, kind: .agendaPoint, in: db)
            try point.save(db)
            try Self.discard(stagedID, in: db)
            return isNew ? .inserted : .updated
        }
    }

    @discardableResult
    package func save(_ item: QuotedItem, discarding stagedID: UUID? = nil) throws -> SaveOutcome {
        try queue.write { db in
            let isNew = try Self.register(item.id, kind: .quotedItem, in: db)
            try item.save(db)
            try Self.discard(stagedID, in: db)
            return isNew ? .inserted : .updated
        }
    }

    @discardableResult
    package func save(_ ad: Advertisement, discarding stagedID: UUID? = nil) throws -> SaveOutcome {
        try writeWithImages { db, changes in
            let isNew = try Self.register(ad.id, kind: .advertisement, in: db)
            try storingImage(of: ad, in: db, changes).save(db)
            try Self.discard(stagedID, in: db)
            return isNew ? .inserted : .updated
        }
    }

    // MARK: News desk and filing

    /// Submissions waiting for an editor, newest first.
    package func newsDesk() throws -> [DeskEntry] {
        try entries(where: "i.status = 'submitted'", orderBy: "i.uploadedAt DESC, i.rowid DESC")
    }

    package func rejectedItems() throws -> [DeskEntry] {
        try entries(where: "i.status = 'rejected'", orderBy: "i.uploadedAt DESC, i.rowid DESC")
    }

    /// Every filed item, latest publish date first.
    package func filedItems() throws -> [DeskEntry] {
        try entries(where: "i.status = 'filed'", orderBy: "i.publishDate DESC, i.uploadedAt, i.rowid")
    }

    /// SQL for "item `i` is in the paper of a date"; takes the date twice.
    static let inPaperOfDate = """
        i.status = 'filed' AND i.publishDate <= ? AND COALESCE(i.publishUntil, i.publishDate) >= ?
        """

    /// The items in the paper of one date, in the order they came in: those
    /// filed for it, and the advertisements running on it.
    package func filedItems(on date: String) throws -> [DeskEntry] {
        try entries(where: Self.inPaperOfDate, orderBy: "i.uploadedAt, i.rowid", arguments: [date, date])
    }

    package func entry(_ id: UUID) throws -> DeskEntry? {
        try entries(where: "i.id = ?", orderBy: "i.rowid", arguments: [id.uuidString]).first
    }

    /// Gives the item a publish date ("yyyy-MM-dd"). Filing again moves it.
    /// An advertisement runs from that date through `until`, or for that one
    /// day without it; `until` means nothing for other kinds.
    package func file(_ id: UUID, on date: String, until: String? = nil) throws {
        try Self.checkRun(from: date, until: until)
        try setStatus(.filed, publishDate: date, publishUntil: until ?? date, of: id)
    }

    /// Refuses dates that are not real, or a run that ends before it starts.
    package static func checkRun(from date: String, until: String?) throws {
        guard EditorDates.isDay(date) else { throw SaveError.invalidDate(date) }
        guard let until else { return }
        guard EditorDates.isDay(until) else { throw SaveError.invalidDate(until) }
        guard until >= date else { throw SaveError.endsBeforeStart }
    }

    package func reject(_ id: UUID) throws {
        try setStatus(.rejected, publishDate: nil, of: id)
    }

    /// Takes a filed or rejected item back to the news desk.
    package func returnToDesk(_ id: UUID) throws {
        try setStatus(.submitted, publishDate: nil, of: id)
    }

    private func setStatus(
        _ status: ItemStatus, publishDate: String?, publishUntil: String? = nil, of id: UUID
    ) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE items SET status = ?, publishDate = ?,
                        publishUntil = CASE WHEN kind = 'advertisement' THEN ? END
                    WHERE id = ?
                    """,
                arguments: [status.rawValue, publishDate, publishUntil, id.uuidString]
            )
            guard db.changesCount > 0 else { throw SaveError.noSuchItem }
        }
    }

    private func entries(
        where condition: String, orderBy: String, arguments: StatementArguments = []
    ) throws -> [DeskEntry] {
        try queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT i.id, i.kind, i.uploadedAt, i.status, i.publishDate, i.publishUntil, s.author,
                       i.contributorName, i.contributorEmail,
                       COALESCE(s.title, a.subject, q.speaker, ad.sponsorName) AS title
                FROM items i
                LEFT JOIN stories s ON s.id = i.id
                LEFT JOIN agenda_points a ON a.id = i.id
                LEFT JOIN quoted_items q ON q.id = i.id
                LEFT JOIN advertisements ad ON ad.id = i.id
                WHERE \(condition)
                ORDER BY \(orderBy)
                """, arguments: arguments)
            return rows.compactMap { row in
                guard let id = UUID(uuidString: row["id"]),
                      let kind = ItemKind(rawValue: row["kind"]),
                      let status = ItemStatus(rawValue: row["status"])
                else { return nil }
                var contributor: Contributor?
                if let name: String = row["contributorName"], let email: String = row["contributorEmail"] {
                    contributor = Contributor(name: name, email: email)
                }
                return DeskEntry(
                    id: id, kind: kind, title: row["title"] ?? "", author: row["author"], contributor: contributor,
                    uploadedAt: row["uploadedAt"], status: status, publishDate: row["publishDate"],
                    publishUntil: row["publishUntil"]
                )
            }
        }
    }

    /// A saved item, whatever its kind (stories come with their markdown).
    package func item(_ id: UUID) throws -> ParsedUpload? {
        try queue.read { db in
            let key = id.uuidString
            guard let raw = try String.fetchOne(db, sql: "SELECT kind FROM items WHERE id = ?", arguments: [key]),
                  let kind = ItemKind(rawValue: raw)
            else { return nil }

            switch kind {
            case .story:
                guard let story = try Story.fetchOne(db, sql: "SELECT * FROM stories WHERE id = ?", arguments: [key]) else { return nil }
                let body = try String.fetchOne(db, sql: "SELECT body FROM stories WHERE id = ?", arguments: [key]) ?? ""
                return .story(story, markdown: body, html: markdownToHTML(body))
            case .agendaPoint:
                return try AgendaPoint.fetchOne(db, sql: "SELECT * FROM agenda_points WHERE id = ?", arguments: [key]).map { .agendaPoint($0) }
            case .quotedItem:
                return try QuotedItem.fetchOne(db, sql: "SELECT * FROM quoted_items WHERE id = ?", arguments: [key]).map { .quotedItem($0) }
            case .advertisement:
                return try Advertisement.fetchOne(db, sql: "SELECT * FROM advertisements WHERE id = ?", arguments: [key]).map { .advertisement($0) }
            }
        }
    }

    /// The markdown body saved with a story.
    package func body(ofStory id: UUID) throws -> String? {
        try queue.read { db in
            try String.fetchOne(db, sql: "SELECT body FROM stories WHERE id = ?", arguments: [id.uuidString])
        }
    }

    // MARK: Staging

    /// Keeps an uploaded file until the editor saves or cancels it. Also
    /// removes staged uploads older than 24 hours.
    package func stage(kind: ItemKind, filename: String, source: String) throws -> UUID {
        let id = UUID()
        try queue.write { db in
            try db.execute(
                sql: "DELETE FROM staged_uploads WHERE createdAt < ?",
                arguments: [Date().addingTimeInterval(-24 * 3600)]
            )
            try db.execute(
                sql: "INSERT INTO staged_uploads (id, kind, filename, source, createdAt) VALUES (?, ?, ?, ?, ?)",
                arguments: [id.uuidString, kind.rawValue, filename, source, Date()]
            )
        }
        return id
    }

    package func staged(_ id: UUID) throws -> StagedUpload? {
        try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM staged_uploads WHERE id = ?", arguments: [id.uuidString])
                .flatMap(Self.stagedUpload)
        }
    }

    /// Uploads still waiting for review, newest first.
    package func stagedUploads() throws -> [StagedUpload] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM staged_uploads ORDER BY createdAt DESC, rowid DESC")
                .compactMap(Self.stagedUpload)
        }
    }

    package func discardStaged(_ id: UUID) throws {
        try queue.write { db in try Self.discard(id, in: db) }
    }

    private static func stagedUpload(_ row: Row) -> StagedUpload? {
        guard let id = UUID(uuidString: row["id"]), let kind = ItemKind(rawValue: row["kind"]) else { return nil }
        return StagedUpload(id: id, kind: kind, filename: row["filename"], source: row["source"], createdAt: row["createdAt"])
    }

    static func discard(_ id: UUID?, in db: Database) throws {
        guard let id else { return }
        try db.execute(sql: "DELETE FROM staged_uploads WHERE id = ?", arguments: [id.uuidString])
    }

    // MARK: Helpers

    /// Adds the item to `items`; false if it was already there.
    @discardableResult
    static func register(_ id: UUID, kind: ItemKind, in db: Database) throws -> Bool {
        try db.execute(
            sql: "INSERT OR IGNORE INTO items (id, kind, uploadedAt) VALUES (?, ?, ?)",
            arguments: [id.uuidString, kind.rawValue, Date()]
        )
        return db.changesCount > 0
    }
}
