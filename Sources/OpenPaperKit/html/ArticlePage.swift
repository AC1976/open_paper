import Elementary
import Foundation

/// Reading a story: `/articles/{slug}`.
///
/// One structure, three characters (see `ArticleStyles`):
/// - **news**: kicker in red (with the live dot for breaking news), bold headline,
///   standfirst, wide photo, a single reading column;
/// - **background**: a "analysis" label, and a side column with an "in brief" box
///   and a contents list made from the article's headings;
/// - **opinion**: centred, italic headline, the author given prominence, a drop
///   cap, and a short note at the end.
///
/// Every article ends with a few more stories from the same section.
package struct ArticlePage: HTMLDocument {
    package let metadata: EditionMetadata
    package let story: Story
    /// The article body as HTML (from the markdown).
    package let bodyHTML: String
    /// The date of the paper it appeared in, "yyyy-MM-dd".
    package let publishDate: String?
    package let picture: Picture?
    /// Other stories of the same category, newest first.
    package let related: [Story]

    package init(
        metadata: EditionMetadata, story: Story, bodyHTML: String,
        publishDate: String? = nil, picture: Picture? = nil, related: [Story] = []
    ) {
        self.picture = picture
        self.publishDate = publishDate
        self.metadata = metadata
        self.story = story
        self.bodyHTML = bodyHTML
        self.related = related
    }

    private var section: PaperSection { PaperSection(rawValue: story.category.rawValue) ?? .news }
    private var isBreaking: Bool { story.category == .news && story.priority == .high }

    package var title: String { "\(story.title) — \(metadata.paperTitle)" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        meta(.name(.description), .content(story.summary))
        style { BroadsheetStyles.css }
        style { HTMLRaw(ArticleStyles.css) }
    }

    package var body: some HTML {
        // Only the background layout has a contents list, so only it needs heading anchors.
        let text = story.category == .background ? ArticleText.withHeadingAnchors(bodyHTML) : (html: bodyHTML, headings: [])

        div(.class("broadsheet")) {
            Masthead(metadata: metadata, activeSection: section)

            article(.class("article article-\(story.category.rawValue)\(isBreaking ? " article-breaking" : "")")) {
                header(.class("article-head")) {
                    kicker
                    h1(.class("article-headline")) { story.title }
                    p(.class("article-standfirst")) { story.summary }
                    if story.category == .news, let extra = story.extendedSummary {
                        p(.class("article-standfirst-extra")) { extra }
                    }
                    meta_
                }

                if let image = picture {
                    figure(.class("article-figure")) {
                        img(.src(image.src), .alt(image.altText))
                        if image.caption != nil || image.credit != nil {
                            figcaption {
                                if let caption = image.caption { span { caption } }
                                if let credit = image.credit { span(.class("image-credit")) { credit } }
                            }
                        }
                    }
                }

                div(.class("article-body-wrap")) {
                    if story.category == .background {
                        aside(.class("article-aside")) {
                            div(.class("aside-block")) {
                                h2(.class("aside-label")) { "In brief" }
                                p(.class("aside-text")) { story.extendedSummary ?? story.summary }
                            }
                            if !text.headings.isEmpty {
                                nav(.class("aside-block"), .custom(name: "aria-label", value: "In this article")) {
                                    h2(.class("aside-label")) { "In this article" }
                                    ul(.class("article-contents")) {
                                        for heading in text.headings {
                                            li { a(.href("#\(heading.id)")) { heading.title } }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    div(.class("article-text")) {
                        HTMLRaw(text.html)
                        if story.category == .opinion {
                            p(.class("opinion-note")) { "Opinion pieces reflect the views of their authors, not of the paper." }
                        }
                    }
                }
            }

            if !related.isEmpty {
                aside(.class("article-related")) {
                    h2(.class("related-heading")) {
                        a(.href(section.href)) { "More in \(section.displayTitle)" }
                    }
                    div(.class("related-grid")) {
                        for other in related {
                            div(.class("related-card")) {
                                h3(.class("headline")) { a(.href("/articles/\(other.slug)")) { other.title } }
                                p(.class("summary")) { other.summary }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    /// The small label above the headline, linking to the section.
    @HTMLBuilder
    private var kicker: some HTML {
        div(.class("article-kicker")) {
            switch (story.category, story.priority) {
            case (.news, .high):
                span(.class("live-dot"))
                a(.href(section.href)) { "Breaking news" }
            case (.news, .normal):
                a(.href(section.href)) { "News" }
            case (.background, .high):
                a(.href(section.href)) { "Must read · Analysis" }
            case (.background, .normal):
                a(.href(section.href)) { "Analysis & Background" }
            case (.opinion, .high):
                a(.href(section.href)) { "Must read · Opinion" }
            case (.opinion, .normal):
                a(.href(section.href)) { "Opinion" }
            }
        }
    }

    /// Byline, publish date and reading time.
    @HTMLBuilder
    private var meta_: some HTML {
        div(.class("article-meta")) {
            if let author = story.author {
                span(.class("article-author")) { "By \(author)" }
            }
            div(.class("article-dates")) {
                if let publishDate {
                    span { EditorDates.longDay(publishDate) }
                }
                span { "\(ArticleText.readingMinutes(bodyHTML)) min read" }
            }
        }
    }
}

/// Small text helpers for the article page.
package enum ArticleText {
    /// Whole minutes to read the HTML at about 220 words a minute; never less than 1.
    package static func readingMinutes(_ html: String) -> Int {
        let words = plainText(html).split(whereSeparator: \.isWhitespace).count
        return max(1, Int((Double(words) / 220).rounded(.up)))
    }

    /// The text of an HTML fragment: tags removed, common entities decoded.
    package static func plainText(_ html: String) -> String {
        var text = ""
        var insideTag = false
        for character in html {
            if character == "<" { insideTag = true; text.append(" ") }
            else if character == ">" { insideTag = false }
            else if !insideTag { text.append(character) }
        }
        return text
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    /// Gives every `<h2>` an `id` and lists them, for the contents list.
    package static func withHeadingAnchors(_ html: String) -> (html: String, headings: [(id: String, title: String)]) {
        var output = ""
        var headings: [(id: String, title: String)] = []
        var used: Set<String> = []
        var cursor = html.startIndex

        while let open = html.range(of: "<h2>", range: cursor..<html.endIndex),
              let close = html.range(of: "</h2>", range: open.upperBound..<html.endIndex) {
            let inner = String(html[open.upperBound..<close.lowerBound])
            let title = plainText(inner)

            var id = slug(title)
            if id.isEmpty { id = "section" }
            var candidate = id
            var number = 2
            while used.contains(candidate) { candidate = "\(id)-\(number)"; number += 1 }
            used.insert(candidate)

            output += html[cursor..<open.lowerBound]
            output += "<h2 id=\"\(candidate)\">\(inner)</h2>"
            headings.append((candidate, title))
            cursor = close.upperBound
        }
        output += html[cursor...]
        return (output, headings)
    }

    /// "Key commitments" → "key-commitments".
    package static func slug(_ text: String) -> String {
        var result = ""
        var lastWasDash = true
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                result.append(character)
                lastWasDash = false
            } else if !lastWasDash {
                result.append("-")
                lastWasDash = true
            }
        }
        if result.hasSuffix("-") { result.removeLast() }
        return result
    }
}
