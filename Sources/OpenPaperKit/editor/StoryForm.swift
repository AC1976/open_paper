import Foundation

/// Dates as the editor forms show them, in the paper's time zone.
package enum EditorDates {
    private static let paperTimeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .current

    package static func dateTime(_ date: Date) -> String { format(date, "yyyy-MM-dd'T'HH:mm") }

    /// "2026-11-20T06:00" from a `datetime-local` input; nil when empty or invalid.
    package static func parseDateTime(_ text: String) -> Date? {
        let formatter = makeFormatter("yyyy-MM-dd'T'HH:mm")
        return formatter.date(from: text)
    }

    /// "2026-11-20" → midnight that day in the paper's time zone; nil unless it is a real date.
    package static func parseDay(_ text: String) -> Date? {
        makeFormatter("yyyy-MM-dd").date(from: text)
    }

    package static func day(_ date: Date) -> String { format(date, "yyyy-MM-dd") }

    package static func today() -> String { day(Date()) }

    /// For the inbox list: "20 Nov 2026, 06:00".
    package static func display(_ date: Date) -> String { format(date, "d MMM yyyy, HH:mm") }

    private static func format(_ date: Date, _ pattern: String) -> String {
        makeFormatter(pattern).string(from: date)
    }

    private static func makeFormatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = paperTimeZone
        formatter.dateFormat = pattern
        return formatter
    }
}

/// Why a submitted form was not accepted: one message per problem.
package struct FormProblems: Error, Sendable {
    package let messages: [String]
}

/// Reading fields out of a submitted form, collecting problems instead of stopping at the first.
struct FormReader {
    let form: MultipartForm
    var problems: [String] = []

    init(_ form: MultipartForm) { self.form = form }

    mutating func required(_ name: String, _ label: String) -> String {
        guard let value = form.text(name) else {
            problems.append("\(label) is required.")
            return ""
        }
        return value
    }

    /// A required web address. Only http(s) links are accepted, so a pasted
    /// `javascript:` address cannot end up in a link on the page.
    mutating func requiredLink(_ name: String, _ label: String) -> String {
        let value = required(name, label)
        if !value.isEmpty, !(value.hasPrefix("https://") || value.hasPrefix("http://")) {
            problems.append("\(label) must start with http:// or https://.")
        }
        return value
    }

    mutating func date(_ name: String, _ label: String) -> Date? {
        guard let text = form.text(name) else { return nil }
        guard let date = EditorDates.parseDateTime(text) else {
            problems.append("\(label) is not a valid date and time.")
            return nil
        }
        return date
    }

    /// The image the form describes: a chosen file, else an address, else the
    /// uploaded image the item already had (unless "remove" is ticked). An image
    /// given by address is not kept: the address field shows it, so clearing
    /// the field removes it.
    mutating func imageSource(keeping existing: ImageSource?) -> ImageSource? {
        if form.text("removeImage") != nil { return nil }
        if let file = form.file("imageFile") {
            guard let type = file.contentType?.lowercased(), StoryForm.imageTypes.contains(type) else {
                problems.append("The image must be a JPEG, PNG or WebP file.")
                return existing
            }
            guard file.data.count <= StoryForm.maxImageBytes else {
                problems.append("The image is larger than \(StoryForm.maxImageBytes / 1024 / 1024) MB.")
                return existing
            }
            return .blob(data: file.data, mimeType: type)
        }
        if let url = form.text("image.source.endpoint.url") { return .endpoint(url: url) }
        if case .blob? = existing { return existing }
        return nil
    }

    func uuid() -> UUID { form.text("id").flatMap(UUID.init(uuidString:)) ?? UUID() }

    func finish() throws {
        if !problems.isEmpty { throw FormProblems(messages: problems) }
    }
}

