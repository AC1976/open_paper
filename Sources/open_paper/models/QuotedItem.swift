import Foundation

struct QuotedItem: Codable, Sendable {
    let id: UUID
    let quote: String
    let speaker: String
    let context: String      // Revealed on click
    let sourceLink: String   // Link to the original source

    init(
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
