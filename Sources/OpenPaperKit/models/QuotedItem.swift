import Foundation

package struct QuotedItem: Codable, Sendable {
    package let id: UUID
    package let quote: String
    package let speaker: String
    package let context: String      // Revealed on click
    package let sourceLink: String   // Link to the original source

    package init(
        id: UUID = UUID(),
        quote: String,
        speaker: String,
        context: String,
        sourceLink: String
    ) {
        self.id = id
        self.quote = quote
        self.speaker = speaker
        self.context = context
        self.sourceLink = sourceLink
    }
}
