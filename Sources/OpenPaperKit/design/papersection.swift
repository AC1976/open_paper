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
        case .frontPage: return "Voorpagina"
        case .news: return "Nieuws"
        case .background: return "Achtergrond"
        case .opinion: return "Opinie"
        case .agenda: return "Agenda"
        case .quoted: return "Quotes"
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
        PaperDates.long(editionDate)
    }
}


/// Dates as readers see them: Dutch, in the paper's time zone.
package enum PaperDates {
    /// "vrijdag 20 november 2026"
    package static func long(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .current
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter.string(from: date)
    }

    /// A "yyyy-MM-dd" day on a line of its own: "Vrijdag 20 november 2026".
    package static func line(_ day: String) -> String {
        guard let date = EditorDates.parseDay(day) else { return day }
        let text = long(date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
