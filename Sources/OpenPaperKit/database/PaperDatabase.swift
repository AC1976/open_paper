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

        return migrator
    }

    // MARK: Saving uploads (into the inbox)

    /// Saves a story and its markdown body. A story with the same `id`, or
    /// failing that the same `slug`, is updated in place instead of duplicated.
    @discardableResult
    package func save(_ story: Story, body: String) throws -> SaveOutcome {
        try queue.write { db in
            let id = try Self.existingStoryID(story, in: db) ?? story.id
            let isNew = try Self.register(id, kind: .story, in: db)
            try story.with(id: id).save(db)
            try db.execute(sql: "UPDATE stories SET body = ? WHERE id = ?", arguments: [body, id.uuidString])
            return isNew ? .inserted : .updated
        }
    }

    @discardableResult
    package func save(_ point: AgendaPoint) throws -> SaveOutcome {
        try queue.write { db in
            let isNew = try Self.register(point.id, kind: .agendaPoint, in: db)
            try point.save(db)
            return isNew ? .inserted : .updated
        }
    }

    @discardableResult
    package func save(_ item: QuotedItem) throws -> SaveOutcome {
        try queue.write { db in
            let isNew = try Self.register(item.id, kind: .quotedItem, in: db)
            try item.save(db)
            return isNew ? .inserted : .updated
        }
    }

    @discardableResult
    package func save(_ ad: Advertisement) throws -> SaveOutcome {
        try queue.write { db in
            let isNew = try Self.register(ad.id, kind: .advertisement, in: db)
            try ad.save(db)
            return isNew ? .inserted : .updated
        }
    }

    // MARK: Inbox and placement

    /// Items that are not in any issue yet, newest upload first.
    package func inbox() throws -> [InboxEntry] {
        try queue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT i.id, i.kind, i.uploadedAt,
                       COALESCE(s.title, a.subject, q.speaker, ad.sponsorName) AS title
                FROM items i
                LEFT JOIN stories s ON s.id = i.id
                LEFT JOIN agenda_points a ON a.id = i.id
                LEFT JOIN quoted_items q ON q.id = i.id
                LEFT JOIN advertisements ad ON ad.id = i.id
                WHERE NOT EXISTS (SELECT 1 FROM edition_items e WHERE e.itemId = i.id)
                ORDER BY i.uploadedAt DESC, i.rowid DESC
                """)
            return rows.compactMap { row in
                guard let id = UUID(uuidString: row["id"]),
                      let kind = ItemKind(rawValue: row["kind"])
                else { return nil }
                return InboxEntry(id: id, kind: kind, title: row["title"] ?? "", uploadedAt: row["uploadedAt"])
            }
        }
    }

    /// Places an item in the issue of `issueDate` ("yyyy-MM-dd"). Placing it
    /// again in the same issue only changes its position.
    package func place(_ itemID: UUID, inIssue issueDate: String, position: Int = 0) throws {
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO edition_items (issueDate, itemId, position) VALUES (?, ?, ?)
                ON CONFLICT(issueDate, itemId) DO UPDATE SET position = excluded.position
                """, arguments: [issueDate, itemID.uuidString, position])
        }
    }

    /// The markdown body saved with a story.
    package func body(ofStory id: UUID) throws -> String? {
        try queue.read { db in
            try String.fetchOne(db, sql: "SELECT body FROM stories WHERE id = ?", arguments: [id.uuidString])
        }
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

    private static func existingStoryID(_ story: Story, in db: Database) throws -> UUID? {
        let found = try String.fetchOne(
            db,
            sql: "SELECT id FROM stories WHERE id = ? OR slug = ? ORDER BY id = ? DESC LIMIT 1",
            arguments: [story.id.uuidString, story.slug, story.id.uuidString]
        )
        return found.flatMap(UUID.init(uuidString:))
    }
}
