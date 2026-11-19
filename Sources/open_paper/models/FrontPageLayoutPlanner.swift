import Foundation
import Elementary

// EditionMode defines whether the lay out is 4, 2 or 1 column.

enum EditionMode {
    case breaking   // Lead spans 4 columns
    case prominent  // Lead spans 2 columns
    case regular    // Lead spans 1 column

    var leadColumnSpan: Int {
        switch self {
        case .breaking: return 4
        case .prominent: return 2
        case .regular: return 1
        }
    }
}

// FrontPageLayout holds the key parameters for any issue of the newspaper. 'Title' is derived from the settings config file.

enum ImageDisplayStyle: String, CaseIterable {
    case fullBanner     // Wide 21:9 photo for 4-column breaking news
    case standardLead   // 16:10 photo for prominent/regular lead & high-priority stories
    case thumbnail      // Compact square thumbnail for secondary stories
    case hidden         // Text-only card to preserve newspaper density
}

struct PlacedStory {
    let story: Story
    let columnSpan: Int
    let imageStyle: ImageDisplayStyle
}

struct FrontPageLayoutPlan {
    let mode: EditionMode
    let breakingBanner: PlacedStory?
    let editorialStories: [PlacedStory]
    let opinionPieces: [Story]
    let agendaPoints: [AgendaPoint]
    let quotedItems: [QuotedItem]
    let advertisements: [Advertisement]

    init(
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
