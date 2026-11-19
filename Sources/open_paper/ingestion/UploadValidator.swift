import Foundation

/// Collects problems while checking one upload.
struct IssueList {
    private(set) var all: [IngestionIssue] = []
    /// Set when something must be fixed before the item can be published.
    private(set) var isHeld = false

    var errorCount: Int { all.filter { $0.severity == .error }.count }

    mutating func error(_ field: String, _ message: String) {
        all.append(IngestionIssue(severity: .error, field: field, message: message))
    }

    mutating func warning(_ field: String, _ message: String) {
        all.append(IngestionIssue(severity: .warning, field: field, message: message))
    }

    /// A warning that also keeps the item in `draft`.
    mutating func hold(_ field: String, _ message: String) {
        warning(field, "\(message) (held as draft)")
        isHeld = true
    }
}

/// Field-level checks, plus the per-type rules that turn upload shapes into models.
final class UploadValidator {
    var issues = IssueList()
    let now: Date
    let timeZone: TimeZone

    init(now: Date, timeZone: TimeZone) {
        self.now = now
        self.timeZone = timeZone
    }

    // MARK: - Item types

    func story(_ upload: StoryUpload, id: UUID, body: String) -> IngestedItem? {
        let errorsBefore = issues.errorCount

        let category = choice(upload.category, "category", as: StoryCategory.self, required: true)
        let priority = self.priority(upload.priority, "priority")
        let title = text(upload.title, "title", required: true)
        let slug = self.slug(upload.slug, "slug")
        let summary = text(upload.summary, "summary", required: true)
        let extendedSummary = text(upload.extendedSummary, "extendedSummary")
        let author = text(upload.author, "author")
        let publishedAt = dateTime(upload.publishedAt, "publishedAt")
        let updatedAt = dateTime(upload.updatedAt, "updatedAt")
        let image = upload.image.flatMap { self.image($0, forAdvertisement: false) }

        if let publishedAt, let updatedAt, updatedAt < publishedAt {
            issues.warning("updatedAt", "is earlier than publishedAt")
        }
        if extendedSummary != nil, let category, let priority,
           !(category == .news && priority == .high) {
            issues.warning("extendedSummary", "is only shown on the front page for high-priority news")
        }
        if body.isEmpty {
            issues.warning("body", "has no article text; the article page will only show the summary")
        }

        guard issues.errorCount == errorsBefore,
              let category, let priority, let title, let slug, let summary
        else { return nil }

        // A linked image needs no further work, so it can go on the story right away.
        var storyImage: StoryImage?
        if let image, image.storage == .link, let url = image.url {
            storyImage = image.storyImage(source: .endpoint(url: url))
        }

        let story = Story(
            id: id,
            category: category,
            priority: priority,
            title: title,
            summary: summary,
            extendedSummary: extendedSummary,
            slug: slug,
            publishedAt: publishedAt,
            updatedAt: updatedAt,
            author: author,
            image: storyImage,
            body: body.isEmpty ? nil : body
        )
        return .story(story, image: image)
    }

    func agenda(_ upload: AgendaUpload, id: UUID) -> IngestedItem? {
        let errorsBefore = issues.errorCount

        let subject = text(upload.subject, "subject", required: true)
        let place = text(upload.place, "place", required: true)
        let link = webAddress(upload.link, "link", required: true)
        let summary = text(upload.summary, "summary", required: true)
        let eventDate = dateTime(upload.eventDate, "eventDate", allowDateOnly: true)

        guard issues.errorCount == errorsBefore,
              let subject, let place, let link, let summary
        else { return nil }

        return .agenda(AgendaPoint(
            id: id, subject: subject, place: place, link: link,
            summary: summary, eventDate: eventDate
        ))
    }

    func quoted(_ upload: QuotedUpload, id: UUID) -> IngestedItem? {
        let errorsBefore = issues.errorCount

        let quote = text(upload.quote, "quote", required: true)
        let speaker = text(upload.speaker, "speaker", required: true)
        let context = text(upload.context, "context", required: true)
        let sourceLink = webAddress(upload.sourceLink, "sourceLink", required: true)

        if let quote, let first = quote.first, "\"“”‘’'„«»".contains(first) {
            issues.warning("quote", "starts with a quotation mark; leave them out, the page adds them")
        }

        guard issues.errorCount == errorsBefore,
              let quote, let speaker, let context, let sourceLink
        else { return nil }

        return .quoted(QuotedItem(
            id: id, quote: quote, speaker: speaker,
            context: context, sourceLink: sourceLink
        ))
    }

