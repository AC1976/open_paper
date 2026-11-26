import Foundation
import Testing
@testable import OpenPaperKit

private func fields(_ extra: [String: String] = [:]) -> ContributionFields {
    var values = ["name": "Jane Writer", "email": "Jane@Example.org", "category": "news", "title": "A headline",
                  "summary": "A summary", "body": "The **text**."]
    for (key, value) in extra { values[key] = value }
    return ContributionFields(values)
}

private let agendaFields = ["subject": "Meeting", "place": "Utrecht", "link": "https://example.org", "summary": "s"]
private let quoteFields = ["quote": "q", "speaker": "S", "context": "c", "sourceLink": "https://example.org"]

private func problems(_ kind: ContributionKind, _ fields: ContributionFields, image: Data? = nil) -> [String] {
    do { _ = try ContributionForm.read(kind, fields: fields, image: image); return [] }
    catch let error as FormProblems { return error.messages }
    catch { return ["\(error)"] }
}

@Suite struct ContributionFormTests {
    @Test func nameAndEmailAreRequiredForEveryKind() {
        for (kind, extra) in [(ContributionKind.story, [:]), (.agenda, agendaFields), (.quote, quoteFields)] {
            #expect(problems(kind, fields(extra)).isEmpty, "\(kind)")
            #expect(problems(kind, fields(extra.merging(["name": "  "]) { _, new in new })).count == 1)
            for bad in ["", "jane", "jane@", "a b@example.org"] {
                #expect(problems(kind, fields(extra.merging(["email": bad]) { _, new in new })) == ["Vul een geldig e-mailadres in."], "\(bad)")
            }
        }
    }

    @Test func aStoryTakesTheContributorsNameAsByline() throws {
        let result = try ContributionForm.read(.story, fields: fields())
        guard case .story(let story, let markdown, _) = result.item else { Issue.record("not a story"); return }
        #expect(story.author == "Jane Writer" && story.priority == .normal && story.slug == "a-headline")
        #expect(markdown == "The **text**.")
        #expect(result.contributor == Contributor(name: "Jane Writer", email: "jane@example.org"))
    }

    @Test func everyProblemIsReportedAtOnce() {
        let empty = ContributionFields([:])
        #expect(problems(.story, empty).count == 6)    // name, email, category, headline, summary, text
        #expect(problems(.agenda, empty).count == 6)
        #expect(problems(.quote, empty).count == 6)
    }

    @Test func linksAndLengthsAreChecked() {
        #expect(problems(.agenda, fields(agendaFields.merging(["link": "javascript:alert(1)"]) { _, n in n })).count == 1)
        #expect(problems(.story, fields(["title": String(repeating: "x", count: 201)])).count == 1)
        #expect(problems(.story, fields(["body": String(repeating: "x", count: 60_001)])).count == 1)
        #expect(problems(.agenda, fields(agendaFields.merging(["eventDate": "soon"]) { _, n in n })).count == 1)
    }

    @Test func picturesAreCleanedAndNeedADescription() throws {
        #expect(problems(.story, fields(), image: TestImage.png()).count == 1)
        #expect(problems(.story, fields(["altText": "a"]), image: Data("<svg/>".utf8)).count == 1)
        #expect(problems(.story, fields(["altText": "a"]), image: Data(count: StoryForm.maxImageBytes + 1)).count == 1)
        let result = try ContributionForm.read(.story, fields: fields(["altText": "a"]), image: TestImage.png(4))
        #expect(result.picture?.data == TestImage.png(4) && result.picture?.mimeType == "image/png")
        #expect(result.picture?.text.altText == "a")
    }
}

@Suite struct TemplateTests {
    @Test func everyTemplateLoadsIntoTheFormAndCanBeSent() throws {
        for kind in ContributionKind.allCases {
            var loaded = ContributionFields(["name": "Jane", "email": "jane@example.org"])
            loaded.fill(from: try ParsedUpload(kind: kind.itemKind, text: kind.template, name: "t.md"))
            #expect(loaded["name"] == "Jane")
            #expect(problems(kind, loaded).isEmpty, "\(kind): \(problems(kind, loaded))")
        }
    }

    @Test func templatesAskForNothingTheContributorMayNotChoose() {
        for kind in ContributionKind.allCases {
            for forbidden in ["id:", "slug:", "priority:", "publishedAt:", "image:", "author:"] {
                #expect(!kind.template.contains("\n\(forbidden)"), "\(kind) \(forbidden)")
            }
        }
    }
}

@Suite struct ContributorPrivacyTests {
    @Test func submissionsReachTheDeskWithTheirSender() throws {
        let db = try PaperDatabase()
        for (kind, extra) in [(ContributionKind.story, [:]), (.agenda, agendaFields), (.quote, quoteFields)] {
            let result = try ContributionForm.read(kind, fields: fields(extra))
            try db.submit(result.item, from: result.contributor)
        }
        let desk = try db.newsDesk()
        #expect(desk.count == 3)
        #expect(desk.allSatisfy { $0.contributor == Contributor(name: "Jane Writer", email: "jane@example.org") })
        #expect(try db.latestIssueDate(asOf: "2099-01-01") == nil)        // nothing is public until filed
        let html = NewsDeskPage(
            desk: desk,
            selected: DeskItem(id: desk[0].id, parsed: try #require(try db.item(desk[0].id)), actionBase: "/editor/items/x",
                               filing: Filing(status: .submitted, publishDate: nil, suggestedDate: "2026-11-20",
                                              contributor: desk[0].contributor))
        ).render()
        #expect(html.contains("jane@example.org") && html.contains("Jane Writer"))
    }

