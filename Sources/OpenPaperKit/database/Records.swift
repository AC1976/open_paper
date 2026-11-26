import Foundation
import GRDB

// The models are GRDB records: they are read from and written to SQLite
// straight from their `Codable` shape.
//
// - Column names are the property names.
// - Ids are stored as upper-case text (readable in the `sqlite3` shell).
// - Nested values (`imageSource`) are stored as JSON text. Story pictures are
//   not part of the model; see `Images.swift`.
// - `stories.body` (the markdown) is not a model property; see `PaperDatabase`.

extension Story: FetchableRecord, PersistableRecord {
    package static var databaseTableName: String { "stories" }
    package static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy { .uppercaseString }
}

extension AgendaPoint: FetchableRecord, PersistableRecord {
    package static var databaseTableName: String { "agenda_points" }
    package static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy { .uppercaseString }
}

extension QuotedItem: FetchableRecord, PersistableRecord {
    package static var databaseTableName: String { "quoted_items" }
    package static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy { .uppercaseString }
}

extension Advertisement: FetchableRecord, PersistableRecord {
    package static var databaseTableName: String { "advertisements" }
    package static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy { .uppercaseString }
}

extension Story {
    /// The same story under another id (used to update an existing story
    /// when a re-upload has the same `slug`).
    package func with(id: UUID, slug newSlug: String? = nil) -> Story {
        Story(
            id: id,
            category: category,
            priority: priority,
            title: title,
            summary: summary,
            extendedSummary: extendedSummary,
            slug: newSlug ?? slug,
            publishedAt: publishedAt,
            updatedAt: updatedAt,
            author: author
        )
    }
}
