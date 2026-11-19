import Foundation

package struct AgendaPoint: Codable, Sendable {
    package let id: UUID
    package let subject: String
    package let place: String
    package let link: String
    package let summary: String
    package let eventDate: Date?

    package init(
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
