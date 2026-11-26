import Foundation
import Elementary

/// Where a saved item stands, as the reading pane needs it.
package struct Filing: Sendable {
    package let status: ItemStatus
    package let publishDate: String?
    /// Offered when the item has no date yet.
    package let suggestedDate: String
    package let contributor: Contributor?
    /// True for advertisements, which run from a first through a last day.
    package let takesRange: Bool
    package let publishUntil: String?

    package init(
        status: ItemStatus, publishDate: String?, suggestedDate: String, contributor: Contributor? = nil,
        takesRange: Bool = false, publishUntil: String? = nil
    ) {
        self.takesRange = takesRange
        self.publishUntil = publishUntil
        self.contributor = contributor
        self.status = status
        self.publishDate = publishDate
        self.suggestedDate = suggestedDate
    }
}

/// The item open on the news desk: a saved one, or an upload under review.
package struct DeskItem: Sendable {
    package let id: UUID
    package let parsed: ParsedUpload
    /// The form posts here (save); `/file`, `/archive`, `/desk`, `/preview` and
    /// `/cancel` are appended for the other buttons.
    package let actionBase: String
    /// Nil for an upload that has not been saved yet.
    package let filing: Filing?
    /// A story's current picture.
    package let picture: Picture?
    /// When it came in.
    package let received: Date?
    /// Messages to show above the fields (a failed save).
    package let problems: [String]

    package init(
        id: UUID, parsed: ParsedUpload, actionBase: String, filing: Filing? = nil,
        picture: Picture? = nil, received: Date? = nil, problems: [String] = []
    ) {
        self.id = id
        self.parsed = parsed
        self.actionBase = actionBase
        self.filing = filing
        self.picture = picture
        self.received = received
        self.problems = problems
    }
}

/// The reading pane: one form holding the toolbar (publish date, publish,
/// archive, preview, save), who sent the item, and its editable fields.
///
/// Field names match what `StoryForm` and `ItemForm` read.
struct DeskItemView: HTML {
    let item: DeskItem
    let today: String

    var body: some HTML {
        form(.method(.post), .action(item.actionBase), .enctype(.multipartFormData), .class("desk-item review-form")) {
            input(.type(.hidden), .name("id"), .value(item.parsed.id.uuidString))
            // The first button is what Enter presses: save, never publish.
            button(.type(.submit), .class("default-submit"), .custom(name: "tabindex", value: "-1"),
                   .custom(name: "aria-hidden", value: "true")) { "Save" }

            toolbar

            div(.class("desk-content")) {
                if !item.problems.isEmpty {
                    div(.class("problems")) {
                        p { "The item was not saved:" }
                        ul {
                            for problem in item.problems { li { problem } }
                        }
                    }
                }

                header(.class("desk-heading")) {
                    h1 { title }
                    p(.class("status")) {
                        if let filing = item.filing {
                            DeskStatus.sentence(filing.status, publishDate: filing.publishDate,
                                                until: filing.publishUntil, today: today)
                        } else {
                            "Uploaded file. Save it to the news desk before publishing."
                        }
                    }
                    p(.class("status")) {
                        item.parsed.kind.label
                        if let received = item.received {
                            " · received \(EditorDates.display(received))"
                        }
                        if let contributor = item.filing?.contributor {
                            " · sent in by \(contributor.name), "
                            a(.href("mailto:\(contributor.email)")) { contributor.email }
                        }
                    }
                }

                switch item.parsed {
                case .story(let story, let markdown, _):
                    StoryInputs(story: story, markdown: markdown, picture: item.picture)
                case .agendaPoint(let point):
                    AgendaInputs(item: point)
                case .quotedItem(let quote):
                    QuoteInputs(item: quote)
                case .advertisement(let ad):
                    AdvertisementInputs(ad: ad)
                }
            }
        }
    }

    private var title: String {
        switch item.parsed {
        case .story(let story, _, _): story.title
        case .agendaPoint(let point): point.subject
        case .quotedItem(let quote): quote.speaker
        case .advertisement(let ad): ad.sponsorName
        }
    }

    private var toolbar: some HTML {
        div(.class("desk-toolbar")) {
            div(.class("desk-publish")) {
                if let filing = item.filing {
                    publishDates(filing)
                    submit(filing.status != .filed ? "Publish" : filing.takesRange ? "Change dates" : "Change date",
                           to: "/file", style: "button primary", validates: true)
                    if filing.status != .rejected {
                        submit("Archive", to: "/archive", style: "button", discards: true)
                    }
                    if filing.status != .submitted {
                        submit("Back to desk", to: "/desk", style: "button quiet", discards: true)
                    }
                } else {
                    submit("Save to desk", to: "", style: "button primary", validates: true)
                    submit("Discard", to: "/cancel", style: "button quiet")
                }
            }
            div(.class("desk-edit")) {
                button(.type(.submit), .class("button"), .custom(name: "formaction", value: item.actionBase + "/preview"),
                       .custom(name: "formtarget", value: "preview-frame"), .custom(name: "formnovalidate", value: ""),
                       .custom(name: "data-preview", value: "")) { "Preview" }
                if item.filing != nil {
                    submit("Save", to: "", style: "button", validates: true)
                }
            }
        }
    }

    @HTMLBuilder
    private func publishDates(_ filing: Filing) -> some HTML {
        label(.class("desk-date")) {
            span { filing.takesRange ? "First day" : "Publish date" }
            input(.type(.date), .name("publishDate"), .value(filing.publishDate ?? filing.suggestedDate))
        }
        if filing.takesRange {
            label(.class("desk-date")) {
                span { "Last day" }
                input(.type(.date), .name("publishUntil"),
                      .value(filing.publishUntil ?? filing.publishDate ?? filing.suggestedDate))
            }
        }
    }

    /// A toolbar button. `validates`: the browser checks the fields first.
    /// `discards`: pressing it leaves edits behind.
    private func submit(
        _ text: String, to suffix: String, style: String, validates: Bool = false, discards: Bool = false
    ) -> some HTML {
        button(.type(.submit), .class(style), .custom(name: "formaction", value: item.actionBase + suffix)) { text }
            .attributes(.custom(name: "formnovalidate", value: ""), when: !validates)
            .attributes(.custom(name: "data-discards", value: ""), when: discards)
    }
}
