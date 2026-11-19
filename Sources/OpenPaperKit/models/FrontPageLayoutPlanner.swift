import Foundation
import Elementary

// EditionMode defines whether the lay out is 4, 2 or 1 column.

package enum EditionMode: String, CaseIterable, Sendable {
    case breaking   // Lead spans 4 columns
    case prominent  // Lead spans 2 columns
    case regular    // Lead spans 1 column

    package var label: String {
        switch self {
        case .breaking: "Breaking"
        case .prominent: "Prominent"
        case .regular: "Regular"
        }
    }

    package var explanation: String {
        switch self {
        case .breaking: "The lead story runs across all four columns."
        case .prominent: "The lead story runs across two columns."
        case .regular: "The lead story stays in one column."
        }
    }

    package var leadColumnSpan: Int {
        switch self {
        case .breaking: return 4
        case .prominent: return 2
        case .regular: return 1
        }
    }
}

// FrontPageLayout holds the key parameters for any issue of the newspaper. 'Title' is derived from the settings config file.

package enum ImageDisplayStyle: String {
    case fullBanner     // Wide 21:9 photo for 4-column breaking news
    case standardLead   // 16:10 photo for prominent/regular lead & high-priority stories
    case thumbnail      // Compact square thumbnail for secondary stories
    case hidden         // Text-only card to preserve newspaper density
}

package struct PlacedStory {
    package let story: Story
    package let columnSpan: Int
    package let imageStyle: ImageDisplayStyle
}

package struct FrontPageLayoutPlan {
    package let mode: EditionMode
    package let breakingBanner: PlacedStory?
    package let editorialStories: [PlacedStory]
    package let opinionPieces: [Story]
    package let agendaPoints: [AgendaPoint]
    package let quotedItems: [QuotedItem]
    package let advertisements: [Advertisement]

    package init(
        mode: EditionMode,
        stories: [Story],
        agendaPoints: [AgendaPoint] = [],
        quotedItems: [QuotedItem] = [],
        advertisements: [Advertisement] = []
    ) {
        self.mode = mode
        self.agendaPoints = agendaPoints
        self.quotedItems = quotedItems
        self.advertisements = advertisements.sorted { $0.priority > $1.priority }

        let sorted = stories.sorted { $0.priority > $1.priority }
        self.opinionPieces = sorted.filter { $0.category == .opinion }

        var editorialPool = sorted.filter {
            $0.category == .news || $0.category == .background
        }

        if let first = editorialPool.first {
            editorialPool.removeFirst()
            let leadImageStyle: ImageDisplayStyle = (mode == .breaking) ? .fullBanner : .standardLead
            let leadPlaced = PlacedStory(
                story: first,
                columnSpan: mode.leadColumnSpan,
                imageStyle: leadImageStyle
            )

            if mode == .breaking {
                self.breakingBanner = leadPlaced
                self.editorialStories = Self.assignEditorialSlots(editorialPool)
            } else {
                self.breakingBanner = nil
                self.editorialStories = [leadPlaced] + Self.assignEditorialSlots(editorialPool)
            }
        } else {
            self.breakingBanner = nil
            self.editorialStories = []
        }
    }

    private static func assignEditorialSlots(_ remaining: [Story]) -> [PlacedStory] {
        remaining.enumerated().map { index, story in
            let style: ImageDisplayStyle
            if story.priority == .high && story.image != nil {
                style = .standardLead
            } else if index < 4 && story.image != nil {
                style = .thumbnail
            } else {
                style = .hidden
            }
            return PlacedStory(story: story, columnSpan: 1, imageStyle: style)
        }
    }
}
