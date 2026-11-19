import OpenPaperKit
import Foundation
import Elementary

// `swift run open_paper ingest` loads every file in `drafts/` instead of
// generating the site. The folder decides which model the YAML must match.
// Add `--save` to also put each item in the inbox of `open_paper.sqlite`.
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "ingest" {
    let database = arguments.contains("--save") ? try PaperDatabase(path: "open_paper.sqlite") : nil

    func check<T: Decodable>(_ type: T.Type, folder: String, save: ((T, String) throws -> SaveOutcome)? = nil) {
        let dir = URL(fileURLWithPath: "drafts").appendingPathComponent(folder)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for file in files.sorted(by: { $0.path < $1.path }) where file.pathExtension == "md" {
            do {
                let upload = try loadUpload(T.self, from: file)
                var note = "\(upload.html.count) characters of HTML"
                if let save, database != nil {
                    note += ", \(try save(upload.item, upload.markdown) == .inserted ? "saved" : "updated")"
                }
                print("OK    \(folder)/\(file.lastPathComponent)  (\(note))")
            } catch {
                print("FAIL  \(folder)/\(file.lastPathComponent)\n      \(error)")
            }
        }
    }
    check(Story.self, folder: "stories") { try database!.save($0, body: $1) }
    check(AgendaPoint.self, folder: "agenda") { item, _ in try database!.save(item) }
    check(QuotedItem.self, folder: "quoted") { item, _ in try database!.save(item) }
    check(Advertisement.self, folder: "advertisements") { item, _ in try database!.save(item) }

    if let database {
        let inbox = try database.inbox()
        print("\nInbox (\(inbox.count) items not placed in an issue):")
        for entry in inbox { print("  \(entry.kind.rawValue.padding(toLength: 13, withPad: " ", startingAt: 0)) \(entry.title)") }
    }
    exit(0)
}

// 1. Define the edition metadata for the masthead
let edition = EditionMetadata(
    paperTitle: "Het Grootboek",
    subtitle: "Met het Oog op de Rekening",
    volume: 1,
    issueNumber: 1,
    editionDate: Date(),
    editionLabel: "Namiddag Editie"
)

// 2. Load sample content across all categories
let stories = makeSampleStories()
let agendaPoints = makeSampleAgendaPoints()
let quotedItems = makeSampleQuotedItems()
let advertisements = makeSampleAdvertisements()

// 3. Build the layout plan (try .breaking, .prominent, or .regular)
let plan = FrontPageLayoutPlan(
    mode: .prominent,
    stories: stories,
    agendaPoints: agendaPoints,
    quotedItems: quotedItems,
    advertisements: advertisements
)

// 4. Render and export the Front Page to index.html
let frontPage = NYTFrontPage(metadata: edition, plan: plan)
let frontPageHTML = frontPage.render()
try frontPageHTML.write(
    to: URL(fileURLWithPath: "index.html"),
    atomically: true,
    encoding: .utf8
)
print("Exported front page to index.html")

// 5. Render and export the News section archive page to news.html
let newsSection = SectionPage(
    metadata: edition,
    section: .news,
    stories: stories,
    agendaPoints: agendaPoints,
    quotedItems: quotedItems
)
let newsHTML = newsSection.render()
try newsHTML.write(
    to: URL(fileURLWithPath: "news.html"),
    atomically: true,
    encoding: .utf8
)
print("Exported news section to news.html")

// 6. Mock-up of the editor's review card, from the news draft, to review.html
let draft = try loadUpload(
    Story.self,
    from: URL(fileURLWithPath: "drafts/stories/news-global-summit-historic-accord-clean-energy-grid.md")
)
let reviewCard = ReviewCard(
    story: draft.item,
    markdown: draft.markdown,
    bodyHTML: draft.html
)
try reviewCard.render().write(
    to: URL(fileURLWithPath: "review.html"),
    atomically: true,
    encoding: .utf8
)
print("Exported editor review card to review.html")