    @Test func theSenderSurvivesEditingAndFiling() throws {
        let db = try PaperDatabase()
        let result = try ContributionForm.read(.story, fields: fields())
        let id = try db.submit(result.item, from: result.contributor)
        try db.update(result.item, id: id)
        try db.file(id, on: "2026-11-20")
        #expect(try db.entry(id)?.contributor?.email == "jane@example.org")
    }

    @Test func theEmailAddressNeverReachesAReaderPage() throws {
        let db = try PaperDatabase()
        for (kind, extra) in [(ContributionKind.story, [:]), (.agenda, agendaFields), (.quote, quoteFields)] {
            let result = try ContributionForm.read(kind, fields: fields(extra))
            try db.file(try db.submit(result.item, from: result.contributor), on: "2026-11-20")
        }
        let issue = try db.issue(on: "2026-11-20")
        let items = try db.publishedItems(asOf: "2026-11-20")
        let story = try #require(try db.publishedStory(slug: "a-headline", asOf: "2026-11-20"))

        var pages = [NYTFrontPage(metadata: issue.metadata, plan: issue.plan).render()]
        pages.append(ArticlePage(metadata: issue.metadata, story: story.story, bodyHTML: markdownToHTML(story.markdown),
                                 publishDate: story.publishDate).render())
        for section in PaperSection.allCases where section != .frontPage {
            pages.append(SectionPage(metadata: issue.metadata, section: section, stories: items.stories,
                                     agendaPoints: items.agendaPoints, quotedItems: items.quotedItems).render())
        }
        for page in pages { #expect(!page.lowercased().contains("jane@example.org")) }
        #expect(pages[1].contains("Door Jane Writer"))
    }
}

@Suite struct ContributePageTests {
    @Test func theFormKeepsWhatWasTypedAndHasNoTickBox() {
        let attack = "Kept\" onfocus=\"alert(1)"
        let page = ContributePage(kind: .story, fields: fields(["title": attack, "body": "</textarea><script>x</script>"]), problems: ["x"]).render()
        #expect(page.contains("value=\"Kept&quot; onfocus=&quot;alert(1)\""))       // cannot leave the attribute
        #expect(page.contains("&lt;/textarea&gt;&lt;script&gt;"))                    // or the text box
        #expect(page.contains("name=\"website\""))                      // spam trap
        #expect(page.contains("Het wordt nooit gepubliceerd."))
        #expect(!page.contains("type=\"checkbox\""))
    }

    @Test func thePreviewIsHarmless() {
        let story = ContributionPreview(kind: .story, fields: fields([
            "title": "<script>alert(1)</script>", "body": "<img src=x onerror=alert(1)> [x](javascript:alert(1))",
        ])).render()
        #expect(!story.contains("<script>") && !story.contains("<img src=x") && !story.contains("href=\"javascript"))
        for (kind, extra) in [(ContributionKind.agenda, ["link": "javascript:alert(1)"]), (.quote, ["sourceLink": "javascript:alert(1)"])] {
            #expect(!ContributionPreview(kind: kind, fields: fields(extra)).render().contains("javascript:"))
        }
    }

    @Test func theMastheadInvitesContributions() throws {
        let issue = try PaperDatabase().issue(on: "2026-11-20")
        #expect(NYTFrontPage(metadata: issue.metadata, plan: issue.plan).render().contains("href=\"/contribute\""))
    }
}

@Suite struct DutchPaperTests {
    @Test func theMastheadIsDutchWithSchrijfMeeBesideTheEdition() throws {
        let issue = try PaperDatabase().issue(on: "2026-11-20")
        let page = NYTFrontPage(metadata: issue.metadata, plan: issue.plan).render()
        #expect(page.contains("<html lang=\"nl\""))
        #expect(page.contains("vrijdag 20 november 2026") && page.contains("JAARGANG 1"))
        for section in ["Voorpagina", "Nieuws", "Achtergrond", "Opinie", "Agenda", "Quotes"] {
            #expect(page.contains(">\(section)</a>"), "\(section)")
        }
        let meta = try #require(page.range(of: "masthead-meta"))
        let sections = try #require(page.range(of: "<nav class=\"section-nav\""))
        let line = page[meta.upperBound..<sections.lowerBound]
        #expect(line.contains("Namiddag Editie") && line.contains(">Schrijf mee</a>"))
        #expect(!page[sections.upperBound...].contains("/contribute"))
    }

    @Test func contributorsAreAnsweredInDutch() {
        #expect(throws: FormProblems.self) { try ContributionForm.read(.quote, fields: ContributionFields()) }
        do {
            _ = try ContributionForm.read(.quote, fields: ContributionFields())
        } catch let problems as FormProblems {
            #expect(problems.messages.contains("\"Je naam\" mag niet leeg zijn."))
        } catch {
            Issue.record("unexpected \(error)")
        }
    }
}
