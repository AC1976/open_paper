import Foundation
import GRDB

/// Everything that has appeared in a published issue, newest first. This is
/// what the section pages (News, Background, Opinion, Agenda, Quoted) show.
package struct PublishedItems: Sendable {
    package let stories: [Story]
    package let agendaPoints: [AgendaPoint]
    package let quotedItems: [QuotedItem]
}

extension PaperDatabase {
    /// Items placed in at least one published issue, newest first.
    ///
    /// "Newest" means the item's own date when it has one (a story's
    /// `publishedAt`, an agenda point's `eventDate`) and otherwise the date of
    /// the newest published issue it appears in. Quotes have no date of their
    /// own, so they follow their issue. Drafts and the inbox never show up.
    package func publishedItems() throws -> PublishedItems {
        try queue.read { db in
            func load<T: FetchableRecord & TableRecord>(_ type: T.Type, ownDate: String) throws -> [T] {
                try T.fetchAll(db, sql: """
                    SELECT t.* FROM \(T.databaseTableName) t
                    JOIN (
                        SELECT e.itemId, MAX(e.issueDate) AS issueDate
                        FROM edition_items e
                        JOIN issues i ON i.issueDate = e.issueDate
                        WHERE i.publishedAt IS NOT NULL
                        GROUP BY e.itemId
                    ) p ON p.itemId = t.id
                    ORDER BY COALESCE(\(ownDate), p.issueDate) DESC, p.issueDate DESC, t.rowid DESC
                    """)
            }
            return PublishedItems(
                stories: try load(Story.self, ownDate: "t.publishedAt"),
                agendaPoints: try load(AgendaPoint.self, ownDate: "t.eventDate"),
                quotedItems: try load(QuotedItem.self, ownDate: "NULL")
            )
        }
    }

    /// A story that has appeared in at least one published issue, with its
    /// markdown body. Nil for unknown slugs, drafts and inbox items, so a
    /// story cannot be read before it is published.
    package func publishedStory(slug: String) throws -> (story: Story, markdown: String)? {
        try queue.read { db in
            guard let story = try Story.fetchOne(db, sql: """
                SELECT s.* FROM stories s
                WHERE s.slug = ?
                  AND EXISTS (
                    SELECT 1 FROM edition_items e
                    JOIN issues i ON i.issueDate = e.issueDate
                    WHERE e.itemId = s.id AND i.publishedAt IS NOT NULL
                  )
                """, arguments: [slug])
            else { return nil }
            let body = try String.fetchOne(db, sql: "SELECT body FROM stories WHERE id = ?", arguments: [story.id.uuidString]) ?? ""
            return (story, body)
        }
    }
}
