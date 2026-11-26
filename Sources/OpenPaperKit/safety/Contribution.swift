import Foundation

/// Who sent something in. The name may appear in the paper; the email address
/// is only shown to editors.
package struct Contributor: Sendable, Equatable {
    package let name: String
    package let email: String

    package init(name: String, email: String) {
        self.name = name
        self.email = email
    }
}

/// What the public may send in. Advertisements are editors' business.
package enum ContributionKind: String, CaseIterable, Sendable {
    case story, agenda, quote

    package var itemKind: ItemKind {
        switch self {
        case .story: .story
        case .agenda: .agendaPoint
        case .quote: .quotedItem
        }
    }

    /// The name contributors see.
    package var label: String {
        switch self {
        case .story: "Artikel"
        case .agenda: "Agendapunt"
        case .quote: "Quote"
        }
    }

    /// As used in a sentence: "het sjabloon voor een artikel".
    package var phrase: String {
        switch self {
        case .story: "een artikel"
        case .agenda: "een agendapunt"
        case .quote: "een quote"
        }
    }

    /// A file to fill in. Every template is also a valid upload (see the tests).
    package var template: String {
        switch self {
        case .story:
            """
            ---
            # Vul de velden in en laad dit bestand op de pagina "Schrijf mee".
            category: news          # news (nieuws), background (achtergrond) of opinion (opinie)
            title: Je kop
            summary: >
              Twee of drie zinnen die vertellen waar het artikel over gaat.
            extendedSummary: >      # optioneel, verwijder als je dit niet nodig hebt
              Iets meer uitleg.
            ---
            Schrijf hier je artikel. Je kunt markdown gebruiken.

            ## Een tussenkop

            - een punt in een lijst
            - [een link](https://example.com)

            """
        case .agenda:
            """
            ---
            # Vul de velden in en laad dit bestand op de pagina "Schrijf mee".
            subject: Wat er gebeurt
            place: Waar het gebeurt
            link: https://example.com
            eventDate: 2027-01-15T14:00:00+01:00     # optioneel
            summary: >
              Een of twee zinnen over de gebeurtenis.
            ---

            """
        case .quote:
            """
            ---
            # Vul de velden in en laad dit bestand op de pagina "Schrijf mee".
            quote: De woorden die gezegd zijn, zonder aanhalingstekens.
            speaker: Wie ze zei
            context: >
              Wanneer en waar het gezegd is, en waarom het ertoe doet.
            sourceLink: https://example.com
            ---

            """
        }
    }
}

/// The fields of the contribute form, as text, so a page can be shown again
/// with everything the contributor typed.
package struct ContributionFields: Sendable, Equatable {
    private var values: [String: String]

    package static let names = [
        "name", "email",
        "category", "title", "summary", "extendedSummary", "body", "altText", "caption", "credit",
        "subject", "place", "link", "eventDate",
        "quote", "speaker", "context", "sourceLink",
    ]

    package init(_ values: [String: String] = [:]) { self.values = values }

    package init(form: MultipartForm) {
        values = [:]
        for name in Self.names {
            if let value = form.rawText(name) { values[name] = value.replacingOccurrences(of: "\r\n", with: "\n") }
        }
    }

    package subscript(_ name: String) -> String {
        get { values[name] ?? "" }
        set { values[name] = newValue }
    }

    /// Fills the item's fields from an uploaded template, keeping name and email.
    package mutating func fill(from parsed: ParsedUpload) {
        switch parsed {
        case .story(let story, let markdown, _):
            self["category"] = story.category.rawValue
            self["title"] = story.title
            self["summary"] = story.summary
            self["extendedSummary"] = story.extendedSummary ?? ""
            self["body"] = markdown
        case .agendaPoint(let point):
            self["subject"] = point.subject
            self["place"] = point.place
            self["link"] = point.link
            self["summary"] = point.summary
            self["eventDate"] = point.eventDate.map(EditorDates.dateTime) ?? ""
        case .quotedItem(let item):
            self["quote"] = item.quote
            self["speaker"] = item.speaker
            self["context"] = item.context
            self["sourceLink"] = item.sourceLink
        case .advertisement:
            break
        }
    }
}

