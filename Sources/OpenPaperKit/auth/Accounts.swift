import CryptoKit
import Foundation
import GRDB
import HummingbirdBcrypt

/// Someone who may use `/editor`.
package struct Editor: Sendable, Equatable {
    package let id: UUID
    package let email: String
}

package enum AccountError: Error, CustomStringConvertible, Sendable, Equatable {
    case invalidEmail
    case passwordTooShort
    case passwordTooLong
    case alreadyExists
    case notFound

    package var description: String {
        switch self {
        case .invalidEmail: "That is not a valid email address."
        case .passwordTooShort: "The password needs at least \(PaperDatabase.minimumPasswordLength) characters."
        case .passwordTooLong: "The password may be at most \(PaperDatabase.maximumPasswordBytes) bytes."
        case .alreadyExists: "There is already an editor with that email address."
        case .notFound: "There is no editor with that email address."
        }
    }
}

// Editor accounts and sessions. Accounts are created on the command line
// (`swift run server add-editor …`); there is deliberately no web sign-up.
extension PaperDatabase {
    package static let minimumPasswordLength = 10
    /// bcrypt ignores everything after 72 bytes, so longer passwords are refused.
    package static let maximumPasswordBytes = 72
    package static let sessionLifetime: TimeInterval = 12 * 3600

    // MARK: Accounts

    /// `cost` is the bcrypt work factor; only tests should lower it.
    @discardableResult
    package func addEditor(email: String, password: String, cost: UInt8 = 12) throws -> Editor {
        let email = try Self.normalised(email: email)
        try Self.check(password: password)
        let hash = Bcrypt.hash(password, cost: cost)
        let id = UUID()
        try queue.write { db in
            let taken = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM editors WHERE email = ?", arguments: [email]) ?? 0
            guard taken == 0 else { throw AccountError.alreadyExists }
            try db.execute(
                sql: "INSERT INTO editors (id, email, passwordHash, createdAt) VALUES (?, ?, ?, ?)",
                arguments: [id.uuidString, email, hash, Date()]
            )
        }
        return Editor(id: id, email: email)
    }

    /// Sets a new password and signs the editor out everywhere.
    package func setPassword(email: String, password: String, cost: UInt8 = 12) throws {
        let email = Self.lowercased(email)
        try Self.check(password: password)
        let hash = Bcrypt.hash(password, cost: cost)
        try queue.write { db in
            try db.execute(sql: "UPDATE editors SET passwordHash = ? WHERE email = ?", arguments: [hash, email])
            guard db.changesCount > 0 else { throw AccountError.notFound }
            try db.execute(
                sql: "DELETE FROM sessions WHERE editorId = (SELECT id FROM editors WHERE email = ?)",
                arguments: [email]
            )
        }
    }

    /// Removes the account; its sessions go with it.
    package func removeEditor(email: String) throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM editors WHERE email = ?", arguments: [Self.lowercased(email)])
            guard db.changesCount > 0 else { throw AccountError.notFound }
        }
    }

    package func editors() throws -> [Editor] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT id, email FROM editors ORDER BY email").compactMap(Self.editor)
        }
    }

    /// The editor with this email and password, or nil.
    package func authenticate(email: String, password: String) throws -> Editor? {
        let row = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT id, email, passwordHash FROM editors WHERE email = ?",
                             arguments: [Self.lowercased(email)])
        }
        // Check a hash even for unknown addresses, so timing does not reveal who has an account.
        let hash: String = row?["passwordHash"] ?? Self.unusedHash
        let matches = Bcrypt.verify(password, hash: hash)
        guard matches, password.utf8.count <= Self.maximumPasswordBytes, let row else { return nil }
        return Self.editor(row)
    }

    // MARK: Sessions

    /// Starts a session and returns the secret to put in the cookie. Only its
    /// hash is stored, so reading the database does not let anyone sign in.
    package func startSession(for editor: Editor, now: Date = Date()) throws -> String {
        var generator = SystemRandomNumberGenerator()
        let token = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
        try queue.write { db in
            try db.execute(sql: "DELETE FROM sessions WHERE expiresAt <= ?", arguments: [now])
            try db.execute(
                sql: "INSERT INTO sessions (tokenHash, editorId, expiresAt) VALUES (?, ?, ?)",
                arguments: [Self.tokenHash(token), editor.id.uuidString, now.addingTimeInterval(Self.sessionLifetime)]
            )
        }
        return token
    }

    /// The editor signed in with this cookie value, if the session is still valid.
    package func editor(forSession token: String, now: Date = Date()) throws -> Editor? {
        try queue.read { db in
            try Row.fetchOne(db, sql: """
                SELECT e.id, e.email FROM sessions s JOIN editors e ON e.id = s.editorId
                WHERE s.tokenHash = ? AND s.expiresAt > ?
                """, arguments: [Self.tokenHash(token), now])
                .flatMap(Self.editor)
        }
    }

    package func endSession(_ token: String) throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM sessions WHERE tokenHash = ?", arguments: [Self.tokenHash(token)])
        }
    }

    // MARK: Helpers

    private static let unusedHash = Bcrypt.hash("no account uses this password", cost: 12)

    private static func editor(_ row: Row) -> Editor? {
        guard let id = UUID(uuidString: row["id"]) else { return nil }
        return Editor(id: id, email: row["email"])
    }

    private static func lowercased(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalised(email: String) throws -> String {
        let email = lowercased(email)
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !email.contains(where: \.isWhitespace)
        else { throw AccountError.invalidEmail }
        return email
    }

    private static func check(password: String) throws {
        guard password.count >= minimumPasswordLength else { throw AccountError.passwordTooShort }
        guard password.utf8.count <= maximumPasswordBytes else { throw AccountError.passwordTooLong }
    }

    private static func tokenHash(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
