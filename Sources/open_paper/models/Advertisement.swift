import Foundation

struct Advertisement: Codable, Sendable {
    let id: UUID
    let sponsorName: String
    let imageSource: ImageSource   // Supports .blob(data:mimeType:) OR .endpoint(url:)
    let altText: String
    let targetURL: String
    let priority: StoryPriority

    init(
        id: UUID = UUID(),
        sponsorName: String,
        imageSource: ImageSource,
        altText: String,
        targetURL: String,
        priority: StoryPriority = .normal
    ) {
        self.id = id
        self.sponsorName = sponsorName
        self.imageSource = imageSource
        self.altText = altText
        self.targetURL = targetURL
        self.priority = priority
    }
}
