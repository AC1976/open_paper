import Foundation

/// Spam protection for the public contribute form (step E).
package actor SubmissionGuard {
    package static let perSender = 5
    package static let overall = 100
    package static let window: TimeInterval = 3600

    private var bySender: [String: [Date]] = [:]
    private var all: [Date] = []

    package init() {}

    /// Counts one submission; false when this sender, or everyone together, has
    /// sent too many in the last hour. `sender` is the network address.
    package func allow(_ sender: String, now: Date = Date()) -> Bool {
        let recent = { (dates: [Date]) in dates.filter { now.timeIntervalSince($0) < Self.window } }
        all = recent(all)
        guard all.count < Self.overall else { return false }
        let mine = recent(bySender[sender] ?? [])
        guard mine.count < Self.perSender else { return false }
        bySender[sender] = mine + [now]
        all.append(now)
        // Only accepted senders are stored, so `overall` also limits memory.
        if bySender.count > Self.overall * 2 { bySender = bySender.filter { !recent($0.value).isEmpty } }
        return true
    }

    /// The form has a field people cannot see. Only a robot fills it in.
    package static let trapField = "website"

    package static func isRobot(_ form: MultipartForm) -> Bool {
        form.text(trapField) != nil
    }
}
