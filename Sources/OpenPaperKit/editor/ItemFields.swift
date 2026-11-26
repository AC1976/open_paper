import Foundation
import Elementary

/// A label, the input, and an optional hint underneath.
private struct Field<Content: HTML>: HTML {
    let id: String
    let name: String
    var hint: String?
    let content: Content

    init(_ id: String, _ name: String, hint: String? = nil, @HTMLBuilder content: () -> Content) {
        self.id = id
        self.name = name
        self.hint = hint
        self.content = content()
    }

    var body: some HTML {
        div(.class("field")) {
            label(.for(id)) { name }
            content
            if let hint {
                small(.class("hint")) { hint }
            }
        }
    }
}

/// A story's fields, in reading order, with its picture near the top.
struct StoryInputs: HTML {
    let story: Story
    let markdown: String   // the body as written
    let picture: Picture?

    var body: some HTML {
        fieldset {
            legend { "Story" }
            Field("title", "Title") {
                input(.type(.text), .id("title"), .name("title"), .value(story.title), .required)
            }
            div(.class("field-row")) {
                Field("category", "Category") {
                    select(.id("category"), .name("category")) {
                        for category in [StoryCategory.news, .background, .opinion] {
                            option(.value(category.rawValue)) { category.rawValue.capitalized }
                                .attributes(.selected, when: category == story.category)
                        }
                    }
                }
                Field("priority", "Priority") {
                    select(.id("priority"), .name("priority")) {
                        option(.value("2")) { "High" }.attributes(.selected, when: story.priority == .high)
                        option(.value("1")) { "Normal" }.attributes(.selected, when: story.priority == .normal)
                    }
                }
                Field("author", "Author") {
                    input(.type(.text), .id("author"), .name("author"), .value(story.author ?? ""))
                }
            }
        }

        fieldset {
            legend { "Picture" }
            if let picture {
                img(.src(picture.src), .alt(picture.altText), .class("desk-picture"))
                div(.class("field")) {
                    label(.for("removeImage")) {
                        input(.type(.checkbox), .id("removeImage"), .name("removeImage"), .value("yes"))
                        " Remove the picture"
                    }
                }
            }
            Field("imageFile", picture == nil ? "Picture file" : "Replace with another file",
                  hint: "JPEG, PNG or WebP, up to 15 MB.") {
                input(.type(.file), .id("imageFile"), .name("imageFile"), .accept("image/jpeg,image/png,image/webp"))
            }
            Field("altText", "Alt text", hint: "Describes the picture for readers who can't see it.") {
                input(.type(.text), .id("altText"), .name("altText"), .value(picture?.altText ?? ""))
            }
            div(.class("field-row")) {
                Field("caption", "Caption") {
                    input(.type(.text), .id("caption"), .name("caption"), .value(picture?.caption ?? ""))
                }
                Field("credit", "Credit") {
                    input(.type(.text), .id("credit"), .name("credit"), .value(picture?.credit ?? ""))
                }
            }
        }

        fieldset {
            legend { "Text" }
            Field("summary", "Summary") {
                textarea(.id("summary"), .name("summary"), .rows(3), .required) { story.summary }
            }
            Field("extendedSummary", "Extended summary", hint: "Only shown for high-priority news.") {
                textarea(.id("extendedSummary"), .name("extendedSummary"), .rows(3)) { story.extendedSummary ?? "" }
            }
            Field("body", "Article text (markdown)") {
                textarea(.id("body"), .name("body"), .rows(18), .class("markdown")) { markdown }
            }
            Field("slug", "Slug", hint: "Used in the address: /articles/\(story.slug)") {
                input(.type(.text), .id("slug"), .name("slug"), .value(story.slug), .required)
            }
        }
    }
}

struct AgendaInputs: HTML {
    let item: AgendaPoint

    var body: some HTML {
        fieldset {
            legend { "Agenda point" }
            Field("subject", "Subject") {
                input(.type(.text), .id("subject"), .name("subject"), .value(item.subject), .required)
            }
            div(.class("field-row")) {
                Field("place", "Place") {
                    input(.type(.text), .id("place"), .name("place"), .value(item.place), .required)
                }
                Field("eventDate", "Date of the event") {
                    input(.type(.datetimeLocal), .id("eventDate"), .name("eventDate"),
                          .value(item.eventDate.map(EditorDates.dateTime) ?? ""))
                }
            }
            Field("link", "Link", hint: "Must start with http:// or https://") {
                input(.type(.text), .id("link"), .name("link"), .value(item.link), .required)
            }
            Field("summary", "Summary") {
                textarea(.id("summary"), .name("summary"), .rows(5), .required) { item.summary }
            }
        }
    }
}

struct QuoteInputs: HTML {
    let item: QuotedItem

    var body: some HTML {
        fieldset {
            legend { "Quote" }
            Field("quote", "Quote") {
                textarea(.id("quote"), .name("quote"), .rows(3), .required) { item.quote }
            }
            Field("speaker", "Speaker") {
                input(.type(.text), .id("speaker"), .name("speaker"), .value(item.speaker), .required)
            }
            Field("context", "Context", hint: "Shown when the reader opens the quote.") {
                textarea(.id("context"), .name("context"), .rows(5), .required) { item.context }
            }
            Field("sourceLink", "Source link", hint: "Must start with http:// or https://") {
                input(.type(.text), .id("sourceLink"), .name("sourceLink"), .value(item.sourceLink), .required)
            }
        }
    }
}

struct AdvertisementInputs: HTML {
    let ad: Advertisement

    /// An uploaded image is a file on this site; only other addresses are typed.
    private var address: String? {
        if case .endpoint(let url) = ad.imageSource, !url.hasPrefix("/images/") { url } else { nil }
    }

    var body: some HTML {
        fieldset {
            legend { "Advertisement" }
            Field("sponsorName", "Sponsor") {
                input(.type(.text), .id("sponsorName"), .name("sponsorName"), .value(ad.sponsorName), .required)
            }
            div(.class("field-row")) {
                Field("targetURL", "Links to", hint: "Must start with http:// or https://") {
                    input(.type(.text), .id("targetURL"), .name("targetURL"), .value(ad.targetURL), .required)
                }
                Field("priority", "Priority") {
                    select(.id("priority"), .name("priority")) {
                        option(.value("2")) { "High" }.attributes(.selected, when: ad.priority == .high)
                        option(.value("1")) { "Normal" }.attributes(.selected, when: ad.priority == .normal)
                    }
                }
            }
        }

        fieldset {
            legend { "Image" }
            img(.src(ad.imageSource.htmlSrc), .alt(ad.altText), .class("desk-picture"))
            Field("imageFile", "Image file", hint: "JPEG, PNG or WebP, up to 15 MB. Choose a file to replace the image.") {
                input(.type(.file), .id("imageFile"), .name("imageFile"), .accept("image/jpeg,image/png,image/webp"))
            }
            if let address {
                Field("imageURL", "Or image address") {
                    input(.type(.text), .id("imageURL"), .name("image.source.endpoint.url"), .value(address))
                }
            }
            Field("altText", "Alt text", hint: "Describes the image for readers who can't see it.") {
                input(.type(.text), .id("altText"), .name("image.altText"), .value(ad.altText), .required)
            }
        }
    }
}
