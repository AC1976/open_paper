import Foundation
import GRDB

/// The paper of one date: the items filed for it, ready for the layout planner.
package struct IssueContents: Sendable {
    /// "yyyy-MM-dd"
    package let date: String
    /// 1 for the first date with items, 2 for the next, and so on.
    package let number: Int
    package let mode: EditionMode
    package let stories: [Story]
    package let agendaPoints: [AgendaPoint]
    package let quotedItems: [QuotedItem]
    package let advertisements: [Advertisement]

    package var isEmpty: Bool {
        stories.isEmpty && agendaPoints.isEmpty && quotedItems.isEmpty && advertisements.isEmpty
    }

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

// "Today" is the date in the paper's time zone. Readers never see anything
// filed for a later date; the functions take `asOf` so tests can choose the day.
extension PaperDatabase {
    /// The newest date, up to today, that has items: what `/` shows.
    package func latestIssueDate(asOf today: String = EditorDates.today()) throws -> String? {
        try queue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT MAX(publishDate) FROM items WHERE status = 'filed' AND publishDate <= ?",
                arguments: [today]
            )
        }
    }

    /// The layout of a date's paper: breaking, prominent (default) or regular.
    package func mode(ofIssue date: String) throws -> EditionMode {
        try queue.read { db in try Self.mode(date, in: db) }
    }

    package func setMode(_ mode: EditionMode, forIssue date: String) throws {
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO issues (issueDate, mode) VALUES (?, ?)
                ON CONFLICT(issueDate) DO UPDATE SET mode = excluded.mode
                """, arguments: [date, mode.rawValue])
        }
    }

    /// Everything filed for `date`, whether or not that day has arrived (the
    /// editor previews future papers; public routes check the date).
    package func issue(on date: String) throws -> IssueContents {
        try queue.read { db in
            func load<T: FetchableRecord & TableRecord>(_ type: T.Type) throws -> [T] {
                try T.fetchAll(db, sql: """
                    SELECT t.* FROM \(T.databaseTableName) t
                    JOIN items i ON i.id = t.id
                    WHERE i.status = 'filed' AND i.publishDate = ?
                    ORDER BY i.uploadedAt, i.rowid
                    """, arguments: [date])
            }
            let number = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(DISTINCT publishDate) FROM items WHERE status = 'filed' AND publishDate <= ?",
                arguments: [date]
            ) ?? 0
            return IssueContents(
                date: date,
                number: max(number, 1),
                mode: try Self.mode(date, in: db),
                stories: try load(Story.self),
                agendaPoints: try load(AgendaPoint.self),
                quotedItems: try load(QuotedItem.self),
                advertisements: try load(Advertisement.self)
            )
        }
    }

    private static func mode(_ date: String, in db: Database) throws -> EditionMode {
        let raw = try String.fetchOne(db, sql: "SELECT mode FROM issues WHERE issueDate = ?", arguments: [date])
        return raw.flatMap(EditionMode.init(rawValue:)) ?? .prominent
    }
}
