import Foundation
import Elementary

/// `/contribute/{kind}`: write a contribution (or load a filled-in template)
/// with a preview beside it.
package struct ContributePage: HTMLDocument {
    package let kind: ContributionKind
    package let fields: ContributionFields
    package let problems: [String]
    /// A message after a template was loaded into the form.
    package let notice: String?

    package init(
        kind: ContributionKind, fields: ContributionFields = ContributionFields(),
        problems: [String] = [], notice: String? = nil
    ) {
        self.kind = kind
        self.fields = fields
        self.problems = problems
        self.notice = notice
    }

    private var path: String { "/contribute/\(kind.rawValue)" }

    package var title: String { "Contribute — Het Grootboek" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Contribute" }
            a(.href("/"), .class("editor-link")) { "← The paper" }
        }

        main(.class("review"), .custom(name: "data-path", value: path)) {
            div(.class("contribute-intro")) {
                h1(.class("review-title")) { "Send us something for the paper" }
                p { "Our editors read everything that comes in and decide what appears, and when." }
                nav(.class("kind-tabs"), .custom(name: "aria-label", value: "What are you sending?")) {
                    for option in ContributionKind.allCases {
                        a(.href("/contribute/\(option.rawValue)"), .class("button")) { option.label }
                            .attributes(.custom(name: "aria-current", value: "page"), when: option == kind)
                    }
                }
            }

            div(.class("review-form")) {
                if !problems.isEmpty {
                    div(.class("problems")) {
                        p { "Not sent yet:" }
                        ul {
                            for problem in problems { li { problem } }
                        }
                    }
                }
                if let notice { p(.class("notice")) { notice } }

                fieldset {
                    legend { "Prefer a file?" }
                    p(.class("status")) {
                        a(.href("/contribute/templates/\(kind.rawValue).md"), .custom(name: "download", value: "\(kind.rawValue).md")) {
                            "Download the \(kind.label.lowercased()) template"
                        }
                        ", fill it in, and load it here. Check it, then send it."
                    }
                    form(.method(.post), .action("\(path)/load"), .enctype(.multipartFormData), .class("issue-picker"), .id("load-form")) {
                        input(.type(.hidden), .name("name"), .value(fields["name"]))
                        input(.type(.hidden), .name("email"), .value(fields["email"]))
                        div(.class("field")) {
                            label(.for("file")) { "Filled-in template" }
                            input(.type(.file), .id("file"), .name("file"), .accept(".md,text/markdown,text/plain"), .required)
                        }
                        button(.type(.submit), .class("button")) { "Load into form" }
                    }
                }

                form(.method(.post), .action(path), .enctype(.multipartFormData), .id("contribution")) {
                    div(.class("trap"), .custom(name: "aria-hidden", value: "true")) {
                        label(.for(SubmissionGuard.trapField)) { "Leave this empty" }
                        input(.type(.text), .id(SubmissionGuard.trapField), .name(SubmissionGuard.trapField),
                              .custom(name: "tabindex", value: "-1"), .custom(name: "autocomplete", value: "off"))
                    }

                    fieldset {
                        legend { "About you" }
                        text("name", "Your name", limit: SubmissionLimits.name, required: true, autocomplete: "name")
                        div(.class("field")) {
                            label(.for("email")) { "Email address" }
                            input(.type(.email), .id("email"), .name("email"), .value(fields["email"]), .required,
                                  .custom(name: "maxlength", value: "\(ContributionForm.emailLimit)"),
                                  .custom(name: "autocomplete", value: "email"))
                        }
                        p(.class("privacy")) {
                            "Your name may appear in the paper with your contribution. Your email address is seen only by our editors, who may use it to contact you. It is never published."
                        }
                    }

                    switch kind {
                    case .story: storyFields
                    case .agenda: agendaFields
                    case .quote: quoteFields
                    }

                    div(.class("actions")) {
                        button(.type(.submit), .class("button primary")) { "Send to the editors" }
                    }
                }
            }

            aside(.class("review-preview"), .id("preview")) {
                ContributionPreview(kind: kind, fields: fields)
            }

            script { HTMLRaw(Self.previewScript) }
        }
    }

    // MARK: - Fields

    @HTMLBuilder
    private var storyFields: some HTML {
        fieldset {
            legend { "Your story" }
            div(.class("field")) {
                label(.for("category")) { "Category" }
                select(.id("category"), .name("category")) {
                    for category in [StoryCategory.news, .background, .opinion] {
                        option(.value(category.rawValue)) { category.rawValue.capitalized }
                            .attributes(.selected, when: category.rawValue == fields["category"])
                    }
                }
            }
            text("title", "Headline", limit: SubmissionLimits.title, required: true)
            area("summary", "Summary", rows: 3, limit: SubmissionLimits.summary, required: true)
            area("extendedSummary", "Extended summary (optional)", rows: 3, limit: SubmissionLimits.summary)
            area("body", "Article text", rows: 14, limit: SubmissionLimits.body, required: true,
                 hint: "Markdown: ## subheading, **bold**, - list, [link](https://…)", extraClass: "markdown")
        }
        fieldset {
            legend { "Picture (optional)" }
            div(.class("field")) {
                label(.for("imageFile")) { "Picture file" }
                input(.type(.file), .id("imageFile"), .name("imageFile"), .accept("image/jpeg,image/png,image/webp"))
                small(.class("hint")) { "JPEG, PNG or WebP, up to 15 MB. Large pictures are scaled down and location data is removed. If the form comes back, choose it again." }
                img(.id("thumbnail"), .class("thumbnail"), .alt("The picture you chose"), .custom(name: "hidden", value: ""))
            }
            text("altText", "Description of the picture", limit: SubmissionLimits.title, hint: "Required with a picture, for readers who can't see it.")
            text("caption", "Caption (optional)", limit: SubmissionLimits.title)
            text("credit", "Picture credit (optional)", limit: SubmissionLimits.name)
        }
    }

    @HTMLBuilder
    private var agendaFields: some HTML {
        fieldset {
            legend { "The event" }
            text("subject", "Subject", limit: SubmissionLimits.title, required: true)
            text("place", "Place", limit: SubmissionLimits.name, required: true)
            div(.class("field")) {
                label(.for("eventDate")) { "Date and time (optional)" }
                input(.type(.datetimeLocal), .id("eventDate"), .name("eventDate"), .value(fields["eventDate"]))
            }
            text("link", "Link", limit: SubmissionLimits.link, required: true, hint: "Must start with http:// or https://")
            area("summary", "Summary", rows: 4, limit: SubmissionLimits.summary, required: true)
        }
    }

    @HTMLBuilder
    private var quoteFields: some HTML {
        fieldset {
            legend { "The quote" }
            area("quote", "Quote", rows: 3, limit: SubmissionLimits.summary, required: true)
            text("speaker", "Who said it", limit: SubmissionLimits.name, required: true)
            area("context", "Context", rows: 4, limit: SubmissionLimits.summary, required: true,
                 hint: "When and where it was said.")
            text("sourceLink", "Source link", limit: SubmissionLimits.link, required: true, hint: "Must start with http:// or https://")
        }
    }

    private func text(
        _ name: String, _ title: String, limit: Int, required: Bool = false,
        hint: String? = nil, autocomplete: String = "off"
    ) -> some HTML {
        div(.class("field")) {
            label(.for(name)) { title }
            input(.type(.text), .id(name), .name(name), .value(fields[name]),
                  .custom(name: "maxlength", value: "\(limit)"), .custom(name: "autocomplete", value: autocomplete))
                .attributes(.required, when: required)
            if let hint { small(.class("hint")) { hint } }
        }
    }

    private func area(
        _ name: String, _ title: String, rows: Int, limit: Int, required: Bool = false,
        hint: String? = nil, extraClass: String = ""
    ) -> some HTML {
        div(.class("field")) {
            label(.for(name)) { title }
            textarea(.id(name), .name(name), .rows(rows), .class(extraClass),
                     .custom(name: "maxlength", value: "\(limit)")) { fields[name] }
                .attributes(.required, when: required)
            if let hint { small(.class("hint")) { hint } }
        }
    }

    /// Refreshes the preview shortly after typing stops, and shows the chosen
    /// picture. The email address and the picture are not sent for previews.
    private static let previewScript = """
    (function () {
      var path = document.querySelector('main[data-path]').dataset.path;
      var form = document.getElementById('contribution');
      var preview = document.getElementById('preview');
      var timer, latest = 0;
      function refresh() {
        var data = new FormData(form);
        data.delete('imageFile');
        data.delete('email');
        var mine = ++latest;
        fetch(path + '/preview', { method: 'POST', body: data })
          .then(function (response) { if (!response.ok) { throw new Error(); } return response.text(); })
          .then(function (html) { if (mine === latest) { preview.innerHTML = html; } })
          .catch(function () {});
      }
      form.addEventListener('input', function () { clearTimeout(timer); timer = setTimeout(refresh, 500); });
      var file = document.getElementById('imageFile');
      if (file) {
        file.addEventListener('change', function () {
          var thumbnail = document.getElementById('thumbnail');
          if (file.files.length) { thumbnail.src = URL.createObjectURL(file.files[0]); }
          thumbnail.hidden = !file.files.length;
        });
      }
      // Loading a template keeps the name and email already typed.
      document.getElementById('load-form').addEventListener('submit', function (event) {
        ['name', 'email'].forEach(function (key) {
          event.target.elements[key].value = form.elements[key].value;
        });
      });
    })();
    """
}

