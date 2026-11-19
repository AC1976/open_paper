import Elementary
import Foundation
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

// The paper (`/`) and the editor (`/editor`), both backed by the SQLite database.
let router = Router()

let databasePath = ProcessInfo.processInfo.environment["OPEN_PAPER_DB"] ?? "open_paper.sqlite"
let database = try PaperDatabase(path: databasePath)
addPublicRoutes(to: router, database: database)
addEditorRoutes(to: router, database: database)

let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
try await app.runService()
