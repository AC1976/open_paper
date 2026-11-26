import Foundation
import GRDB

// Uploads are treated as coming from strangers. Only the fields a contributor
// may choose are read; `id`, `slug`, priority, dates and story image addresses
// in a file are ignored. Editors set those on the review page.

package enum SubmissionError: Error, CustomStringConvertible, Sendable, Equatable {
    case fileTooLarge
    case aliasesNotAllowed
    case missing(String)
    case tooLong(String, Int)
    case badLink(String)

    package var description: String {
        switch self {
        case .fileTooLarge: "The file is larger than \(SubmissionLimits.fileBytes / 1000) KB."
        case .aliasesNotAllowed: "YAML anchors and aliases (& and *) are not allowed."
        case .missing(let field): "\"\(field)\" must not be empty."
        case .tooLong(let field, let limit): "\"\(field)\" is longer than \(limit) characters."
        case .badLink(let field): "\"\(field)\" must start with http:// or https://."
        }
    }
}

package enum SubmissionLimits {
    package static let fileBytes = 100_000
    package static let title = 200
    package static let name = 120
    package static let summary = 1_000
    package static let link = 500
    package static let body = 60_000
}

private struct StoryFields: Decodable {
    let category: StoryCategory
    let title: String
    let summary: String
    let extendedSummary: String?
    let author: String?
}

private struct AgendaFields: Decodable {
    let subject: String
    let place: String
    let link: String
    let summary: String
    let eventDate: Date?
}

private struct QuoteFields: Decodable {
    let quote: String
    let speaker: String
    let context: String
    let sourceLink: String
}

/// Advertisements are only uploaded by editors, so they may name an image address.
private struct AdvertisementFields: Decodable {
    let sponsorName: String
    let imageSource: ImageSource
    let altText: String
    let targetURL: String
}

extension ParsedUpload {
    /// Reads an uploaded markdown file as a new submission.
    package init(kind: ItemKind, text: String, name: String) throws {
        guard text.utf8.count <= SubmissionLimits.fileBytes else { throw SubmissionError.fileTooLarge }
        try Check.noAliases(in: text)

        switch kind {
        case .story:
            let upload = try parseUpload(StoryFields.self, text: text, name: name)
            let fields = upload.item
            let title = try Check.text(fields.title, "title", SubmissionLimits.title)
            let story = Story(
                category: fields.category,
                priority: .normal,
                title: title,
                summary: try Check.text(fields.summary, "summary", SubmissionLimits.summary),
                extendedSummary: try Check.optional(fields.extendedSummary, "extendedSummary", SubmissionLimits.summary),
                slug: Slug.make(from: title),
                author: try Check.optional(fields.author, "author", SubmissionLimits.name)
            )
            guard upload.markdown.count <= SubmissionLimits.body else {
                throw SubmissionError.tooLong("article text", SubmissionLimits.body)
            }
            self = .story(story, markdown: upload.markdown, html: upload.html)

        case .agendaPoint:
            let fields = try parseUpload(AgendaFields.self, text: text, name: name).item
            self = .agendaPoint(AgendaPoint(
                subject: try Check.text(fields.subject, "subject", SubmissionLimits.title),
                place: try Check.text(fields.place, "place", SubmissionLimits.name),
                link: try Check.link(fields.link, "link"),
                summary: try Check.text(fields.summary, "summary", SubmissionLimits.summary),
                eventDate: fields.eventDate
            ))

        case .quotedItem:
            let fields = try parseUpload(QuoteFields.self, text: text, name: name).item
            self = .quotedItem(QuotedItem(
                quote: try Check.text(fields.quote, "quote", SubmissionLimits.summary),
                speaker: try Check.text(fields.speaker, "speaker", SubmissionLimits.name),
                context: try Check.text(fields.context, "context", SubmissionLimits.summary),
                sourceLink: try Check.link(fields.sourceLink, "sourceLink")
            ))

        case .advertisement:
            let fields = try parseUpload(AdvertisementFields.self, text: text, name: name).item
            self = .advertisement(Advertisement(
                sponsorName: try Check.text(fields.sponsorName, "sponsorName", SubmissionLimits.name),
                imageSource: fields.imageSource,
                altText: try Check.text(fields.altText, "altText", SubmissionLimits.title),
                targetURL: try Check.link(fields.targetURL, "targetURL")
            ))
        }
    }
}