/// How the contribution would look in the paper. Used on the page and, alone,
/// as the live preview.
package struct ContributionPreview: HTML, Sendable {
    package let kind: ContributionKind
    package let fields: ContributionFields

    package init(kind: ContributionKind, fields: ContributionFields) {
        self.kind = kind
        self.fields = fields
    }

    private func value(_ name: String, _ placeholder: String) -> String {
        let value = fields[name].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? placeholder : String(value.prefix(SubmissionLimits.body))
    }

    private func link(_ name: String) -> String {
        HTMLSanitizer.safeLink(fields[name]) ?? "#"
    }

    package var body: some HTML {
        switch kind {
        case .story:
            StoryPreview(
                story: Story(
                    category: StoryCategory(rawValue: fields["category"]) ?? .news, priority: .normal,
                    title: value("title", "Your headline"), summary: value("summary", "Your summary appears here."),
                    slug: "preview",
                    author: value("name", "Your name")
                ),
                bodyHTML: markdownToHTML(value("body", "Your article text appears here."))
            )
        case .agenda:
            h2(.class("preview-label")) { "Agenda" }
            div(.class("preview-frame broadsheet")) {
                AgendaSection(points: [AgendaPoint(
                    subject: value("subject", "Subject"), place: value("place", "Place"), link: link("link"),
                    summary: value("summary", "Your summary appears here.")
                )])
            }
        case .quote:
            h2(.class("preview-label")) { "Quoted" }
            div(.class("preview-frame broadsheet")) {
                QuotedSection(items: [QuotedItem(
                    quote: value("quote", "The quote"), speaker: value("speaker", "Speaker"),
                    context: value("context", "Context"), sourceLink: link("sourceLink")
                )])
            }
        }
    }
}

/// Shown after something was sent in.
package struct ThankYouPage: HTMLDocument {
    package init() {}

    package var title: String { "Thank you — Het Grootboek" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Contribute" }
            a(.href("/"), .class("editor-link")) { "← The paper" }
        }
        main(.class("editor-main")) {
            h1 { "Thank you" }
            p { "Your contribution is on its way to the editors. They decide what appears in the paper, and when." }
            p { a(.href("/contribute")) { "Send something else" } }
        }
    }
}
