import Foundation
import Elementary

enum StoryCategory: String, Codable, Sendable {
    case news
    case background
    case opinion
}

enum StoryPriority: Int, Comparable, Codable, Sendable {
    case high = 2
    case normal = 1

    static func < (lhs: StoryPriority, rhs: StoryPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct Story: Identifiable, Codable, Sendable {
    let id: UUID
    let category: StoryCategory
    let priority: StoryPriority
    let title: String
    let summary: String
    let extendedSummary: String? // Optional extended summary for in-depth articles
    let slug: String
    let publishedAt: Date?
    let updatedAt: Date?
    let author: String?
    let image: StoryImage? // Optional editorial photo or ad graphic

    init(
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
