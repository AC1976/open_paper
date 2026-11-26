import Foundation
import GRDB

/// Everything readers can see, newest first. This is what the section pages
/// (News, Background, Opinion, Agenda, Quoted) show.
package struct PublishedItems: Sendable {
    package let stories: [Story]
    package let agendaPoints: [AgendaPoint]
    package let quotedItems: [QuotedItem]
    /// The stories' pictures, by story id.
    package let pictures: [UUID: Picture]
}

extension PaperDatabase {
    /// Items filed for today or earlier, newest first: stories and quotes by
    /// publish date, agenda points by event date (publish date if they have none).
    package func publishedItems(asOf today: String = EditorDates.today()) throws -> PublishedItems {
        try queue.read { db in
            func load<T: FetchableRecord & TableRecord>(_ type: T.Type, orderBy: String) throws -> [T] {
                try T.fetchAll(db, sql: """
                    SELECT t.* FROM \(T.databaseTableName) t
                    JOIN items i ON i.id = t.id
                    WHERE i.status = 'filed' AND i.publishDate <= ?
                    ORDER BY \(orderBy), i.uploadedAt DESC, i.rowid DESC
                    """, arguments: [today])
            }
            let stories = try load(Story.self, orderBy: "i.publishDate DESC")
            return PublishedItems(
                stories: stories,
                agendaPoints: try load(AgendaPoint.self, orderBy: "COALESCE(t.eventDate, i.publishDate) DESC"),
                quotedItems: try load(QuotedItem.self, orderBy: "i.publishDate DESC"),
                pictures: try Self.pictures(of: stories.map(\.id), in: db)
            )
        }
    }

    /// A story readers may open, with its markdown body and publish date. Nil
    /// for unknown slugs and for anything not filed for today or earlier.
    package func publishedStory(
        slug: String, asOf today: String = EditorDates.today()
    ) throws -> (story: Story, markdown: String, publishDate: String, picture: Picture?)? {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT s.*, i.publishDate AS filedFor FROM stories s
                JOIN items i ON i.id = s.id
                WHERE s.slug = ? AND i.status = 'filed' AND i.publishDate <= ?
                """, arguments: [slug, today])
            else { return nil }
            let story = try Story(row: row)
            return (story, row["body"] ?? "", row["filedFor"], try Self.pictures(of: [story.id], in: db)[story.id])
        }
    }
}
