import Foundation
import Elementary

/// The page an editor sees after uploading a story: the fields on the left,
/// a preview of how it will look on the front page on the right.
///
/// Field names match the `Story` model, so the submitted form maps straight back to it.
package struct ReviewCard: HTMLDocument {
    package let story: Story
    package let markdown: String   // the body as written
    package let bodyHTML: String   // the body as HTML, for the preview
    /// The form posts here; `/preview` and `/cancel` are appended for the other buttons.
    package let actionBase: String
    /// Messages to show above the form (a failed save).
    package let problems: [String]
    package let heading: String
    /// Where the "back" link in the top bar goes.
    package let backHref: String
    /// Set for saved items, which can be filed or rejected here.
    package let filing: Filing?

    package init(
        story: Story,
        markdown: String,
        bodyHTML: String,
        actionBase: String,
        problems: [String] = [],
        heading: String = "Review story",
        backHref: String = "/editor",
        filing: Filing? = nil
    ) {
        self.filing = filing
        self.heading = heading
        self.backHref = backHref
        self.story = story
        self.markdown = markdown
        self.bodyHTML = bodyHTML
        self.actionBase = actionBase
        self.problems = problems
    }

    package var title: String { "Review: \(story.title)" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }   // raw: the CSS uses ">" selectors
    }

    package var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Editor" }
            a(.href(backHref), .class("editor-link")) { "← Back" }
        }

        main(.class("review")) {
            form(.method(.post), .action(actionBase), .enctype(.multipartFormData), .class("review-form")) {
                input(.type(.hidden), .name("id"), .value(story.id.uuidString))

                h1(.class("review-title")) { heading }

                if !problems.isEmpty {
                    div(.class("problems")) {
                        p { "The story was not saved:" }
                        ul {
                            for problem in problems { li { problem } }
                        }
                    }
                }

                fieldset {
                    legend { "Classification" }
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
                    if case .blob(let data, _)? = story.image?.source {
                        p(.class("notice")) {
                            "This story has an uploaded image (\(max(data.count / 1024, 1)) KB). Choose a file to replace it, or tick the box to remove it."
                        }
                        div(.class("field")) {
                            label(.for("removeImage")) {
                                input(.type(.checkbox), .id("removeImage"), .name("removeImage"), .value("yes"))
                                " Remove the image"
                            }
                        }
                    }
                    field("imageFile", "Image file", hint: "JPEG, PNG or WebP, up to 5 MB. Choose the file again after \"Update preview\".") {
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
                    button(.type(.submit), .class("button"), .custom(name: "formaction", value: actionBase + "/preview"),
                           .custom(name: "formnovalidate", value: "")) {
                        "Update preview"
                    }
                    button(.type(.submit), .class("button quiet"), .custom(name: "formaction", value: actionBase + "/cancel"),
                           .custom(name: "formnovalidate", value: "")) {
                        "Cancel"
                    }
                }

                if let filing {
                    FilingBox(filing: filing, actionBase: actionBase)
                }
            }

            aside(.class("review-preview")) {
                StoryPreview(story: story, bodyHTML: bodyHTML)
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
}
