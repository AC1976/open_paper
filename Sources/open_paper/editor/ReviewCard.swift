import Foundation
import Elementary

/// The page an editor sees after uploading a story: the fields on the left,
/// a preview of how it will look on the front page on the right.
///
/// Field names match the `Story` model, so the submitted form maps straight back to it.
struct ReviewCard: HTMLDocument {
    let story: Story
    let markdown: String   // the body as written
    let bodyHTML: String   // the body as HTML, for the preview
    let issueDate: Date

    var title: String { "Review: \(story.title)" }

    var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }   // raw: the CSS uses ">" selectors
    }

    var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Editor" }
            a(.href("/editor"), .class("editor-link")) { "← All editions" }
        }

        main(.class("review")) {
            form(.method(.post), .action("/editor/stories"), .enctype(.multipartFormData), .class("review-form")) {
                input(.type(.hidden), .name("id"), .value(story.id.uuidString))

                h1(.class("review-title")) { "Review story" }

                fieldset {
                    legend { "Placement" }
                    field("issueDate", "Appears in issue of") {
                        input(.type(.date), .id("issueDate"), .name("issueDate"), .value(Self.day(issueDate)), .required)
                    }
                    div(.class("field-row")) {
                        field("category", "Category") {
                            select(.id("category"), .name("category")) {
                                for category in [StoryCategory.news, .background, .opinion] {
                                    option(.value(category.rawValue)) { category.rawValue.capitalized }
                                        .attributes(.selected, when: category == story.category)
                                }
                            }
                        }
                        field("priority", "Priority") {
                            select(.id("priority"), .name("priority")) {
                                option(.value("2")) { "High" }.attributes(.selected, when: story.priority == .high)
                                option(.value("1")) { "Normal" }.attributes(.selected, when: story.priority == .normal)
                            }
                        }
                    }
                }

                fieldset {
                    legend { "Story" }
                    field("title", "Title") {
                        input(.type(.text), .id("title"), .name("title"), .value(story.title), .required)
                    }
                    field("slug", "Slug", hint: "Used in the address: /articles/\(story.slug)") {
                        input(.type(.text), .id("slug"), .name("slug"), .value(story.slug), .required)
                    }
                    field("author", "Author") {
                        input(.type(.text), .id("author"), .name("author"), .value(story.author ?? ""))
                    }
                    div(.class("field-row")) {
                        field("publishedAt", "Published") {
                            input(.type(.datetimeLocal), .id("publishedAt"), .name("publishedAt"),
                                  .value(story.publishedAt.map(Self.dateTime) ?? ""))
                        }
                        field("updatedAt", "Updated") {
                            input(.type(.datetimeLocal), .id("updatedAt"), .name("updatedAt"),
                                  .value(story.updatedAt.map(Self.dateTime) ?? ""))
                        }
                    }
                    field("summary", "Summary") {
                        textarea(.id("summary"), .name("summary"), .rows(4), .required) { story.summary }
                    }
                    field("extendedSummary", "Extended summary", hint: "Only shown for high-priority news.") {
                        textarea(.id("extendedSummary"), .name("extendedSummary"), .rows(3)) { story.extendedSummary ?? "" }
                    }
                    field("body", "Article text (markdown)") {
                        textarea(.id("body"), .name("body"), .rows(12), .class("markdown")) { markdown }
                    }
                }

                fieldset {
                    legend { "Image" }
                    if let path = Self.localPath(of: story.image) {
                        p(.class("notice")) {
                            "This story refers to "
                            code { path }
                            ". Choose the file to upload it with the story."
                        }
                    }
                    field("imageFile", "Image file") {
                        input(.type(.file), .id("imageFile"), .name("imageFile"), .accept("image/jpeg,image/png,image/webp"))
                    }
                    field("imageURL", "Or image address") {
                        input(.type(.text), .id("imageURL"), .name("image.source.endpoint.url"),
                              .value(Self.url(of: story.image) ?? ""))
                    }
                    field("altText", "Alt text", hint: "Describes the image for readers who can't see it.") {
                        input(.type(.text), .id("altText"), .name("image.altText"), .value(story.image?.altText ?? ""))
                    }
                    field("caption", "Caption") {
                        input(.type(.text), .id("caption"), .name("image.caption"), .value(story.image?.caption ?? ""))
                    }
                    field("credit", "Credit") {
                        input(.type(.text), .id("credit"), .name("image.credit"), .value(story.image?.credit ?? ""))
                    }
                }

                div(.class("actions")) {
                    button(.type(.submit), .class("button primary")) { "Save" }
                    button(.type(.submit), .class("button"), .custom(name: "formaction", value: "/editor/stories/preview")) {
                        "Update preview"
                    }
                    a(.href("/editor"), .class("button quiet")) { "Cancel" }
                }
            }

            aside(.class("review-preview")) {
                h2(.class("preview-label")) { "Front page" }
                div(.class("preview-frame broadsheet mode-prominent")) {
                    StoryCard(placed: PlacedStory(story: story, columnSpan: 2, imageStyle: .standardLead))
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
    }

    // MARK: - Helpers

    /// A label, the input, and an optional hint underneath.
    private func field<Content: HTML>(
        _ id: String, _ label: String, hint: String? = nil,
        @HTMLBuilder content: () -> Content
    ) -> some HTML {
        div(.class("field")) {
            Elementary.label(.for(id)) { label }
            content()
            if let hint {
                small(.class("hint")) { hint }
            }
        }
    }

    private static func url(of image: StoryImage?) -> String? {
        guard let image, case .endpoint(let url) = image.source else { return nil }
        return url
    }

    /// The image path when it points at a file the editor still has to upload.
    private static func localPath(of image: StoryImage?) -> String? {
        guard let url = url(of: image), !url.hasPrefix("http://"), !url.hasPrefix("https://") else { return nil }
        return url
    }

    private static let paperTimeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .current

    private static func day(_ date: Date) -> String {
        format(date, "yyyy-MM-dd")
    }

    private static func dateTime(_ date: Date) -> String {
        format(date, "yyyy-MM-dd'T'HH:mm")
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = paperTimeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
