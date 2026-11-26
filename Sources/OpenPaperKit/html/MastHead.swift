import Elementary

package struct Masthead: HTML {
    package let metadata: EditionMetadata
    package let activeSection: PaperSection

    package var body: some HTML {
        header(.class("nyt-masthead")) {
            div(.class("masthead-meta")) {
                span { "JAARGANG \(metadata.volume) . . . Nr. \(metadata.issueNumber)" }
                span(.class("masthead-date")) { metadata.formattedDate }
                span(.class("masthead-edition")) {
                    span { metadata.editionLabel }
                    a(.href("/contribute"), .class("masthead-contribute")) { "Schrijf mee" }
                }
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

