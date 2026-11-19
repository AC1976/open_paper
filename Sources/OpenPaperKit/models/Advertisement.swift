import Foundation

package struct Advertisement: Codable, Sendable {
    package let id: UUID
    package let sponsorName: String
    package let imageSource: ImageSource   // Supports .blob(data:mimeType:) OR .endpoint(url:)
    package let altText: String
    package let targetURL: String
    package let priority: StoryPriority

    package init(
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