    func advertisement(_ upload: AdvertisementUpload, id: UUID) -> IngestedItem? {
        let errorsBefore = issues.errorCount

        let sponsorName = text(upload.sponsorName, "sponsorName", required: true)
        let targetURL = webAddress(upload.targetURL, "targetURL", required: true)
        let priority = self.priority(upload.priority, "priority", default: .normal)
        let campaignStart = dateTime(upload.campaignStart, "campaignStart", allowDateOnly: true)
        let campaignEnd = dateTime(upload.campaignEnd, "campaignEnd", allowDateOnly: true)

        var image: ImageRequest?
        if let upload = upload.image {
            image = self.image(upload, forAdvertisement: true)
        } else {
            issues.error("image", "is required for advertisements")
        }

        if let campaignStart, let campaignEnd, campaignEnd < campaignStart {
            issues.error("campaignEnd", "is before campaignStart")
        } else if let campaignEnd, now >= endOfDay(campaignEnd) {
            issues.hold("campaignEnd", "has passed")
        }

        guard issues.errorCount == errorsBefore,
              let sponsorName, let targetURL, let priority, let image
        else { return nil }

        return .advertisement(AdvertisementDraft(
            id: id, sponsorName: sponsorName, targetURL: targetURL,
            priority: priority, image: image,
            campaignStart: campaignStart, campaignEnd: campaignEnd
        ))
    }

    // MARK: - Image block

    func image(_ upload: ImageUpload, forAdvertisement: Bool) -> ImageRequest? {
        let errorsBefore = issues.errorCount

        let file = text(upload.file, "image.file")
        let urlText = text(upload.url, "image.url")

        switch (file, urlText) {
        case (nil, nil):
            issues.error("image.file", "give either `file` (uploaded with this item) or `url` (a remote image)")
        case (.some, .some):
            issues.error("image.file", "give `file` or `url`, not both")
        default:
            break
        }

        if let file {
            let parts = file.split(whereSeparator: { $0 == "/" || $0 == "\\" })
            if file.hasPrefix("/") || file.hasPrefix("\\") || file.contains(":") || parts.contains("..") {
                issues.error("image.file", "must be a relative path inside the upload, e.g. images/photo.jpg")
            }
            let ext = (file as NSString).pathExtension.lowercased()
            if !["jpg", "jpeg", "png", "webp"].contains(ext) {
                issues.error("image.file", "must be a .jpg, .jpeg, .png or .webp file")
            }
        }
        let url = urlText == nil ? nil : webAddress(upload.url, "image.url")

        let storage = choice(upload.storage, "image.storage", as: ImageStorage.self, required: true)
        if storage == .link, file != nil {
            issues.error("image.storage", "'link' needs a `url`; use 'store' or 'embed' for an uploaded file")
        }

        let altText = text(upload.altText, "image.altText", required: true)
        var caption = text(upload.caption, "image.caption")
        var credit = text(upload.credit, "image.credit")
        if forAdvertisement {
            if caption != nil { issues.warning("image.caption", "is ignored for advertisements") }
            if credit != nil { issues.warning("image.credit", "is ignored for advertisements") }
            caption = nil
            credit = nil
        }

        var license = ImageLicense.unknown
        if text(upload.license, "image.license") == nil {
            issues.hold("image.license", "is missing")
        } else if let chosen = choice(upload.license, "image.license", as: ImageLicense.self) {
            license = chosen
            if chosen == .unknown { issues.hold("image.license", "is 'unknown'") }
        }

        let rightsHolder = text(upload.rightsHolder, "image.rightsHolder")
        let usageExpires = dateTime(upload.usageExpires, "image.usageExpires", allowDateOnly: true)
        if let usageExpires, now >= endOfDay(usageExpires) {
            issues.hold("image.usageExpires", "has passed")
        }

        var displayHint: ImageDisplayStyle?
        if let hint = text(upload.displayHint, "image.displayHint"), hint != "auto" {
            if let style = ImageDisplayStyle(rawValue: hint) {
                displayHint = style
            } else {
                let allowed = ["auto"] + ImageDisplayStyle.allCases.map(\.rawValue)
                issues.error("image.displayHint", "must be one of \(allowed.joined(separator: ", ")); got '\(hint)'")
            }
        }

        var focalPoint: FocalPoint?
        if let point = upload.focalPoint {
            let x = unitInterval(point.x, "image.focalPoint.x")
            let y = unitInterval(point.y, "image.focalPoint.y")
            if let x, let y { focalPoint = FocalPoint(x: x, y: y) }
        }

        let sensitive = boolean(upload.sensitive, "image.sensitive") ?? false

        guard issues.errorCount == errorsBefore, let storage, let altText else { return nil }

        return ImageRequest(
            file: file, url: url, storage: storage, altText: altText,
            caption: caption, credit: credit, license: license,
            rightsHolder: rightsHolder, usageExpires: usageExpires,
            displayHint: displayHint, focalPoint: focalPoint, sensitive: sensitive
        )
    }

