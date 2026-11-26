import Foundation
import Elementary

extension ItemKind {
    package var label: String {
        switch self {
        case .story: "Story"
        case .agendaPoint: "Agenda point"
        case .quotedItem: "Quote"
        case .advertisement: "Advertisement"
        }
    }
}

/// Styles and the top bar shared by the editor pages.
package struct EditorBar: HTML {
    package init() {}

    package var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Editor" }
            nav(.class("editor-nav")) {
                a(.href("/editor"), .class("editor-link")) { "News desk" }
                a(.href("/editor/issues"), .class("editor-link")) { "Editions" }
                form(.method(.post), .action("/editor/logout"), .enctype(.multipartFormData), .class("editor-logout")) {
                    button(.type(.submit), .class("editor-link")) { "Log out" }
                }
            }
        }
    }
}

/// What the "Preview" button shows: the item as readers will see it, or why it
/// cannot be shown yet.
package struct PreviewPage: HTMLDocument {
    package let parsed: ParsedUpload?
    package let picture: Picture?
    package let problems: [String]

    package init(parsed: ParsedUpload?, picture: Picture? = nil, problems: [String] = []) {
        self.parsed = parsed
        self.picture = picture
        self.problems = problems
    }

    package var title: String { "Preview" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        main(.class("preview-page")) {
            if !problems.isEmpty {
                div(.class("problems")) {
                    p { "Fix this to see the preview:" }
                    ul {
                        for problem in problems { li { problem } }
                    }
                }
            }
            switch parsed {
            case .story(let story, _, let html)?:
                StoryPreview(story: story, bodyHTML: html, picture: picture)
            case .agendaPoint(let point)?:
                h2(.class("preview-label")) { "Agenda" }
                div(.class("preview-frame broadsheet")) { AgendaSection(points: [point]) }
            case .quotedItem(let quote)?:
                h2(.class("preview-label")) { "Quoted" }
                div(.class("preview-frame broadsheet")) { QuotedSection(items: [quote]) }
            case .advertisement(let ad)?:
                h2(.class("preview-label")) { "Advertisement" }
                div(.class("preview-frame broadsheet preview-ad")) { AdvertisementCard(ad: ad) }
            case nil:
                EmptyHTML()
            }
        }
    }
}

/// How a story looks on the front page and on its own page.
package struct StoryPreview: HTML {
    package let story: Story
    package let bodyHTML: String
    package var picture: Picture? = nil

    package var body: some HTML {
        h2(.class("preview-label")) { "Front page" }
        div(.class("preview-frame broadsheet mode-prominent")) {
            StoryCard(placed: PlacedStory(story: story, columnSpan: 2, imageStyle: .standardLead, picture: picture))
        }

        h2(.class("preview-label")) { "Article page" }
        div(.class("preview-frame article-body")) {
            h1(.class("headline")) { story.title }
            if let author = story.author {
                p(.class("byline")) { "By \(author)" }
            }
            HTMLRaw(bodyHTML)
        }
    }
}