/// Turns the submitted story form (`ReviewCard`) back into a `Story`.
package enum StoryForm {
    /// Largest image accepted until image processing (step 4b) exists.
    package static let maxImageBytes = 5 * 1024 * 1024
    static let imageTypes: Set<String> = ["image/jpeg", "image/png", "image/webp"]

    package typealias Problems = FormProblems

    /// `existing` is the story being edited; its stored image is kept when the
    /// form does not choose a new one.
    package static func story(from form: MultipartForm, keeping existing: Story? = nil) throws -> (story: Story, body: String) {
        var reader = FormReader(form)

        let title = reader.required("title", "Title")
        let slug = reader.required("slug", "Slug")
        let summary = reader.required("summary", "Summary")

        let category = form.text("category").flatMap(StoryCategory.init(rawValue:))
        if category == nil { reader.problems.append("Choose a category.") }

        let priority = form.text("priority").flatMap(Int.init).flatMap(StoryPriority.init(rawValue:))
        if priority == nil { reader.problems.append("Choose a priority.") }

        let publishedAt = reader.date("publishedAt", "Published")
        let updatedAt = reader.date("updatedAt", "Updated")

        var image: StoryImage?
        if let source = reader.imageSource(keeping: existing?.image?.source) {
            if let alt = form.text("image.altText") {
                image = StoryImage(source: source, altText: alt, caption: form.text("image.caption"), credit: form.text("image.credit"))
            } else {
                reader.problems.append("Alt text is required when the story has an image.")
            }
        }

        if let slug = form.text("slug"), slug.contains(where: { !($0.isLetter || $0.isNumber || $0 == "-") }) {
            reader.problems.append("Slug may only contain letters, numbers and hyphens.")
        }

        try reader.finish()
        guard let category, let priority else { throw FormProblems(messages: reader.problems) }

        let story = Story(
            id: reader.uuid(),
            category: category,
            priority: priority,
            title: title,
            summary: summary,
            extendedSummary: form.text("extendedSummary"),
            slug: slug,
            publishedAt: publishedAt,
            updatedAt: updatedAt,
            author: form.text("author"),
            image: image
        )
        return (story, form.rawText("body") ?? "")
    }
}

/// Turns the submitted agenda, quote and advertisement forms back into models.
package enum ItemForm {
    package static func agendaPoint(from form: MultipartForm) throws -> AgendaPoint {
        var reader = FormReader(form)
        let subject = reader.required("subject", "Subject")
        let place = reader.required("place", "Place")
        let link = reader.requiredLink("link", "Link")
        let summary = reader.required("summary", "Summary")
        let eventDate = reader.date("eventDate", "Date")
        try reader.finish()
        return AgendaPoint(id: reader.uuid(), subject: subject, place: place, link: link, summary: summary, eventDate: eventDate)
    }

    package static func quotedItem(from form: MultipartForm) throws -> QuotedItem {
        var reader = FormReader(form)
        let quote = reader.required("quote", "Quote")
        let speaker = reader.required("speaker", "Speaker")
        let context = reader.required("context", "Context")
        let sourceLink = reader.requiredLink("sourceLink", "Source link")
        try reader.finish()
        return QuotedItem(id: reader.uuid(), quote: quote, speaker: speaker, context: context, sourceLink: sourceLink)
    }

    /// `existing` is the advertisement being edited; its image is kept unless a new one is chosen.
    package static func advertisement(from form: MultipartForm, keeping existing: Advertisement? = nil) throws -> Advertisement {
        var reader = FormReader(form)
        let sponsor = reader.required("sponsorName", "Sponsor")
        let target = reader.requiredLink("targetURL", "Link")
        let alt = reader.required("image.altText", "Alt text")
        let priority = form.text("priority").flatMap(Int.init).flatMap(StoryPriority.init(rawValue:))
        if priority == nil { reader.problems.append("Choose a priority.") }

        var source = reader.imageSource(keeping: existing?.imageSource)
        if form.text("removeImage") != nil { source = existing?.imageSource }   // an advertisement always has an image
        if source == nil { reader.problems.append("An image is required: choose a file or give an address.") }

        try reader.finish()
        guard let priority, let source else { throw FormProblems(messages: reader.problems) }
        return Advertisement(
            id: reader.uuid(), sponsorName: sponsor, imageSource: source,
            altText: alt, targetURL: target, priority: priority
        )
    }
}

extension PaperDatabase {
    /// Saves whichever kind of item was parsed, and discards its staged upload.
    @discardableResult
    package func save(_ parsed: ParsedUpload, discarding stagedID: UUID?) throws -> SaveOutcome {
        switch parsed {
        case .story(let story, let markdown, _): try save(story, body: markdown, discarding: stagedID)
        case .agendaPoint(let item): try save(item, discarding: stagedID)
        case .quotedItem(let item): try save(item, discarding: stagedID)
        case .advertisement(let item): try save(item, discarding: stagedID)
        }
    }
}
