import Foundation
import Elementary

package struct QuotedSection: HTML {
    package let items: [QuotedItem]

    package var body: some HTML {
        section(.class("rail-section quoted-section")) {
            h3(.class("rail-header")) { "Quotes" }

            for item in items {
                details(.class("quote-card")) {
                    summary(.class("quote-trigger")) {
                        blockquote(.class("quote-text")) { "“\(item.quote)”" }
                        span(.class("quote-speaker")) { "— \(item.speaker)" }
                    }
                    div(.class("quote-details")) {
                        p(.class("quote-context")) { item.context }
                        a(.href(item.sourceLink), .class("quote-source-link")) {
                            "Lees de oorspronkelijke bron →"
                        }
                    }
                }
            }
        }
    }
}
