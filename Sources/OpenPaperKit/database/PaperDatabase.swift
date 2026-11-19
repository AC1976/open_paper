import Foundation
import GRDB

/// What kind of item an upload is. One row per item in `items`, whatever its kind.
package enum ItemKind: String, Sendable {
    case story, agendaPoint, quotedItem, advertisement
}

package enum SaveOutcome: Sendable, Equatable {
    case inserted, updated
}

/// An uploaded item that has not been placed in any issue yet.
package struct InboxEntry: Sendable, Equatable {
    package let id: UUID
    package let kind: ItemKind
    package let title: String
    package let uploadedAt: Date
}

package enum SaveError: Error, CustomStringConvertible, Sendable {
    case slugTaken(String)

    package var description: String {
        switch self {
        case .slugTaken(let slug): "Another story already uses the slug \"\(slug)\"."
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
/// Workflow: an editor uploads one item at a time. `save` stores it in the
/// inbox (a row in `items` plus a row in the item's own table). Later the
/// editor places inbox items into an issue with `place`, which adds a row to
/// `edition_items`. Each `save` / `place` is one transaction.
package final class PaperDatabase: Sendable {
    package let queue: DatabaseQueue

    package init(path: String) throws {
        queue = try DatabaseQueue(path: path)
        try Self.migrator.migrate(queue)
    }

    package init() throws {
        queue = try DatabaseQueue()   // in memory, for tests
        try Self.migrator.migrate(queue)
    }

    // MARK: Migrations
    //
    // Never edit a migration that has shipped; add a new one.

    private static var migrator: DatabaseMigrator {
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

        return migrator
    }

    // MARK: Saving uploads (into the inbox)

    /// Saves a story and its markdown body. A story with the same `id`, or
    /// failing that the same `slug`, is updated in place instead of duplicated.
    @discardableResult
    package func save(_ story: Story, body: String, discarding stagedID: UUID? = nil) throws -> SaveOutcome {
        try queue.write { db in
            let id = try Self.existingStoryID(story, in: db) ?? story.id
            let isNew = try Self.register(id, kind: .story, in: db)
            try story.with(id: id).save(db)
            try db.execute(sql: "UPDATE stories SET body = ? WHERE id = ?", arguments: [body, id.uuidString])
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
        try queue.write { db in
            let isNew = try Self.register(ad.id, kind: .advertisement, in: db)
            try ad.save(db)
            try Self.discard(stagedID, in: db)
            return isNew ? .inserted : .updated
        }
    }

    // MARK: Inbox and placement

    /// Items that are not in any issue yet, newest upload first.
    package func inbox() throws -> [InboxEntry] {
        try queue.read { db in
            try Self.entries(db, where: "NOT EXISTS (SELECT 1 FROM edition_items e WHERE e.itemId = i.id)",
                             orderBy: "i.uploadedAt DESC, i.rowid DESC")
        }
    }

    /// Items placed in the issue of `issueDate`, in their order.
    package func placed(inIssue issueDate: String) throws -> [InboxEntry] {
        try queue.read { db in
            try Self.entries(db, where: "i.id IN (SELECT itemId FROM edition_items WHERE issueDate = ?)",
                             orderBy: "(SELECT position FROM edition_items WHERE itemId = i.id AND issueDate = ?), i.rowid",
                             arguments: [issueDate, issueDate])
        }
    }

    /// Places an item in the issue of `issueDate` ("yyyy-MM-dd"), after the
    /// items already there. Placing it again leaves its position alone unless
    /// you pass one.
    package func place(_ itemID: UUID, inIssue issueDate: String, position: Int? = nil) throws {
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO edition_items (issueDate, itemId, position)
                VALUES (?, ?, COALESCE(?, (SELECT MAX(position) + 1 FROM edition_items WHERE issueDate = ?), 0))
                ON CONFLICT(issueDate, itemId) DO UPDATE SET position = COALESCE(?, position)
                """, arguments: [issueDate, itemID.uuidString, position, issueDate, position])
        }
    }

    /// Takes an item out of an issue; it goes back to the inbox if it is in no other issue.
    package func remove(_ itemID: UUID, fromIssue issueDate: String) throws {
        try queue.write { db in
            try db.execute(
                sql: "DELETE FROM edition_items WHERE issueDate = ? AND itemId = ?",
                arguments: [issueDate, itemID.uuidString]
            )
        }
    }

    private static func entries(
        _ db: Database, where condition: String, orderBy: String, arguments: StatementArguments = []
    ) throws -> [InboxEntry] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT i.id, i.kind, i.uploadedAt,
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
                  let kind = ItemKind(rawValue: row["kind"])
            else { return nil }
            return InboxEntry(id: id, kind: kind, title: row["title"] ?? "", uploadedAt: row["uploadedAt"])
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

    private static func discard(_ id: UUID?, in db: Database) throws {
        guard let id else { return }
        try db.execute(sql: "DELETE FROM staged_uploads WHERE id = ?", arguments: [id.uuidString])
    }

    // MARK: Helpers

    /// Adds the item to `items`; false if it was already there.
    private static func register(_ id: UUID, kind: ItemKind, in db: Database) throws -> Bool {
        try db.execute(
            sql: "INSERT OR IGNORE INTO items (id, kind, uploadedAt) VALUES (?, ?, ?)",
            arguments: [id.uuidString, kind.rawValue, Date()]
        )
        return db.changesCount > 0
    }

    /// The id of the story this one replaces: the same `id`, or failing that the
    /// same `slug` (a re-upload). Editing a story into another story's slug is an error.
    private static func existingStoryID(_ story: Story, in db: Database) throws -> UUID? {
        let byID = try String.fetchOne(db, sql: "SELECT id FROM stories WHERE id = ?", arguments: [story.id.uuidString])
        let bySlug = try String.fetchOne(db, sql: "SELECT id FROM stories WHERE slug = ?", arguments: [story.slug])
        if let byID {
            if let bySlug, bySlug != byID { throw SaveError.slugTaken(story.slug) }
            return UUID(uuidString: byID)
        }
        return bySlug.flatMap(UUID.init(uuidString:))
    }
}