    // MARK: - Field checks

    /// Trimmed text, or `nil` when empty. Reports an error if required and missing.
    func text(_ value: String?, _ field: String, required: Bool = false) -> String? {
        if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        if required { issues.error(field, "is required") }
        return nil
    }

    func choice<T: RawRepresentable & CaseIterable>(
        _ value: String?, _ field: String, as type: T.Type, required: Bool = false
    ) -> T? where T.RawValue == String {
        guard let raw = text(value, field, required: required) else { return nil }
        if let match = T(rawValue: raw) { return match }
        let allowed = T.allCases.map(\.rawValue).joined(separator: ", ")
        issues.error(field, "must be one of \(allowed); got '\(raw)'")
        return nil
    }

    /// `2` = high, `1` = normal: the raw values of `StoryPriority`.
    func priority(_ value: String?, _ field: String, default fallback: StoryPriority? = nil) -> StoryPriority? {
        guard let raw = text(value, field, required: fallback == nil) else { return fallback }
        if let number = Int(raw), let priority = StoryPriority(rawValue: number) { return priority }
        issues.error(field, "must be 2 (high) or 1 (normal); got '\(raw)'")
        return nil
    }

    func slug(_ value: String?, _ field: String) -> String? {
        guard let raw = text(value, field, required: true) else { return nil }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        let valid = raw.allSatisfy(allowed.contains)
            && !raw.hasPrefix("-") && !raw.hasSuffix("-") && !raw.contains("--")
        if valid { return raw }
        issues.error(field, "may only contain lowercase letters, digits and single hyphens, e.g. 'my-story-title'; got '\(raw)'")
        return nil
    }

    func webAddress(_ value: String?, _ field: String, required: Bool = false) -> String? {
        guard let raw = text(value, field, required: required) else { return nil }
        if let url = URL(string: raw),
           let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
           let host = url.host, !host.isEmpty {
            return raw
        }
        issues.error(field, "must be a full web address starting with https://; got '\(raw)'")
        return nil
    }

    /// ISO 8601 with an offset (`2026-11-20T06:00:00+01:00`), or a plain date
    /// (`2026-12-31`, start of that day in the paper's time zone) when allowed.
    func dateTime(_ value: String?, _ field: String, allowDateOnly: Bool = false) -> Date? {
        guard let raw = text(value, field) else { return nil }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: raw) { return date }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }

        if allowDateOnly, raw.count == 10 {
            let day = DateFormatter()
            day.locale = Locale(identifier: "en_US_POSIX")
            day.timeZone = timeZone
            day.dateFormat = "yyyy-MM-dd"
            day.isLenient = false
            if let date = day.date(from: raw) { return date }
        }

        let example = allowDateOnly
            ? "a date (2026-12-31) or a date and time with offset (2026-11-20T06:00:00+01:00)"
            : "a date and time with offset, e.g. 2026-11-20T06:00:00+01:00"
        issues.error(field, "must be \(example); got '\(raw)'")
        return nil
    }

    func boolean(_ value: String?, _ field: String) -> Bool? {
        guard let raw = text(value, field)?.lowercased() else { return nil }
        switch raw {
        case "true", "yes": return true
        case "false", "no": return false
        default:
            issues.error(field, "must be true or false; got '\(raw)'")
            return nil
        }
    }

    func unitInterval(_ value: String?, _ field: String) -> Double? {
        guard let raw = text(value, field, required: true) else { return nil }
        if let number = Double(raw), (0...1).contains(number) { return number }
        issues.error(field, "must be a number from 0 to 1; got '\(raw)'")
        return nil
    }

    /// Start of the day after `date`, in the paper's time zone: a date-only
    /// expiry is still valid for the whole of that day.
    private func endOfDay(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? date
    }
}
