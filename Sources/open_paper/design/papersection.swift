import Foundation

enum PaperSection: String, CaseIterable, Codable, Sendable {
    case frontPage = "front-page"
    case news = "news"
    case background = "background"
    case opinion = "opinion"
    case agenda = "agenda"
    case quoted = "quoted"

    var displayTitle: String {
        switch self {
        case .frontPage: return "Front Page"
        case .news: return "News"
        case .background: return "Background"
        case .opinion: return "Opinion"
        case .agenda: return "Agenda"
        case .quoted: return "Quoted"
        }
    }

    var href: String {
        self == .frontPage ? "/" : "/sections/\(rawValue)"
    }
}

struct EditionMetadata: Codable, Sendable {
    let paperTitle: String
    let subtitle: String?
    let volume: Int
    let issueNumber: Int
    let editionDate: Date
    let editionLabel: String

    init(
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

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: editionDate)
    }
}

