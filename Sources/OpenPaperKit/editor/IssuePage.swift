import Foundation
import Elementary

/// `/editor/issues/{date}`: compose an issue.
///
/// Left: the issue date and the inbox. Click a title to edit the item; tick it
/// to move it to the right. Right: what is in this issue, the edition layout
/// (breaking / prominent / regular) and the Publish button.
///
/// Ticking moves the row at once (a small script saves it in the background).
package struct IssuePage: HTMLDocument {
    /// "yyyy-MM-dd"
    package let date: String
    package let inbox: [InboxEntry]
    package let placed: [InboxEntry]
    package let mode: EditionMode
    /// Nil while the issue is a draft.
    package let publishedAt: Date?
    package let problems: [String]

    package init(
        date: String,
        inbox: [InboxEntry],
        placed: [InboxEntry],
        mode: EditionMode = .prominent,
        publishedAt: Date? = nil,
        problems: [String] = []
    ) {
        self.date = date
        self.inbox = inbox
        self.placed = placed
        self.mode = mode
        self.publishedAt = publishedAt
        self.problems = problems
    }

    package var title: String { "Issue of \(date)" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        EditorBar()

        main(.class("review"), .custom(name: "data-date", value: date)) {
            h1(.class("review-title review-heading")) { "Compose the issue of \(date)" }

            // Left: date and inbox
            div(.class("review-form")) {
                fieldset {
                    legend { "Issue" }
                    form(.method(.get), .action("/editor/issues"), .class("issue-picker")) {
                        div(.class("field")) {
                            label(.for("date")) { "Issue of" }
                            input(.type(.date), .id("date"), .name("date"), .value(date), .required)
                        }
                        button(.type(.submit), .class("button")) { "Open" }
                    }
                }

                fieldset {
                    legend { "Inbox ("; span(.id("inbox-count")) { "\(inbox.count)" }; ")" }
                    p(.class("hint list-hint")) { "Click a title to edit it. Tick an item to add it to the issue." }
                    ul(.id("inbox-list"), .class("pick-list")) {
                        for entry in inbox { PickRow(date: date, entry: entry, checked: false) }
                    }
                    p(.id("inbox-empty"), .class("empty")) { "The inbox is empty. Upload items on the Inbox page." }
                        .attributes(.custom(name: "hidden", value: ""), when: !inbox.isEmpty)
                }
            }

            // Right: the issue
            div(.class("review-form")) {
                if !problems.isEmpty {
                    div(.class("problems")) {
                        p { "The issue was not published:" }
                        ul {
                            for problem in problems { li { problem } }
                        }
                    }
                }
                p(.id("move-error"), .class("problems"), .custom(name: "hidden", value: "")) {
                    "The change could not be saved. Reload the page and try again."
                }

                fieldset {
                    legend { "In this issue ("; span(.id("issue-count")) { "\(placed.count)" }; ")" }
                    p(.class("hint list-hint")) { "Untick an item to send it back to the inbox." }
                    ul(.id("issue-list"), .class("pick-list")) {
                        for entry in placed { PickRow(date: date, entry: entry, checked: true) }
                    }
                    p(.id("issue-empty"), .class("empty")) { "Nothing yet. Tick items in the inbox." }
                        .attributes(.custom(name: "hidden", value: ""), when: !placed.isEmpty)
                }

                form(.method(.post), .action("/editor/issues/\(date)/publish"), .enctype(.multipartFormData), .id("publish-form")) {
                    fieldset {
                        legend { "Edition" }
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

                    if let publishedAt {
                        p(.class("status")) { "Published \(EditorDates.display(publishedAt)). Changes show on the front page straight away." }
                    } else {
                        p(.class("status")) { "Draft. Not on the front page yet." }
                    }

                    div(.class("actions")) {
                        button(.type(.submit), .class("button primary")) { publishedAt == nil ? "Publish" : "Publish again" }
                        a(.href("/editor/issues/\(date)/preview"), .target(.blank), .class("button")) { "Preview front page" }
                    }
                }

                noscript {
                    p(.class("notice")) { "JavaScript is needed to move items between the lists." }
                }
            }

            script { HTMLRaw(Self.moveScript) }
        }
    }

    /// Moves a row between the lists when its box is ticked or unticked, and
    /// saves the change; saves the edition when a radio is chosen.
    private static let moveScript = """
    (function () {
      var root = document.querySelector('main[data-date]');
      var date = root.dataset.date;
      var lists = { inbox: document.getElementById('inbox-list'), issue: document.getElementById('issue-list') };
      var error = document.getElementById('move-error');

      function post(path, data) {
        return fetch('/editor/issues/' + date + path + '?fetch=1', { method: 'POST', body: data }).then(function (response) {
          if (!response.ok) { throw new Error(String(response.status)); }
        });
      }

      function refresh() {
        ['inbox', 'issue'].forEach(function (name) {
          var count = lists[name].children.length;
          document.getElementById(name + '-count').textContent = count;
          document.getElementById(name + '-empty').hidden = count > 0;
        });
      }

      document.addEventListener('change', function (event) {
        var input = event.target;
        if (input.matches('input.pick')) {
          var row = input.closest('li');
          var data = new FormData();
          data.append('item', input.value);
          input.disabled = true;
          error.hidden = true;
          post(input.checked ? '/place' : '/remove', data).then(function () {
            lists[input.checked ? 'issue' : 'inbox'].appendChild(row);
            input.disabled = false;
            refresh();
          }).catch(function () {
            input.checked = !input.checked;
            input.disabled = false;
            error.hidden = false;
          });
        } else if (input.matches('input[name="mode"]')) {
          var modeData = new FormData();
          modeData.append('mode', input.value);
          error.hidden = true;
          post('/mode', modeData).catch(function () { error.hidden = false; });
        }
      });
    })();
    """
}

/// One item in a list: a box, the title (a link to the edit page) and its kind.
private struct PickRow: HTML {
    let date: String
    let entry: InboxEntry
    let checked: Bool

    var body: some HTML {
        li {
            label(.class("pick-box")) {
                input(.type(.checkbox), .class("pick"), .name("item"), .value(entry.id.uuidString),
                      .custom(name: "aria-label", value: "In this issue: \(entry.title)"))
                    .attributes(.checked, when: checked)
            }
            a(.href("/editor/issues/\(date)/items/\(entry.id.uuidString)"), .class("pick-title")) { entry.title }
            span(.class("pick-kind")) { entry.kind.label }
        }
    }
}

/// Shown at `/` before any issue has been published.
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
            p(.class("empty")) { "The first issue has not been published yet." }
            p { a(.href("/editor/issues")) { "Editor: compose an issue" } }
        }
    }
}
