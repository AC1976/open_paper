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

    package var title: String { "Schrijf mee — Het Grootboek" }
    package var lang: String { "nl" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Schrijf mee" }
            a(.href("/"), .class("editor-link")) { "← Naar de krant" }
        }

        main(.class("review"), .custom(name: "data-path", value: path)) {
            div(.class("contribute-intro")) {
                h1(.class("review-title")) { "Stuur ons iets voor de krant" }
                p { "De redactie leest alles wat binnenkomt en bepaalt wat er in de krant komt, en wanneer." }
                nav(.class("kind-tabs"), .custom(name: "aria-label", value: "Wat stuur je in?")) {
                    for option in ContributionKind.allCases {
                        a(.href("/contribute/\(option.rawValue)"), .class("button")) { option.label }
                            .attributes(.custom(name: "aria-current", value: "page"), when: option == kind)
                    }
                }
            }

            div(.class("review-form")) {
                if !problems.isEmpty {
                    div(.class("problems")) {
                        p { "Nog niet verzonden:" }
                        ul {
                            for problem in problems { li { problem } }
                        }
                    }
                }
                if let notice { p(.class("notice")) { notice } }

                fieldset {
                    legend { "Liever een bestand?" }
                    p(.class("status")) {
                        a(.href("/contribute/templates/\(kind.rawValue).md"), .custom(name: "download", value: "\(kind.rawValue).md")) {
                            "Download het sjabloon voor \(kind.phrase)"
                        }
                        ", vul het in en laad het hier. Controleer het en verstuur het daarna."
                    }
                    form(.method(.post), .action("\(path)/load"), .enctype(.multipartFormData), .class("issue-picker"), .id("load-form")) {
                        input(.type(.hidden), .name("name"), .value(fields["name"]))
                        input(.type(.hidden), .name("email"), .value(fields["email"]))
                        div(.class("field")) {
                            label(.for("file")) { "Ingevuld sjabloon" }
                            input(.type(.file), .id("file"), .name("file"), .accept(".md,text/markdown,text/plain"), .required)
                        }
                        button(.type(.submit), .class("button")) { "In het formulier laden" }
                    }
                }

                form(.method(.post), .action(path), .enctype(.multipartFormData), .id("contribution")) {
                    div(.class("trap"), .custom(name: "aria-hidden", value: "true")) {
                        label(.for(SubmissionGuard.trapField)) { "Laat dit leeg" }
                        input(.type(.text), .id(SubmissionGuard.trapField), .name(SubmissionGuard.trapField),
                              .custom(name: "tabindex", value: "-1"), .custom(name: "autocomplete", value: "off"))
                    }

                    fieldset {
                        legend { "Over jou" }
                        text("name", "Je naam", limit: SubmissionLimits.name, required: true, autocomplete: "name")
                        div(.class("field")) {
                            label(.for("email")) { "E-mailadres" }
                            input(.type(.email), .id("email"), .name("email"), .value(fields["email"]), .required,
                                  .custom(name: "maxlength", value: "\(ContributionForm.emailLimit)"),
                                  .custom(name: "autocomplete", value: "email"))
                        }
                        p(.class("privacy")) {
                            "Je naam kan bij je bijdrage in de krant staan. Je e-mailadres ziet alleen de redactie, die het kan gebruiken om contact met je op te nemen. Het wordt nooit gepubliceerd."
                        }
                    }

                    switch kind {
                    case .story: storyFields
                    case .agenda: agendaFields
                    case .quote: quoteFields
                    }

                    div(.class("actions")) {
                        button(.type(.submit), .class("button primary")) { "Verstuur naar de redactie" }
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
            legend { "Je artikel" }
            div(.class("field")) {
                label(.for("category")) { "Rubriek" }
                select(.id("category"), .name("category")) {
                    for category in [StoryCategory.news, .background, .opinion] {
                        option(.value(category.rawValue)) { PaperSection(rawValue: category.rawValue)?.displayTitle ?? category.rawValue }
                            .attributes(.selected, when: category.rawValue == fields["category"])
                    }
                }
            }
            text("title", "Kop", limit: SubmissionLimits.title, required: true)
            area("summary", "Samenvatting", rows: 3, limit: SubmissionLimits.summary, required: true)
            area("extendedSummary", "Uitgebreide samenvatting (optioneel)", rows: 3, limit: SubmissionLimits.summary)
            area("body", "Tekst", rows: 14, limit: SubmissionLimits.body, required: true,
                 hint: "Markdown: ## tussenkop, **vet**, - lijst, [link](https://…)", extraClass: "markdown")
        }
        fieldset {
            legend { "Foto (optioneel)" }
            div(.class("field")) {
                label(.for("imageFile")) { "Fotobestand" }
                input(.type(.file), .id("imageFile"), .name("imageFile"), .accept("image/jpeg,image/png,image/webp"))
                small(.class("hint")) { "JPEG, PNG of WebP, maximaal 15 MB. Grote foto's worden verkleind en locatiegegevens worden verwijderd. Komt het formulier terug, kies de foto dan opnieuw." }
                img(.id("thumbnail"), .class("thumbnail"), .alt("De gekozen foto"), .custom(name: "hidden", value: ""))
            }
            text("altText", "Beschrijving van de foto", limit: SubmissionLimits.title, hint: "Verplicht bij een foto, voor lezers die haar niet kunnen zien.")
            text("caption", "Bijschrift (optioneel)", limit: SubmissionLimits.title)
            text("credit", "Fotograaf of bron (optioneel)", limit: SubmissionLimits.name)
        }
    }

    @HTMLBuilder
    private var agendaFields: some HTML {
        fieldset {
            legend { "De gebeurtenis" }
            text("subject", "Onderwerp", limit: SubmissionLimits.title, required: true)
            text("place", "Plaats", limit: SubmissionLimits.name, required: true)
            div(.class("field")) {
                label(.for("eventDate")) { "Datum en tijd (optioneel)" }
                input(.type(.datetimeLocal), .id("eventDate"), .name("eventDate"), .value(fields["eventDate"]))
            }
            text("link", "Link", limit: SubmissionLimits.link, required: true, hint: "Begint met http:// of https://")
            area("summary", "Samenvatting", rows: 4, limit: SubmissionLimits.summary, required: true)
        }
    }

    @HTMLBuilder
    private var quoteFields: some HTML {
        fieldset {
            legend { "De quote" }
            area("quote", "Quote", rows: 3, limit: SubmissionLimits.summary, required: true)
            text("speaker", "Wie zei het", limit: SubmissionLimits.name, required: true)
            area("context", "Context", rows: 4, limit: SubmissionLimits.summary, required: true,
                 hint: "Wanneer en waar het gezegd is.")
            text("sourceLink", "Link naar de bron", limit: SubmissionLimits.link, required: true, hint: "Begint met http:// of https://")
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
                    title: value("title", "Je kop"), summary: value("summary", "Hier verschijnt je samenvatting."),
                    slug: "preview",
                    author: value("name", "Je naam")
                ),
                bodyHTML: markdownToHTML(value("body", "Hier verschijnt je tekst.")),
                labels: (front: "Voorpagina", article: "Artikelpagina")
            )
        case .agenda:
            h2(.class("preview-label")) { "Agenda" }
            div(.class("preview-frame broadsheet")) {
                AgendaSection(points: [AgendaPoint(
                    subject: value("subject", "Onderwerp"), place: value("place", "Plaats"), link: link("link"),
                    summary: value("summary", "Hier verschijnt je samenvatting.")
                )])
            }
        case .quote:
            h2(.class("preview-label")) { "Quotes" }
            div(.class("preview-frame broadsheet")) {
                QuotedSection(items: [QuotedItem(
                    quote: value("quote", "De quote"), speaker: value("speaker", "Spreker"),
                    context: value("context", "Context"), sourceLink: link("sourceLink")
                )])
            }
        }
    }
}

/// Shown after something was sent in.
package struct ThankYouPage: HTMLDocument {
    package init() {}

    package var title: String { "Bedankt — Het Grootboek" }
    package var lang: String { "nl" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Schrijf mee" }
            a(.href("/"), .class("editor-link")) { "← Naar de krant" }
        }
        main(.class("editor-main")) {
            h1 { "Bedankt" }
            p { "Je bijdrage is onderweg naar de redactie. Zij bepaalt wat er in de krant komt, en wanneer." }
            p { a(.href("/contribute")) { "Nog iets insturen" } }
        }
    }
}
