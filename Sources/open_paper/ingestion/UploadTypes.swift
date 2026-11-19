import Foundation

// Raw shapes of the YAML front matter, as the editor writes it.
//
// Every scalar is decoded as an optional String on purpose: the validator then
// checks each field itself and reports problems in plain language ("priority must
// be 2 (high) or 1 (normal)") instead of surfacing a Swift DecodingError.

/// Keys shared by every upload.
struct UploadEnvelope: Decodable {
    let type: String?
    let schemaVersion: String?
    let status: String?
    let id: String?

    static let keys: Set<String> = ["type", "schemaVersion", "status", "id"]
}

struct StoryUpload: Decodable {
    let category: String?
    let priority: String?
    let title: String?
    let slug: String?
    let author: String?
    let publishedAt: String?
    let updatedAt: String?
    let summary: String?
    let extendedSummary: String?
    let image: ImageUpload?

    static let keys: Set<String> = [
        "category", "priority", "title", "slug", "author", "publishedAt",
        "updatedAt", "summary", "extendedSummary", "image",
    ]
}

struct AgendaUpload: Decodable {
    let subject: String?
    let place: String?
    let link: String?
    let eventDate: String?
    let summary: String?

    static let keys: Set<String> = ["subject", "place", "link", "eventDate", "summary"]
}

struct QuotedUpload: Decodable {
    let quote: String?
    let speaker: String?
    let sourceLink: String?
    let context: String?

    static let keys: Set<String> = ["quote", "speaker", "sourceLink", "context"]
}

struct AdvertisementUpload: Decodable {
    let sponsorName: String?
    let targetURL: String?
    let priority: String?
    let image: ImageUpload?
    let campaignStart: String?
    let campaignEnd: String?

    static let keys: Set<String> = [
        "sponsorName", "targetURL", "priority", "image", "campaignStart", "campaignEnd",
    ]
}

struct ImageUpload: Decodable {
    let file: String?
    let url: String?
    let storage: String?
    let altText: String?
    let caption: String?
    let credit: String?
    let license: String?
    let rightsHolder: String?
    let usageExpires: String?
    let displayHint: String?
    let focalPoint: FocalPointUpload?
    let sensitive: String?

    static let keys: Set<String> = [
        "file", "url", "storage", "altText", "caption", "credit", "license",
        "rightsHolder", "usageExpires", "displayHint", "focalPoint", "sensitive",
    ]
}

struct FocalPointUpload: Decodable {
    let x: String?
    let y: String?
}
