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

    /// True for a real date written exactly as "yyyy-MM-dd".
    package static func isDay(_ text: String) -> Bool {
        parseDay(text).map(day) == text
    }

    /// "Friday, November 20, 2026" for a "yyyy-MM-dd" day.
    package static func longDay(_ text: String) -> String {
        parseDay(text).map { format($0, "EEEE, MMMM d, yyyy") } ?? text
    }

    /// One day as `longDay`; a longer run as "first day to last day".
    package static func run(from first: String, until last: String?) -> String {
        guard let last, last != first else { return longDay(first) }
        return "\(longDay(first)) to \(longDay(last))"
    }

    /// "20 Nov" for a "yyyy-MM-dd" day, as the news desk list shows it.
    package static func shortDay(_ text: String) -> String {
        parseDay(text).map { format($0, "d MMM") } ?? text
    }

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

    /// A chosen picture file, checked and cleaned; nil when none was chosen or
    /// it is not acceptable (which is recorded as a problem).
    private mutating func chosenImage() -> (data: Data, mimeType: String)? {
        guard let file = form.file("imageFile") else { return nil }
        guard file.data.count <= StoryForm.maxImageBytes else {
            problems.append("The image is larger than \(StoryForm.maxImageBytes / 1024 / 1024) MB.")
            return nil
        }
        // The bytes decide what it is; metadata is removed and big pictures are scaled down.
        guard let image = ImageResizer.accept(file.data) else {
            problems.append("The image must be a JPEG, PNG or WebP file of at most 60 megapixels.")
            return nil
        }
        return image
    }

    /// What the story form asks for its picture: remove it, a new file, new
    /// words for the current one, or nothing.
    mutating func pictureChange(hasPicture: Bool) -> PictureChange {
        if form.text("removeImage") != nil { return .remove }
        let chosen = chosenImage()
        guard chosen != nil || hasPicture else { return .unchanged }
        guard let alt = form.text("altText") else {
            problems.append("Alt text is required when the story has an image.")
            return .unchanged
        }
        let text = PictureText(altText: alt, caption: form.text("caption"), credit: form.text("credit"))
        if let chosen { return .replace(NewPicture(data: chosen.data, mimeType: chosen.mimeType, text: text)) }
        return .describe(text)
    }

    /// An advertisement's image: a chosen file, else an address, else the
    /// uploaded image it already had.
    mutating func imageSource(keeping existing: ImageSource?) -> ImageSource? {
        if form.file("imageFile") != nil {
            return chosenImage().map { .blob(data: $0.data, mimeType: $0.mimeType) } ?? existing
        }
        if let url = form.text("image.source.endpoint.url") { return .endpoint(url: url) }
        // A stored picture is not shown as an address in the form, so keep it.
        if case .blob? = existing { return existing }
        if case .endpoint(let url)? = existing, url.hasPrefix("/images/") { return existing }
        return nil
    }

    func uuid() -> UUID { form.text("id").flatMap(UUID.init(uuidString:)) ?? UUID() }

    func finish() throws {
        if !problems.isEmpty { throw FormProblems(messages: problems) }
    }
}

/// Turns the submitted story form (`StoryInputs`) back into a `Story`.
package enum StoryForm {
    /// Largest picture file accepted. It is scaled down before it is stored.
    package static let maxImageBytes = 15 * 1024 * 1024

    package typealias Problems = FormProblems

    /// `existing` is the story being edited; `hasPicture` says whether it has a
    /// picture, which is then kept unless the form replaces or removes it.
    package static func story(
        from form: MultipartForm, keeping existing: Story? = nil, hasPicture: Bool = false
    ) throws -> (story: Story, body: String, picture: PictureChange) {
        var reader = FormReader(form)

        let title = reader.required("title", "Title")
        let slug = reader.required("slug", "Slug")
        let summary = reader.required("summary", "Summary")

        let category = form.text("category").flatMap(StoryCategory.init(rawValue:))
        if category == nil { reader.problems.append("Choose a category.") }

        let priority = form.text("priority").flatMap(Int.init).flatMap(StoryPriority.init(rawValue:))
        if priority == nil { reader.problems.append("Choose a priority.") }

        // The form has no date fields (the publish date is set by filing),
        // so dates that came with the upload are kept.
        let publishedAt = form.rawText("publishedAt") == nil ? existing?.publishedAt : reader.date("publishedAt", "Published")
        let updatedAt = form.rawText("updatedAt") == nil ? existing?.updatedAt : reader.date("updatedAt", "Updated")

        let picture = reader.pictureChange(hasPicture: hasPicture)

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
            author: form.text("author")
        )
        return (story, form.rawText("body") ?? "", picture)
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

        let source = reader.imageSource(keeping: existing?.imageSource)
        if source == nil { reader.problems.append("An image is required: choose a file or give an address.") }

        try reader.finish()
        guard let priority, let source else { throw FormProblems(messages: reader.problems) }
        return Advertisement(
            id: reader.uuid(), sponsorName: sponsor, imageSource: source,
            altText: alt, targetURL: target, priority: priority
        )
    }
}
