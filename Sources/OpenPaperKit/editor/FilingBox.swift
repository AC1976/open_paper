import Elementary

/// Where a saved item stands, as the edit page needs it.
package struct Filing: Sendable {
    package let status: ItemStatus
    package let publishDate: String?
    /// Offered when the item has no date yet.
    package let suggestedDate: String

    package init(status: ItemStatus, publishDate: String?, suggestedDate: String) {
        self.status = status
        self.publishDate = publishDate
        self.suggestedDate = suggestedDate
    }
}

/// The "Filing" box at the bottom of an edit page. It sits inside the item's
/// form: filing saves the fields and sets the date in one go.
struct FilingBox: HTML {
    let filing: Filing
    let actionBase: String

    var body: some HTML {
        fieldset(.class("filing")) {
            legend { "Filing" }
            p(.class("status")) {
                switch filing.status {
                case .submitted: "On the news desk. Not in the paper yet."
                case .filed: "Filed for \(EditorDates.longDay(filing.publishDate ?? ""))."
                case .rejected: "Rejected. It will not appear in the paper."
                }
            }
            div(.class("field")) {
                label(.for("publishDate")) { "Publish date" }
                input(.type(.date), .id("publishDate"), .name("publishDate"),
                      .value(filing.publishDate ?? filing.suggestedDate))
                small(.class("hint")) { "It appears in the paper of that day, and not before." }
            }
            div(.class("actions")) {
                button(.type(.submit), .class("button primary"), .custom(name: "formaction", value: actionBase + "/file")) {
                    filing.status == .filed ? "Save and change date" : "Save and file"
                }
                if filing.status != .submitted {
                    button(.type(.submit), .class("button"), .custom(name: "formaction", value: actionBase + "/desk"),
                           .custom(name: "formnovalidate", value: "")) { "Back to news desk" }
                }
                if filing.status != .rejected {
                    button(.type(.submit), .class("button quiet"), .custom(name: "formaction", value: actionBase + "/reject"),
                           .custom(name: "formnovalidate", value: "")) { "Reject" }
                }
            }
        }
    }
}
