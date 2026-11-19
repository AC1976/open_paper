import Foundation
import Elementary

package enum StoryCategory: String, Codable, Sendable {
    case news
    case background
    case opinion
}

package enum StoryPriority: Int, Comparable, Codable, Sendable {
    case high = 2
    case normal = 1

    package static func < (lhs: StoryPriority, rhs: StoryPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package struct Story: Identifiable, Codable, Sendable {
    package let id: UUID
    package let category: StoryCategory
    package let priority: StoryPriority
    package let title: String
    package let summary: String
    package let extendedSummary: String? // Optional extended summary for in-depth articles
    package let slug: String
    package let publishedAt: Date?
    package let updatedAt: Date?
    package let author: String?
    package let image: StoryImage? // Optional editorial photo or ad graphic

    package init(
        id: UUID = UUID(),
        category: StoryCategory,
        priority: StoryPriority,
        title: String,
        summary: String,
        extendedSummary: String? = nil,
        slug: String,
        publishedAt: Date? = nil,
        updatedAt: Date? = nil,
        author: String? = nil,
        image: StoryImage? = nil
    ) {
        self.id = id
        self.category = category
        self.priority = priority
        self.title = title
        self.summary = summary
        self.extendedSummary = extendedSummary
        self.slug = slug
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.author = author
        self.image = image
    }
}
