import Foundation
import Elementary

// `swift run open_paper ingest [paths...]` checks upload files instead of
// generating the site. Defaults to the `drafts` folder.
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "ingest" {
    let paths = Array(arguments.dropFirst())
    let allAccepted = IngestCommand.run(paths: paths.isEmpty ? ["drafts"] : paths)
    exit(allAccepted ? 0 : 1)
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
