import Foundation

// What ingestion hands back: the validated item (ready to become a staged upload),
// plus everything the editor's review card needs to show.

struct IngestionIssue: CustomStringConvertible {
    enum Severity: String {
        case error
        case warning
    }

    let severity: Severity
    /// Dotted path of the field, e.g. `image.altText`. Empty for whole-file problems.
    let field: String
    let message: String

    var description: String {
        let label = severity == .error ? "error  " : "warning"
        return field.isEmpty ? "\(label)  \(message)" : "\(label)  \(field): \(message)"
    }
}

enum UploadType: String, CaseIterable {
    case story
    case agenda
    case quoted
    case advertisement
}

enum UploadStatus: String, CaseIterable {
    case draft
    case ready
}

enum ImageStorage: String, CaseIterable {
    case embed   // base64 in the database → ImageSource.blob
    case store   // file on the server     → ImageSource.endpoint("/media/…")
    case link    // keep the remote URL    → ImageSource.endpoint(url)
}

enum ImageLicense: String, CaseIterable {
    case own
    case agency
    case ccBy = "cc-by"
    case ccBySa = "cc-by-sa"
    case publicDomain = "public-domain"
    case unknown
}

struct FocalPoint {
    let x: Double
    let y: Double
}

/// A checked image block. The picture itself is not loaded yet: ingestion only
/// decides what has to happen next (upload, download, or nothing for `link`).
struct ImageRequest {
    let file: String?
    let url: String?
    let storage: ImageStorage
    let altText: String
    let caption: String?
    let credit: String?
    let license: ImageLicense
    let rightsHolder: String?
    let usageExpires: Date?
    let displayHint: ImageDisplayStyle?   // nil = auto
    let focalPoint: FocalPoint?
    let sensitive: Bool

    /// The editor still has to upload `file`.
    var needsUpload: Bool { file != nil }

    /// The server has to fetch `url` itself (storage `store` or `embed`).
    var needsDownload: Bool { file == nil && storage != .link }

    func storyImage(source: ImageSource) -> StoryImage {
        StoryImage(source: source, altText: altText, caption: caption, credit: credit)
    }
}

/// `Advertisement` needs an `ImageSource` up front, which doesn't exist until the
/// image has been uploaded or fetched — so ads stay a draft until then.
struct AdvertisementDraft {
    let id: UUID
    let sponsorName: String
    let targetURL: String
    let priority: StoryPriority
    let image: ImageRequest
    let campaignStart: Date?
    let campaignEnd: Date?

    func advertisement(imageSource: ImageSource) -> Advertisement {
        Advertisement(
            id: id,
            sponsorName: sponsorName,
            imageSource: imageSource,
            altText: image.altText,
            targetURL: targetURL,
            priority: priority
        )
    }
}

enum IngestedItem {
    /// `Story.image` is already filled in for `storage: link`; otherwise it is set
    /// once the `ImageRequest` has been resolved.
    case story(Story, image: ImageRequest?)
    case agenda(AgendaPoint)
    case quoted(QuotedItem)
    case advertisement(AdvertisementDraft)
}

struct IngestionResult {
    let fileName: String
    let type: UploadType?
    /// `nil` when the upload has errors and was rejected.
    let item: IngestedItem?
    /// The requested status, lowered to `draft` when something is held.
    let status: UploadStatus
    let issues: [IngestionIssue]
    /// Article body rendered to HTML, for the review card's preview (stories only).
    let bodyHTML: String?

    var isAccepted: Bool { item != nil }
    var errors: [IngestionIssue] { issues.filter { $0.severity == .error } }
    var warnings: [IngestionIssue] { issues.filter { $0.severity == .warning } }
}
