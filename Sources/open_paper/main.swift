import OpenPaperKit
import Foundation
import Elementary

// `swift run open_paper ingest` loads every file in `drafts/` instead of
// generating the site. The folder decides which model the YAML must match.
if CommandLine.arguments.dropFirst().first == "ingest" {
    func check<T: Decodable>(_ type: T.Type, folder: String) {
        let dir = URL(fileURLWithPath: "drafts").appendingPathComponent(folder)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "md" {
            do {
                let upload = try loadUpload(T.self, from: file)
                print("OK    \(folder)/\(file.lastPathComponent)  (\(upload.html.count) characters of HTML)")
            } catch {
                print("FAIL  \(folder)/\(file.lastPathComponent)\n      \(error)")
            }
        }
    }
    check(Story.self, folder: "stories")
    check(AgendaPoint.self, folder: "agenda")
    check(QuotedItem.self, folder: "quoted")
    check(Advertisement.self, folder: "advertisements")
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
    bodyHTML: draft.html,
    issueDate: draft.item.publishedAt ?? Date()
)
try reviewCard.render().write(
    to: URL(fileURLWithPath: "review.html"),
    atomically: true,
    encoding: .utf8
)
print("Exported editor review card to review.html")
