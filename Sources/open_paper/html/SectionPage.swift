import Elementary
import Foundation

struct SectionPage: HTMLDocument {
    let metadata: EditionMetadata
    let section: PaperSection
    let stories: [Story]
    let agendaPoints: [AgendaPoint]
    let quotedItems: [QuotedItem]

    var title: String { "\(section.displayTitle) — \(metadata.paperTitle)" }

    var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
    }

    var body: some HTML {
        div(.class("broadsheet")) {
            Masthead(metadata: metadata, activeSection: section)

            header(.class("section-banner")) {
                h2(.class("section-heading")) { section.displayTitle }
            }

            main(.class("section-archive-list")) {
                switch section {
                case .news, .background, .opinion:
                    let filtered = stories
                        .filter { $0.category.rawValue == section.rawValue }
                        .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }

                    for story in filtered {
                        StoryCard(placed: PlacedStory(
                            story: story,
                            columnSpan: 1,
                            imageStyle: story.image != nil ? .thumbnail : .hidden
                        ))
                    }

                case .agenda:
                    let sortedAgenda = agendaPoints.sorted {
                        ($0.eventDate ?? .distantPast) > ($1.eventDate ?? .distantPast)
                    }
                    for point in sortedAgenda {
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
