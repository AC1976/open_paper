import Foundation

package enum PaperSection: String, CaseIterable, Codable, Sendable {
    case frontPage = "front-page"
    case news = "news"
    case background = "background"
    case opinion = "opinion"
    case agenda = "agenda"
    case quoted = "quoted"

    package var displayTitle: String {
        switch self {
        case .frontPage: return "Front Page"
        case .news: return "News"
        case .background: return "Background"
        case .opinion: return "Opinion"
        case .agenda: return "Agenda"
        case .quoted: return "Quoted"
        }
    }

    package var href: String {
        self == .frontPage ? "/" : "/sections/\(rawValue)"
    }
}

package struct EditionMetadata: Codable, Sendable {
    package let paperTitle: String
    package let subtitle: String?
    package let volume: Int
    package let issueNumber: Int
    package let editionDate: Date
    package let editionLabel: String

    package init(
        paperTitle: String,
        subtitle: String? = nil,
        volume: Int,
        issueNumber: Int,
        editionDate: Date,
        editionLabel: String
    ) {
        self.paperTitle = paperTitle
        self.subtitle = subtitle
        self.volume = volume
        self.issueNumber = issueNumber
        self.editionDate = editionDate
        self.editionLabel = editionLabel
    }

    package var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: editionDate)
    }
}

