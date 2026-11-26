import Foundation
import Testing
@testable import OpenPaperKit

@Suite struct NewsDeskTests {
    private let story = Story(
        category: .news, priority: .normal, title: "Harbour reopens", summary: "Ships are back.", slug: "harbour"
    )

    private func page(filing: Filing?) -> String {
        let item = DeskItem(
            id: story.id, parsed: .story(story, markdown: "Body", html: "<p>Body</p>"),
            actionBase: "/editor/items/x", filing: filing,
            picture: Picture(src: "/images/abc", altText: "The harbour", caption: nil, credit: nil)
        )
        return NewsDeskPage(selected: item, today: "2026-11-20").render()
    }

    private func filing(_ status: ItemStatus, date: String? = nil) -> Filing {
        Filing(status: status, publishDate: date, suggestedDate: "2026-11-20")
    }

    @Test func aSubmittedStoryCanBePublishedOrArchived() {
        let html = page(filing: filing(.submitted))
        #expect(html.contains("Harbour reopens") && html.contains("/images/abc"))
        #expect(html.contains("name=\"publishDate\" value=\"2026-11-20\""))
        #expect(html.contains("/editor/items/x/file") && html.contains("/editor/items/x/archive"))
        #expect(html.contains("/editor/items/x/preview") && html.contains("formtarget=\"preview-frame\""))
        #expect(!html.contains("/editor/items/x/desk"))
    }

    @Test func enterSavesAndNeverPublishes() throws {
        let html = page(filing: filing(.submitted))
        let form = try #require(html.range(of: "desk-item review-form"))
        let first = try #require(html[form.upperBound...].range(of: "<button"))
        let tag = html[first.lowerBound...].prefix(while: { $0 != ">" })
        #expect(tag.contains("default-submit") && !tag.contains("formaction"))
    }

    @Test func anArchivedItemCanComeBack() {
        let html = page(filing: filing(.rejected))
        #expect(html.contains("/editor/items/x/desk") && html.contains("/editor/items/x/file"))
        #expect(!html.contains("/editor/items/x/archive"))
    }

    @Test func anUploadIsSavedBeforeItCanBePublished() {
        let html = page(filing: nil)
        #expect(html.contains("Save to desk") && html.contains("/editor/items/x/cancel"))
        #expect(!html.contains("name=\"publishDate\""))
    }

    @Test func theStatusSaysWhereTheItemStands() {
        func says(_ date: String, _ until: String? = nil) -> String {
            DeskStatus.sentence(.filed, publishDate: date, until: until, today: "2026-11-20")
        }
        #expect(says("2026-11-21").hasPrefix("Scheduled for Saturday"))
        #expect(says("2026-11-20").hasPrefix("Published Friday"))
        #expect(says("2026-11-18", "2026-11-22").hasPrefix("Running"))
        #expect(says("2026-11-17", "2026-11-19").hasPrefix("Ran"))
    }

    @Test func thePreviewShowsEveryKindOrWhatIsWrong() {
        let items: [(ParsedUpload, String)] = [
            (.story(story, markdown: "", html: "<p>Body text</p>"), "Body text"),
            (.agendaPoint(AgendaPoint(subject: "Rate decision", place: "Frankfurt", link: "https://x", summary: "s")), "Rate decision"),
            (.quotedItem(QuotedItem(quote: "Sell", speaker: "Lindeman", context: "c", sourceLink: "https://x")), "Lindeman"),
            (.advertisement(Advertisement(sponsorName: "V", imageSource: .endpoint(url: "/a.webp"), altText: "Watch ad",
                                          targetURL: "https://x", priority: .high)), "Watch ad"),
        ]
        for (item, expected) in items {
            #expect(PreviewPage(parsed: item).render().contains(expected))
        }
        #expect(PreviewPage(parsed: nil, problems: ["Title is required."]).render().contains("Title is required."))
    }
}
