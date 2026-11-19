import Elementary
import Foundation
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

// Smoke test for step 0: a bare Hummingbird server that renders the sample
// front page with the shared library. Real editor routes come later.
let router = Router()

router.get("/") { _, _ -> HTMLResponse in
    let edition = EditionMetadata(
        paperTitle: "Het Grootboek",
        subtitle: "Met het Oog op de Rekening",
        volume: 1,
        issueNumber: 1,
        editionDate: Date(),
        editionLabel: "Namiddag Editie"
    )
    let plan = FrontPageLayoutPlan(
        mode: .prominent,
        stories: makeSampleStories(),
        agendaPoints: makeSampleAgendaPoints(),
        quotedItems: makeSampleQuotedItems(),
        advertisements: makeSampleAdvertisements()
    )
    return HTMLResponse { NYTFrontPage(metadata: edition, plan: plan) }
}

let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
try await app.runService()