package enum ContributionForm {
    package static let emailLimit = 254

    /// Checks a submitted form. All problems are reported at once.
    package static func read(
        _ kind: ContributionKind, fields: ContributionFields, image: Data? = nil
    ) throws -> (item: ParsedUpload, contributor: Contributor, picture: NewPicture?) {
        var picture: NewPicture?
        var problems: [String] = []

        func check<T>(_ work: () throws -> T) -> T? {
            do {
                return try work()
            } catch {
                problems.append((error as? SubmissionError)?.dutch ?? "\(error)")
                return nil
            }
        }
        func text(_ name: String, _ label: String, _ limit: Int) -> String {
            check { try Check.text(fields[name], label, limit) } ?? ""
        }
        func optional(_ name: String, _ label: String, _ limit: Int) -> String? {
            check { try Check.optional(fields[name], label, limit) } ?? nil
        }
        func link(_ name: String, _ label: String) -> String {
            check { try Check.link(fields[name], label) } ?? ""
        }

        let name = text("name", "Je naam", SubmissionLimits.name)
        var email = ""
        if let valid = try? PaperDatabase.normalised(email: fields["email"]), valid.count <= emailLimit {
            email = valid
        } else {
            problems.append("Vul een geldig e-mailadres in.")
        }

        let item: ParsedUpload?
        switch kind {
        case .story:
            let category = StoryCategory(rawValue: fields["category"])
            if category == nil { problems.append("Kies een rubriek.") }
            let title = text("title", "Kop", SubmissionLimits.title)
            let summary = text("summary", "Samenvatting", SubmissionLimits.summary)
            let extended = optional("extendedSummary", "Uitgebreide samenvatting", SubmissionLimits.summary)
            let body = fields["body"].trimmingCharacters(in: .whitespacesAndNewlines)
            if body.isEmpty { problems.append("Schrijf de tekst van het artikel.") }
            if body.count > SubmissionLimits.body {
                problems.append(SubmissionError.tooLong("Tekst", SubmissionLimits.body).dutch)
            }

            if let image {
                let alt = text("altText", "Beschrijving van de foto", SubmissionLimits.title)
                let caption = optional("caption", "Bijschrift", SubmissionLimits.title)
                let credit = optional("credit", "Fotograaf of bron", SubmissionLimits.name)
                if image.count > StoryForm.maxImageBytes {
                    problems.append("De foto is groter dan \(StoryForm.maxImageBytes / 1024 / 1024) MB.")
                } else if let cleaned = ImageResizer.accept(image) {
                    picture = NewPicture(
                        data: cleaned.data, mimeType: cleaned.mimeType,
                        text: PictureText(altText: alt, caption: caption, credit: credit)
                    )
                } else {
                    problems.append("De foto moet een JPEG-, PNG- of WebP-bestand zijn van maximaal 60 megapixels.")
                }
            }
            item = category.map {
                .story(Story(
                    category: $0, priority: .normal, title: title, summary: summary, extendedSummary: extended,
                    slug: Slug.make(from: title), author: name
                ), markdown: body, html: "")
            }

        case .agenda:
            var eventDate: Date?
            if !fields["eventDate"].isEmpty {
                eventDate = EditorDates.parseDateTime(fields["eventDate"])
                if eventDate == nil { problems.append("De datum en tijd van de gebeurtenis kloppen niet.") }
            }
            item = .agendaPoint(AgendaPoint(
                subject: text("subject", "Onderwerp", SubmissionLimits.title),
                place: text("place", "Plaats", SubmissionLimits.name),
                link: link("link", "Link"),
                summary: text("summary", "Samenvatting", SubmissionLimits.summary),
                eventDate: eventDate
            ))

        case .quote:
            item = .quotedItem(QuotedItem(
                quote: text("quote", "Quote", SubmissionLimits.summary),
                speaker: text("speaker", "Spreker", SubmissionLimits.name),
                context: text("context", "Context", SubmissionLimits.summary),
                sourceLink: link("sourceLink", "Link naar de bron")
            ))
        }

        guard problems.isEmpty, let item else { throw FormProblems(messages: problems) }
        return (item, Contributor(name: name, email: email), picture)
    }
}
