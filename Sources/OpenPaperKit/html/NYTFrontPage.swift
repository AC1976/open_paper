import Foundation
import Elementary

package struct NYTFrontPage: HTMLDocument {
    package let metadata: EditionMetadata
    package let plan: FrontPageLayoutPlan

    package init(metadata: EditionMetadata, plan: FrontPageLayoutPlan) {
        self.metadata = metadata
        self.plan = plan
    }

    package var title: String { metadata.paperTitle }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
    }

    package var body: some HTML {
        div(.class("broadsheet mode-\(plan.mode)")) {
            Masthead(metadata: metadata, activeSection: .frontPage)

            main(.class("four-column-grid")) {
                // 1. Breaking News Banner (spans all 4 columns at the very top)
                if let banner = plan.breakingBanner {
                    StoryCard(placed: banner)
                }

                // 2. Columns 1 & 2: Strictly News & Background
                div(.class("news-columns")) {
                    for item in plan.editorialStories {
                        StoryCard(placed: item)
                    }
                }

                               
                // 3. Column 3: Strictly Reserved for Quoted (Top), Agenda (Middle) & Opinion (Bottom)
                aside(.class("opinion-rail")) {
                    // 1. Quoted on top
                    if !plan.quotedItems.isEmpty {
                        QuotedSection(items: plan.quotedItems)
                    }

                    // 2. Agenda in the middle
                    if !plan.agendaPoints.isEmpty {
                        AgendaSection(points: plan.agendaPoints)
                    }

                    // 3. Opinion at the bottom
                    if !plan.opinionPieces.isEmpty {
                        section(.class("rail-section")) {
                            h3(.class("rail-header")) { "Opinion" }
                            for piece in plan.opinionPieces {
                                StoryCard(placed: PlacedStory(
                                    story: piece,
                                    columnSpan: 1,
                                    imageStyle: .hidden
                                ))
                            }
                        }
                    }
                }
               
                // 4. Column 4: Strictly Reserved for Full-Height Advertisements
                aside(.class("ad-rail-full-height")) {
                    for ad in plan.advertisements {
                        AdvertisementCard(ad: ad)
                    }
                }

            }
        }
    }
        
}

