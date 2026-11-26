import Foundation
import Elementary

/// `/editor/issues/{date}`: the paper of one date. Left: what is filed for it.
/// Right: the layout (breaking / prominent / regular) and a preview. There is
/// nothing to publish: the paper appears by itself on its date.
package struct EditionPage: HTMLDocument {
    /// "yyyy-MM-dd"
    package let date: String
    package let items: [DeskEntry]
    package let mode: EditionMode
    package let today: String

    package init(date: String, items: [DeskEntry], mode: EditionMode, today: String) {
        self.date = date
        self.items = items
        self.mode = mode
        self.today = today
    }

    package var title: String { "Edition of \(date)" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    /// Advertisements alone do not make a paper.
    private var hasPaper: Bool { items.contains { $0.kind != .advertisement } }

    private var status: String {
        if items.isEmpty { return "Nothing is filed for this date." }
        if !hasPaper { return "Only advertisements: readers get no paper for this date." }
        return date > today ? "Scheduled. Readers see it from this date." : "Visible to readers."
    }

    package var body: some HTML {
        EditorBar()

        main(.class("review"), .custom(name: "data-date", value: date)) {
            h1(.class("review-title review-heading")) { "Edition of \(EditorDates.longDay(date))" }

            div(.class("review-form")) {
                fieldset {
                    legend { "Date" }
                    form(.method(.get), .action("/editor/issues"), .class("issue-picker")) {
                        div(.class("field")) {
                            label(.for("date")) { "Edition of" }
                            input(.type(.date), .id("date"), .name("date"), .value(date), .required)
                        }
                        button(.type(.submit), .class("button")) { "Open" }
                    }
                }

                fieldset {
                    legend { "Filed for this date (\(items.count))" }
                    if items.isEmpty {
                        p(.class("empty")) { "File items from the news desk." }
                    } else {
                        p(.class("hint list-hint")) { "Click a title to edit it, change its date or send it back." }
                        ul(.class("pick-list")) {
                            for item in items {
                                li {
                                    div(.class("pick-text")) {
                                        a(.href("/editor/items/\(item.id.uuidString)"), .class("pick-title")) { item.title }
                                        if let first = item.publishDate, let last = item.publishUntil, last != first {
                                            small(.class("pick-run")) { "Runs \(EditorDates.run(from: first, until: last))" }
                                        }
                                    }
                                    span(.class("pick-kind")) { item.kind.label }
                                }
                            }
                        }
                    }
                }
            }

            div(.class("review-form")) {
                p(.id("save-error"), .class("problems"), .custom(name: "hidden", value: "")) {
                    "The change could not be saved. Reload the page and try again."
                }
                form(.method(.post), .action("/editor/issues/\(date)/mode"), .enctype(.multipartFormData)) {
                    fieldset {
                        legend { "Layout" }
                        div(.class("mode-options")) {
                            for option in EditionMode.allCases {
                                label(.class("mode-option")) {
                                    input(.type(.radio), .name("mode"), .value(option.rawValue))
                                        .attributes(.checked, when: option == mode)
                                    span {
                                        strong { option.label }
                                        small { option.explanation }
                                    }
                                }
                            }
                        }
                    }
                    noscript { button(.type(.submit), .class("button")) { "Save layout" } }
                }

                p(.class("status")) { status }
                div(.class("actions")) {
                    a(.href("/editor/issues/\(date)/preview"), .target(.blank), .class("button")) { "Preview front page" }
                    if hasPaper && date <= today {
                        a(.href("/issues/\(date)"), .target(.blank), .class("button quiet")) { "View as a reader" }
                    }
                }
            }

            script { HTMLRaw(Self.saveScript) }
        }
    }

    /// Saves the layout as soon as it is chosen.
    private static let saveScript = """
    (function () {
      var date = document.querySelector('main[data-date]').dataset.date;
      var error = document.getElementById('save-error');
      document.querySelectorAll('input[name="mode"]').forEach(function (radio) {
        radio.addEventListener('change', function () {
          var data = new FormData();
          data.append('mode', radio.value);
          error.hidden = true;
          fetch('/editor/issues/' + date + '/mode?fetch=1', { method: 'POST', body: data })
            .then(function (response) { if (!response.ok) { throw new Error(); } })
            .catch(function () { error.hidden = false; });
        });
      });
    })();
    """
}

/// Shown at `/` while nothing has been published.
package struct NoIssuePage: HTMLDocument {
    package init() {}

    package var title: String { "Het Grootboek" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        main(.class("editor-main")) {
            h1 { "Het Grootboek" }
            p(.class("empty")) { "Nothing has been published yet." }
            p { a(.href("/contribute")) { "Send us a story, an agenda point or a quote" } }
            p { a(.href("/editor")) { "Editor: go to the news desk" } }
        }
    }
}
