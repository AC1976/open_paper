import Elementary

package struct Masthead: HTML {
    package let metadata: EditionMetadata
    package let activeSection: PaperSection

    package var body: some HTML {
        header(.class("nyt-masthead")) {
            div(.class("masthead-meta")) {
                span { "VOL. \(metadata.volume) . . . No. \(metadata.issueNumber)" }
                span(.class("masthead-date")) { metadata.formattedDate }
                span { metadata.editionLabel }
            }

            h1(.class("paper-title")) {
                a(.href("/")) { metadata.paperTitle }
            }

            if let subtitle = metadata.subtitle {
                p(.class("paper-subtitle")) { subtitle }
            }

            nav(.class("section-nav")) {
                for section in PaperSection.allCases {
                    let activeClass = (section == activeSection) ? "nav-link active" : "nav-link"
                    a(.href(section.href), .class(activeClass)) {
                        section.displayTitle
                    }
                }
            }
        }
    }
}

