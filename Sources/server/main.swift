import Elementary
import Foundation
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

// The paper (`/`) and the editor (`/editor`), both backed by the SQLite database.
//
// Environment:
//   OPEN_PAPER_DB      database file (default open_paper.sqlite)
//   OPEN_PAPER_IMAGES  folder for pictures (default open_paper-images, next to the database)
//   OPEN_PAPER_PORT    port on 127.0.0.1 (default 8080)
//   OPEN_PAPER_HTTPS   set to 1 when reached over HTTPS, so the login cookie is Secure
//   OPEN_PAPER_TRUST_PROXY  set to 1 behind your own proxy, to limit submissions
//                           by the address it reports in X-Forwarded-For
let environment = ProcessInfo.processInfo.environment
let database = try PaperDatabase(
    path: environment["OPEN_PAPER_DB"] ?? "open_paper.sqlite",
    imageDirectory: environment["OPEN_PAPER_IMAGES"].map { URL(fileURLWithPath: $0) }
)

let arguments = Array(CommandLine.arguments.dropFirst())
if !arguments.isEmpty {
    exit(runAccountCommand(arguments, database: database))
}

let router = Router(context: AppRequestContext.self)
addPublicRoutes(to: router, database: database)

// Public, but forms must be posted from our own pages.
addContributeRoutes(
    to: router.group().add(middleware: SameOriginOnly()),
    database: database,
    trustProxy: environment["OPEN_PAPER_TRUST_PROXY"] == "1"
)

// Everything under /editor: own-site requests only, and (except login) signed in.
let ownSite = router.group().add(middleware: SameOriginOnly())
addLoginRoutes(to: ownSite, database: database, secureCookie: environment["OPEN_PAPER_HTTPS"] == "1")
addEditorRoutes(to: ownSite.group().add(middleware: SignedInOnly(database: database)), database: database)

if try database.editors().isEmpty {
    print("No editor account yet. Create one with: swift run server add-editor you@example.com")
}

let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: environment["OPEN_PAPER_PORT"].flatMap(Int.init) ?? 8080))
)
try await app.runService()
