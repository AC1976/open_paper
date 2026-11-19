import Foundation
import Elementary

struct StoryCard: HTML {
    let placed: PlacedStory

    private var story: Story { placed.story }

    var body: some HTML {
        let priorityClass = "priority-\(story.priority == .high ? "high" : "normal")"

        article(.class("story-card category-\(story.category.rawValue) \(priorityClass) span-\(placed.columnSpan) image-\(placed.imageStyle.rawValue)")) {
            // 1. Render photo only if present and not hidden by layout rules
            if let image = story.image, placed.imageStyle != .hidden {
                figure(.class("story-figure")) {
                    img(
                        .src(image.source.htmlSrc),
                        .alt(image.altText),
                        .class("story-image")
                    )

                    if placed.imageStyle != .thumbnail && (image.caption != nil || image.credit != nil) {
                        figcaption(.class("image-caption")) {
                            if let caption = image.caption {
                                span { caption }
                            }
                            if let credit = image.credit {
                                span(.class("image-credit")) { " \(credit)" }
                            }
                        }
                    }
                }
            }

            // 2. NYT-Style Editorial Badges & Kickers
            switch (story.category, story.priority) {

            case (.news, .high):
                div(.class("badge-breaking")) {
                    span(.class("live-dot"))
                    span { "BREAKING NEWS" }
                }

            case (.background, .high):
                span(.class("badge-must-read")) { "MUST READ · ANALYSIS" }

            case (.opinion, .high):
                span(.class("badge-must-read")) { "MUST READ · OPINION" }

            case (.background, .normal):
                span(.class("kicker")) { "ANALYSIS & BACKGROUND" }

            case (.opinion, .normal):
                span(.class("kicker")) { "OPINION" }

            case (.news, .normal):
                EmptyHTML()
            }

            // 3. Headline, Byline & Summary
            h2(.class("headline")) {
                a(.href("/articles/\(story.slug)")) {
                    story.title
                }
            }


            p(.class("summary")) { story.summary }

            // Double the text content for high-priority news stories
            if story.category == .news, story.priority == .high, let extra = story.extendedSummary {
                p(.class("summary summary-extended")) { extra }
            }
        }
    }
}
