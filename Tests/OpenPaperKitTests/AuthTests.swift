import Foundation
import GRDB
import Testing
@testable import OpenPaperKit

@Suite struct AccountTests {
    private let password = "correct horse battery"
    private let cost: UInt8 = 4      // fast bcrypt, tests only

    @Test func signInNeedsTheRightEmailAndPassword() throws {
        let db = try PaperDatabase()
        let editor = try db.addEditor(email: "  Ed@Example.com ", password: password, cost: cost)
        #expect(editor.email == "ed@example.com")
        #expect(try db.authenticate(email: "ED@example.com", password: password) == editor)
        #expect(try db.authenticate(email: "ed@example.com", password: password + "x") == nil)
        #expect(try db.authenticate(email: "other@example.com", password: password) == nil)
        #expect(try db.authenticate(email: "other@example.com", password: "no account uses this password") == nil)
    }

    @Test func passwordsAreStoredOnlyAsHashes() throws {
        let db = try PaperDatabase()
        try db.addEditor(email: "ed@example.com", password: password, cost: cost)
        let stored = try db.queue.read { try String.fetchOne($0, sql: "SELECT passwordHash FROM editors") }
        #expect(stored?.hasPrefix("$2") == true && stored?.contains(password) == false)
    }

    @Test func badAccountsAreRefused() throws {
        let db = try PaperDatabase()
        #expect(throws: AccountError.invalidEmail) { try db.addEditor(email: "nobody", password: password, cost: cost) }
        #expect(throws: AccountError.passwordTooShort) { try db.addEditor(email: "a@b.nl", password: "short", cost: cost) }
        #expect(throws: AccountError.passwordTooLong) {
            try db.addEditor(email: "a@b.nl", password: String(repeating: "x", count: 73), cost: cost)
        }
        try db.addEditor(email: "a@b.nl", password: password, cost: cost)
        #expect(throws: AccountError.alreadyExists) { try db.addEditor(email: "A@B.nl", password: password, cost: cost) }
        #expect(throws: AccountError.notFound) { try db.removeEditor(email: "x@y.nl") }
        #expect(throws: AccountError.notFound) { try db.setPassword(email: "x@y.nl", password: password, cost: cost) }
    }

    @Test func sessionsWorkUntilTheyExpireOrEnd() throws {
        let db = try PaperDatabase()
        let editor = try db.addEditor(email: "ed@example.com", password: password, cost: cost)
        let start = Date()
        let token = try db.startSession(for: editor, now: start)

        #expect(token.count == 64)
        #expect(try db.editor(forSession: token, now: start) == editor)
        #expect(try db.editor(forSession: "nonsense", now: start) == nil)
        #expect(try db.editor(forSession: token, now: start.addingTimeInterval(PaperDatabase.sessionLifetime + 1)) == nil)
        #expect(try db.startSession(for: editor, now: start) != token)

        try db.endSession(token)
        #expect(try db.editor(forSession: token, now: start) == nil)
    }

    @Test func theDatabaseDoesNotHoldTheCookieValue() throws {
        let db = try PaperDatabase()
        let editor = try db.addEditor(email: "ed@example.com", password: password, cost: cost)
        let token = try db.startSession(for: editor)
        let stored = try db.queue.read { try String.fetchOne($0, sql: "SELECT tokenHash FROM sessions") }
        #expect(stored != nil && stored != token)
        #expect(try db.editor(forSession: stored!) == nil)
    }

    @Test func changingThePasswordOrRemovingTheEditorSignsThemOut() throws {
        let db = try PaperDatabase()
        let a = try db.addEditor(email: "a@example.com", password: password, cost: cost)
        let b = try db.addEditor(email: "b@example.com", password: password, cost: cost)
        let tokenA = try db.startSession(for: a), tokenB = try db.startSession(for: b)

        try db.setPassword(email: "a@example.com", password: "another long password", cost: cost)
        #expect(try db.editor(forSession: tokenA) == nil)
        #expect(try db.editor(forSession: tokenB) == b)
        #expect(try db.authenticate(email: "a@example.com", password: password) == nil)

        try db.removeEditor(email: "b@example.com")
        #expect(try db.editor(forSession: tokenB) == nil)
        #expect(try db.editors().map(\.email) == ["a@example.com"])
    }
}

@Suite struct RequestCheckTests {
    @Test func fiveAttemptsThenBlockedUntilTheWindowPasses() async {
        let throttle = LoginThrottle()
        let start = Date()
        for _ in 0..<LoginThrottle.maximumFailures { #expect(await throttle.attempt("ed@example.com", now: start)) }
        #expect(await throttle.attempt(" ED@example.com", now: start) == false)
        #expect(await throttle.attempt("other@example.com", now: start))
        #expect(await throttle.attempt("ed@example.com", now: start.addingTimeInterval(LoginThrottle.window + 1)))
    }

    @Test func successForgetsEarlierAttempts() async {
        let throttle = LoginThrottle()
        for _ in 0..<4 { _ = await throttle.attempt("ed@example.com") }
        await throttle.succeeded("ed@example.com")
        for _ in 0..<5 { #expect(await throttle.attempt("ed@example.com")) }
    }

    @Test func onlyOurOwnPagesMayPost() {
        func ok(_ site: String?, _ origin: String?, _ host: String? = "127.0.0.1:8080") -> Bool {
            RequestChecks.isSameOrigin(secFetchSite: site, origin: origin, host: host)
        }
        #expect(ok("same-origin", nil))
        #expect(ok(nil, "http://127.0.0.1:8080"))
        #expect(ok(nil, "https://paper.example", "paper.example"))
        #expect(!ok("cross-site", "http://127.0.0.1:8080"))   // the browser's own verdict wins
        #expect(!ok("same-site", nil))
        #expect(!ok(nil, "http://evil.example"))
        #expect(!ok(nil, "http://127.0.0.1:9999"))
        #expect(!ok(nil, "null"))
        #expect(!ok(nil, nil))
        #expect(!ok(nil, "http://127.0.0.1:8080", nil))
    }

    @Test func loginOnlyLeadsToEditorPages() {
        #expect(RequestChecks.safeDestination("/editor/issues/2026-11-20") == "/editor/issues/2026-11-20")
        for bad in [nil, "", "/", "https://evil.example", "//evil.example", "/editorial", "/editor//x",
                    "/editor/../x", "/editor/\\evil", "/editor/x\r\nSet-Cookie:a", "/editor/login", "/editor/logout"] {
            #expect(RequestChecks.safeDestination(bad) == "/editor", "\(bad ?? "nil")")
        }
    }
}
