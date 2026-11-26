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

    package var label: String { itemKind.label }

    /// A file to fill in. Every template is also a valid upload (see the tests).
    package var template: String {
        switch self {
        case .story:
            """
            ---
            # Fill in the fields, then load this file on the contribute page.
            category: news          # news, background or opinion
            title: Your headline
            summary: >
              Two or three sentences that tell readers what the story is about.
            extendedSummary: >      # optional, delete if not needed
              A little more detail.
            ---
            Write your article here. You can use markdown.

            ## A subheading

            - a list item
            - [a link](https://example.com)

            """
        case .agenda:
            """
            ---
            # Fill in the fields, then load this file on the contribute page.
            subject: What is happening
            place: Where it is happening
            link: https://example.com
            eventDate: 2027-01-15T14:00:00+01:00     # optional
            summary: >
              A sentence or two about the event.
            ---

            """
        case .quote:
            """
            ---
            # Fill in the fields, then load this file on the contribute page.
            quote: The words that were said, without quotation marks.
            speaker: Who said them
            context: >
              When and where it was said, and why it matters.
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
            do { return try work() } catch { problems.append("\(error)"); return nil }
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

        let name = text("name", "Your name", SubmissionLimits.name)
        var email = ""
        if let valid = try? PaperDatabase.normalised(email: fields["email"]), valid.count <= emailLimit {
            email = valid
        } else {
            problems.append("Enter a valid email address.")
        }

        let item: ParsedUpload?
        switch kind {
        case .story:
            let category = StoryCategory(rawValue: fields["category"])
            if category == nil { problems.append("Choose a category.") }
            let title = text("title", "Headline", SubmissionLimits.title)
            let summary = text("summary", "Summary", SubmissionLimits.summary)
            let extended = optional("extendedSummary", "Extended summary", SubmissionLimits.summary)
            let body = fields["body"].trimmingCharacters(in: .whitespacesAndNewlines)
            if body.isEmpty { problems.append("Write the article text.") }
            if body.count > SubmissionLimits.body {
                problems.append("\(SubmissionError.tooLong("Article text", SubmissionLimits.body))")
            }

            if let image {
                let alt = text("altText", "Description of the picture", SubmissionLimits.title)
                let caption = optional("caption", "Caption", SubmissionLimits.title)
                let credit = optional("credit", "Picture credit", SubmissionLimits.name)
                if image.count > StoryForm.maxImageBytes {
                    problems.append("The picture is larger than \(StoryForm.maxImageBytes / 1024 / 1024) MB.")
                } else if let cleaned = ImageCleaner.clean(image) {
                    picture = NewPicture(
                        data: cleaned.data, mimeType: cleaned.mimeType,
                        text: PictureText(altText: alt, caption: caption, credit: credit)
                    )
                } else {
                    problems.append("The picture must be a JPEG, PNG or WebP file.")
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
                if eventDate == nil { problems.append("The date and time of the event are not valid.") }
            }
            item = .agendaPoint(AgendaPoint(
                subject: text("subject", "Subject", SubmissionLimits.title),
                place: text("place", "Place", SubmissionLimits.name),
                link: link("link", "Link"),
                summary: text("summary", "Summary", SubmissionLimits.summary),
                eventDate: eventDate
            ))

        case .quote:
            item = .quotedItem(QuotedItem(
                quote: text("quote", "Quote", SubmissionLimits.summary),
                speaker: text("speaker", "Speaker", SubmissionLimits.name),
                context: text("context", "Context", SubmissionLimits.summary),
                sourceLink: link("sourceLink", "Source link")
            ))
        }

        guard problems.isEmpty, let item else { throw FormProblems(messages: problems) }
        return (item, Contributor(name: name, email: email), picture)
    }
}
