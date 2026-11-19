import Foundation

struct AgendaPoint: Codable, Sendable {
    let id: UUID
    let subject: String
    let place: String
    let link: String
    let summary: String
    let eventDate: Date?

    init(
        id: UUID = UUID(),
        subject: String,
        place: String,
        link: String,
        summary: String,
        eventDate: Date? = nil
    ) {
        self.id = id
        self.subject = subject
        self.place = place
        self.link = link
        self.summary = summary
        self.eventDate = eventDate
    }
}
