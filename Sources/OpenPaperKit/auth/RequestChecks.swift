import Foundation

/// Slows down password guessing: after too many failures for one email address
/// within the window, further attempts are refused until the window has passed.
/// Kept in memory, so restarting the server clears it.
package actor LoginThrottle {
    package static let maximumFailures = 5
    package static let window: TimeInterval = 15 * 60
    /// Keeps a flood of made-up addresses from growing memory without limit.
    private static let maximumEntries = 10_000

    private var failures: [String: [Date]] = [:]

    package init() {}

    /// Registers an attempt before the password is checked; false when blocked.
    /// Counting up front means parallel guesses cannot slip past the limit.
    package func attempt(_ email: String, now: Date = Date()) -> Bool {
        let key = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let recent = (failures[key] ?? []).filter { now.timeIntervalSince($0) < Self.window }
        guard recent.count < Self.maximumFailures else {
            failures[key] = recent
            return false
        }
        if failures.count >= Self.maximumEntries {
            failures = failures.filter { $0.value.contains { now.timeIntervalSince($0) < Self.window } }
        }
        failures[key] = recent + [now]
        return true
    }

    /// Forgets the attempts after a successful sign-in.
    package func succeeded(_ email: String) {
        failures[email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = nil
    }
}

package enum RequestChecks {
    /// Whether a state-changing request comes from our own pages (protection
    /// against cross-site request forgery). Browsers say so in `Sec-Fetch-Site`;
    /// older ones send `Origin`. With neither, the request is refused.
    package static func isSameOrigin(secFetchSite: String?, origin: String?, host: String?) -> Bool {
        if let secFetchSite {
            return secFetchSite == "same-origin" || secFetchSite == "none"
        }
        guard let origin, let host, let url = URL(string: origin), let originHost = url.host() else { return false }
        let originAuthority = url.port.map { "\(originHost):\($0)" } ?? originHost
        return originAuthority.lowercased() == host.lowercased()
    }

    /// Where to go after signing in. Only editor pages are accepted, so a
    /// crafted login link cannot send someone to another site.
    package static func safeDestination(_ next: String?) -> String {
        guard let next,
              next == "/editor" || next.hasPrefix("/editor/"),
              !next.hasPrefix("/editor/log"),
              !next.contains("//"), !next.contains("\\"), !next.contains(".."),
              !next.unicodeScalars.contains(where: { $0.value < 0x21 || $0.value > 0x7E })
        else { return "/editor" }
        return next
    }
}
