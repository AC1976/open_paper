import Foundation
import GRDB

/// Everything placed in one issue, ready for the layout planner.
package struct IssueContents: Sendable {
    /// "yyyy-MM-dd"
    package let date: String
    /// 1 for the first issue date, 2 for the next, and so on.
    package let number: Int
    package let mode: EditionMode
    /// Nil while the issue is a draft.
    package let publishedAt: Date?
    package let stories: [Story]
    package let agendaPoints: [AgendaPoint]
    package let quotedItems: [QuotedItem]
    package let advertisements: [Advertisement]

    package var isEmpty: Bool {
        stories.isEmpty && agendaPoints.isEmpty && quotedItems.isEmpty && advertisements.isEmpty
    }

    package var isPublished: Bool { publishedAt != nil }

    package var metadata: EditionMetadata {
        EditionMetadata(
            paperTitle: "Het Grootboek",
            subtitle: "Met het Oog op de Rekening",
            volume: 1,
            issueNumber: number,
            editionDate: EditorDates.parseDay(date) ?? Date(),
            editionLabel: "Namiddag Editie"
        )
    }

    package var plan: FrontPageLayoutPlan {
        FrontPageLayoutPlan(
            mode: mode,
            stories: stories,
            agendaPoints: agendaPoints,
            quotedItems: quotedItems,
            advertisements: advertisements
        )
    }
}

extension PaperDatabase {
    /// The issue that `/` shows: the one published most recently.
    package func latestPublishedIssueDate() throws -> String? {
        try queue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT issueDate FROM issues WHERE publishedAt IS NOT NULL ORDER BY publishedAt DESC LIMIT 1"
            )
        }
    }

    /// How the issue is laid out and whether it is published.
    package func settings(ofIssue date: String) throws -> (mode: EditionMode, publishedAt: Date?) {
        try queue.read { db in
            try Self.settings(date, in: db)
        }
    }

    /// Chooses the layout of an issue (breaking, prominent or regular).
    package func setMode(_ mode: EditionMode, forIssue date: String) throws {
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO issues (issueDate, mode) VALUES (?, ?)
                ON CONFLICT(issueDate) DO UPDATE SET mode = excluded.mode
                """, arguments: [date, mode.rawValue])
        }
    }

    /// Publishes the issue: it becomes the one `/` shows. Fails (returns
    /// false) when nothing is placed in it. Publishing again makes it the
    /// newest publication again.
    @discardableResult
    package func publish(issue date: String, mode: EditionMode) throws -> Bool {
        try queue.write { db in
            let count = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM edition_items WHERE issueDate = ?", arguments: [date]
            ) ?? 0
            guard count > 0 else { return false }
            try db.execute(sql: """
                INSERT INTO issues (issueDate, mode, publishedAt) VALUES (?, ?, ?)
                ON CONFLICT(issueDate) DO UPDATE SET mode = excluded.mode, publishedAt = excluded.publishedAt
                """, arguments: [date, mode.rawValue, Date()])
            return true
        }
    }

    /// Loads the items placed in the issue of `date` ("yyyy-MM-dd"), each
    /// kind in the order the editor gave them.
    package func issue(on date: String) throws -> IssueContents {
        try queue.read { db in
            func load<T: FetchableRecord & TableRecord>(_ type: T.Type) throws -> [T] {
                try T.fetchAll(db, sql: """
                    SELECT t.* FROM \(T.databaseTableName) t
                    JOIN edition_items e ON e.itemId = t.id
                    WHERE e.issueDate = ?
                    ORDER BY e.position, e.rowid
                    """, arguments: [date])
            }
            let number = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(DISTINCT issueDate) FROM edition_items WHERE issueDate <= ?",
                arguments: [date]
            ) ?? 0
            let settings = try Self.settings(date, in: db)
            return IssueContents(
                date: date,
                number: max(number, 1),
                mode: settings.mode,
                publishedAt: settings.publishedAt,
                stories: try load(Story.self),
                agendaPoints: try load(AgendaPoint.self),
                quotedItems: try load(QuotedItem.self),
                advertisements: try load(Advertisement.self)
            )
        }
    }

    private static func settings(_ date: String, in db: Database) throws -> (mode: EditionMode, publishedAt: Date?) {
        guard let row = try Row.fetchOne(db, sql: "SELECT mode, publishedAt FROM issues WHERE issueDate = ?", arguments: [date]) else {
            return (.prominent, nil)
        }
        let mode = EditionMode(rawValue: row["mode"] ?? "") ?? .prominent
        return (mode, row["publishedAt"])
    }
}
