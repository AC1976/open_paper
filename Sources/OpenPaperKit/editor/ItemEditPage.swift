import Foundation
import Elementary

/// Editable form for an agenda point, a quote or an advertisement. Used both
/// to review a fresh upload and to edit a saved item (stories use `ReviewCard`).
///
/// Field names match what `ItemForm` reads.
package struct ItemEditPage: HTMLDocument {
    package let parsed: ParsedUpload
    package let actionBase: String
    package let heading: String
    package let backHref: String
    package let problems: [String]
    /// Set for saved items, which can be filed or rejected here.
    package let filing: Filing?

    package init(
        parsed: ParsedUpload,
        actionBase: String,
        heading: String,
        backHref: String = "/editor",
        problems: [String] = [],
        filing: Filing? = nil
    ) {
        self.filing = filing
        self.parsed = parsed
        self.actionBase = actionBase
        self.heading = heading
        self.backHref = backHref
        self.problems = problems
    }

    package var title: String { heading }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Editor" }
            a(.href(backHref), .class("editor-link")) { "← Back" }
        }

        main(.class("review single")) {
            form(.method(.post), .action(actionBase), .enctype(.multipartFormData), .class("review-form")) {
                input(.type(.hidden), .name("id"), .value(parsed.id.uuidString))

                h1(.class("review-title")) { heading }

                if !problems.isEmpty {
                    div(.class("problems")) {
                        p { "The item was not saved:" }
                        ul {
                            for problem in problems { li { problem } }
                        }
                    }
                }

                switch parsed {
                case .story:
                    p(.class("notice")) { "Stories are edited on their own review page." }
                case .agendaPoint(let item):
                    agendaFields(item)
                case .quotedItem(let item):
                    quoteFields(item)
                case .advertisement(let ad):
                    advertisementFields(ad)
                }

                div(.class("actions")) {
                    button(.type(.submit), .class("button primary")) { "Save" }
                    button(.type(.submit), .class("button quiet"), .custom(name: "formaction", value: actionBase + "/cancel"),
                           .custom(name: "formnovalidate", value: "")) {
                        "Cancel"
                    }
                }

                if let filing {
                    FilingBox(filing: filing, actionBase: actionBase)
                }
            }
        }
    }

    // MARK: - Fields per kind

    @HTMLBuilder
    private func agendaFields(_ item: AgendaPoint) -> some HTML {
        fieldset {
            legend { "Agenda point" }
            field("subject", "Subject") {
                input(.type(.text), .id("subject"), .name("subject"), .value(item.subject), .required)
            }
            div(.class("field-row")) {
                field("place", "Place") {
                    input(.type(.text), .id("place"), .name("place"), .value(item.place), .required)
                }
                field("eventDate", "Date") {
                    input(.type(.datetimeLocal), .id("eventDate"), .name("eventDate"),
                          .value(item.eventDate.map(EditorDates.dateTime) ?? ""))
                }
            }
            field("link", "Link", hint: "Must start with http:// or https://") {
                input(.type(.text), .id("link"), .name("link"), .value(item.link), .required)
            }
            field("summary", "Summary") {
                textarea(.id("summary"), .name("summary"), .rows(4), .required) { item.summary }
            }
        }
    }

    @HTMLBuilder
    private func quoteFields(_ item: QuotedItem) -> some HTML {
        fieldset {
            legend { "Quote" }
            field("quote", "Quote") {
                textarea(.id("quote"), .name("quote"), .rows(3), .required) { item.quote }
            }
            field("speaker", "Speaker") {
                input(.type(.text), .id("speaker"), .name("speaker"), .value(item.speaker), .required)
            }
            field("context", "Context", hint: "Shown when the reader opens the quote.") {
                textarea(.id("context"), .name("context"), .rows(4), .required) { item.context }
            }
            field("sourceLink", "Source link", hint: "Must start with http:// or https://") {
                input(.type(.text), .id("sourceLink"), .name("sourceLink"), .value(item.sourceLink), .required)
            }
        }
    }

    @HTMLBuilder
    private func advertisementFields(_ ad: Advertisement) -> some HTML {
        fieldset {
            legend { "Advertisement" }
            field("sponsorName", "Sponsor") {
                input(.type(.text), .id("sponsorName"), .name("sponsorName"), .value(ad.sponsorName), .required)
            }
            div(.class("field-row")) {
                field("targetURL", "Links to", hint: "Must start with http:// or https://") {
                    input(.type(.text), .id("targetURL"), .name("targetURL"), .value(ad.targetURL), .required)
                }
                field("priority", "Priority") {
                    select(.id("priority"), .name("priority")) {
                        option(.value("2")) { "High" }.attributes(.selected, when: ad.priority == .high)
                        option(.value("1")) { "Normal" }.attributes(.selected, when: ad.priority == .normal)
                    }
                }
            }
        }

        fieldset {
            legend { "Image" }
            switch ad.imageSource {
            case .blob(let data, _):
                p(.class("notice")) {
                    "This advertisement has an uploaded image (\(max(data.count / 1024, 1)) KB). Choose a file to replace it."
                }
            case .endpoint(let url):
                p(.class("notice")) { "Current image: "; code { url } }
            }
            field("imageFile", "Image file", hint: "JPEG, PNG or WebP, up to 5 MB.") {
                input(.type(.file), .id("imageFile"), .name("imageFile"), .accept("image/jpeg,image/png,image/webp"))
            }
            if case .endpoint(let url) = ad.imageSource {
                field("imageURL", "Or image address") {
                    input(.type(.text), .id("imageURL"), .name("image.source.endpoint.url"), .value(url))
                }
            }
            field("altText", "Alt text", hint: "Describes the image for readers who can't see it.") {
                input(.type(.text), .id("altText"), .name("image.altText"), .value(ad.altText), .required)
            }
        }
    }

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
}
