import Elementary
import Foundation

/// A section archive. Items are shown in the order given, so pass them newest
/// first (`PaperDatabase.publishedItems()` does).
package struct SectionPage: HTMLDocument {
    package let metadata: EditionMetadata
    package let section: PaperSection
    package let stories: [Story]
    package let agendaPoints: [AgendaPoint]
    package let quotedItems: [QuotedItem]
    /// The stories' pictures, by story id.
    package let pictures: [UUID: Picture]

    package init(
        metadata: EditionMetadata,
        section: PaperSection,
        stories: [Story],
        agendaPoints: [AgendaPoint],
        quotedItems: [QuotedItem],
        pictures: [UUID: Picture] = [:]
    ) {
        self.pictures = pictures
        self.metadata = metadata
        self.section = section
        self.stories = stories
        self.agendaPoints = agendaPoints
        self.quotedItems = quotedItems
    }

    package var title: String { "\(section.displayTitle) — \(metadata.paperTitle)" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
    }

    package var body: some HTML {
        div(.class("broadsheet")) {
            Masthead(metadata: metadata, activeSection: section)

            header(.class("section-banner")) {
                h2(.class("section-heading")) { section.displayTitle }
            }

            main(.class("section-archive-list")) {
                switch section {
                case .news, .background, .opinion:
                    for story in stories where story.category.rawValue == section.rawValue {
                        StoryCard(placed: PlacedStory(
                            story: story,
                            columnSpan: 1,
                            imageStyle: pictures[story.id] != nil ? .thumbnail : .hidden,
                            picture: pictures[story.id]
                        ))
                    }

                case .agenda:
                    for point in agendaPoints {
                        AgendaItemRow(point: point)
                    }

                case .quoted:
                    for item in quotedItems {
                        div(.class("archive-quote-row")) {
                            blockquote(.class("quote-text")) { "“\(item.quote)”" }
                            span(.class("quote-speaker")) { "— \(item.speaker)" }
                            p(.class("quote-context")) { item.context }
                            a(.href(item.sourceLink), .class("quote-source-link")) {
                                "Read original source →"
                            }
                        }
                    }

                case .frontPage:
                    EmptyHTML()
                }
            }
        }
    }
}