enum Check {
    static func text(_ value: String, _ field: String, _ limit: Int) throws -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw SubmissionError.missing(field) }
        guard value.count <= limit else { throw SubmissionError.tooLong(field, limit) }
        return value
    }

    static func optional(_ value: String?, _ field: String, _ limit: Int) throws -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try text(value, field, limit)
    }

    static func link(_ value: String, _ field: String) throws -> String {
        let value = try text(value, field, SubmissionLimits.link)
        guard value.hasPrefix("https://") || value.hasPrefix("http://") else { throw SubmissionError.badLink(field) }
        return value
    }

    /// A handful of YAML aliases can expand into gigabytes while a file is
    /// read, so none are allowed. An alias needs an anchor of the same name, so
    /// the file is refused when a name appears as both `&name` and `*name`.
    static func noAliases(in file: String) throws {
        // Only the front matter is YAML; the article text may say what it likes.
        // Split exactly where `parseUpload` splits.
        let file = file.replacingOccurrences(of: "\r\n", with: "\n")
        guard file.hasPrefix("---\n"),
              let end = file.range(of: "\n---", range: file.index(file.startIndex, offsetBy: 4)..<file.endIndex)
        else { return }   // refused later: no front matter
        let text = String(file[file.startIndex..<end.lowerBound])

        let before = "(?:^|[\\s\\[\\]{},:])"
        let anchors = try NSRegularExpression(pattern: before + "&([^\\s\\[\\]{},]+)", options: .anchorsMatchLines)
        let all = NSRange(text.startIndex..., in: text)
        let names = Set(anchors.matches(in: text, range: all).compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } })
        for name in names {
            let alias = before + "\\*" + NSRegularExpression.escapedPattern(for: name) + "(?=$|[\\s\\[\\]{},:])"
            let regex = try NSRegularExpression(pattern: alias, options: .anchorsMatchLines)
            if regex.firstMatch(in: text, range: all) != nil { throw SubmissionError.aliasesNotAllowed }
        }
    }
}

/// Web addresses made from titles.
package enum Slug {
    package static let maximumLength = 80

    /// "Café: the slow return!" → "cafe-the-slow-return".
    package static func make(from title: String) -> String {
        let plain = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let words = plain.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
        var slug = words.joined(separator: "-").lowercased()
        if slug.count > maximumLength {
            slug = String(slug.prefix(maximumLength))
            while slug.hasSuffix("-") { slug.removeLast() }
        }
        return slug.isEmpty ? "article" : slug
    }
}

extension PaperDatabase {
    /// Puts a new item on the news desk. A submission never changes an existing
    /// item: it always gets a new id, and a story whose slug is taken gets a
    /// number added to it.
    @discardableResult
    package func submit(
        _ parsed: ParsedUpload, from contributor: Contributor? = nil, discarding stagedID: UUID? = nil
    ) throws -> UUID {
        let id = UUID()
        try queue.write { db in
            try Self.register(id, kind: parsed.kind, in: db)
            switch parsed {
            case .story(let story, let markdown, _):
                var slug = story.slug
                var number = 2
                while try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM stories WHERE slug = ?", arguments: [slug]) != 0 {
                    slug = "\(story.slug)-\(number)"
                    number += 1
                }
                try story.with(id: id, slug: slug).insert(db)
                try db.execute(sql: "UPDATE stories SET body = ? WHERE id = ?", arguments: [markdown, id.uuidString])
            case .agendaPoint(let p):
                try AgendaPoint(id: id, subject: p.subject, place: p.place, link: p.link, summary: p.summary, eventDate: p.eventDate).insert(db)
            case .quotedItem(let q):
                try QuotedItem(id: id, quote: q.quote, speaker: q.speaker, context: q.context, sourceLink: q.sourceLink).insert(db)
            case .advertisement(let a):
                try Advertisement(
                    id: id, sponsorName: a.sponsorName, imageSource: a.imageSource,
                    altText: a.altText, targetURL: a.targetURL, priority: a.priority
                ).insert(db)
            }
            if let contributor {
                try db.execute(
                    sql: "UPDATE items SET contributorName = ?, contributorEmail = ? WHERE id = ?",
                    arguments: [contributor.name, contributor.email, id.uuidString]
                )
            }
            try Self.discard(stagedID, in: db)
        }
        return id
    }

    /// Saves an editor's changes to the item `id`. The id comes from the page
    /// being edited, so a changed form field cannot redirect the save.
    package func update(_ edited: ParsedUpload, id: UUID) throws {
        guard try entry(id)?.kind == edited.kind else { throw SaveError.noSuchItem }
        switch edited {
        case .story(let story, let markdown, _):
            try save(story.with(id: id), body: markdown)
        case .agendaPoint(let p):
            try save(AgendaPoint(id: id, subject: p.subject, place: p.place, link: p.link, summary: p.summary, eventDate: p.eventDate))
        case .quotedItem(let q):
            try save(QuotedItem(id: id, quote: q.quote, speaker: q.speaker, context: q.context, sourceLink: q.sourceLink))
        case .advertisement(let a):
            try save(Advertisement(
                id: id, sponsorName: a.sponsorName, imageSource: a.imageSource,
                altText: a.altText, targetURL: a.targetURL, priority: a.priority
            ))
        }
    }
}
