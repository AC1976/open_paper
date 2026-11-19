import Foundation
import Testing
@testable import OpenPaperKit

@Suite struct ArticleTextTests {
    @Test func readingTimeRoundsUpAndNeverDropsBelowOne() {
        #expect(ArticleText.readingMinutes("<p>short</p>") == 1)
        let words = Array(repeating: "word", count: 221).joined(separator: " ")
        #expect(ArticleText.readingMinutes("<p>\(words)</p>") == 2)
        #expect(ArticleText.readingMinutes("") == 1)
    }

    @Test func plainTextDropsTagsAndDecodesEntities() {
        #expect(ArticleText.plainText("<p>Fish &amp; <em>chips</em></p>") == "Fish & chips")
    }

    @Test func headingsGetUniqueAnchorsAndAContentsList() {
        let html = "<p>x</p><h2>Key commitments</h2><p>y</p><h2>Key commitments</h2><h2>Fish &amp; <em>Chips</em></h2><h2>!!!</h2>"
        let (anchored, headings) = ArticleText.withHeadingAnchors(html)
        #expect(headings.map(\.id) == ["key-commitments", "key-commitments-2", "fish-chips", "section"])
        #expect(headings.map(\.title) == ["Key commitments", "Key commitments", "Fish & Chips", "!!!"])
        #expect(anchored.contains("<h2 id=\"key-commitments-2\">Key commitments</h2>"))
        #expect(anchored.contains("<h2 id=\"fish-chips\">Fish &amp; <em>Chips</em></h2>"))   // the heading's own markup is kept
        #expect(ArticleText.withHeadingAnchors("<p>no headings</p>").headings.isEmpty)
    }

    @Test func datesUseThePapersTimeZone() {
        let published = ISO8601DateFormatter().date(from: "2026-11-20T05:00:00Z")!      // 06:00 in Amsterdam
        #expect(ArticleText.dateTime(published) == "November 20, 2026, 6:00 AM")
        #expect(ArticleText.updatedText(published.addingTimeInterval(1800), after: published) == "6:30 AM")
        #expect(ArticleText.updatedText(published.addingTimeInterval(86_400), after: published) == "November 21, 2026, 6:00 AM")
    }
}

@Suite struct ArticlePageTests {
    private let metadata = EditionMetadata(paperTitle: "Het Grootboek", volume: 1, issueNumber: 1, editionDate: Date(), editionLabel: "Editie")

    private func story(
        _ category: StoryCategory, priority: StoryPriority = .normal, title: String = "A headline", author: String? = "Jane Doe",
        extended: String? = "More detail.", image: StoryImage? = nil
    ) -> Story {
        Story(
            category: category, priority: priority, title: title, summary: "The summary.", extendedSummary: extended,
            slug: "a-headline", publishedAt: ISO8601DateFormatter().date(from: "2026-11-20T05:00:00Z"), author: author, image: image
        )
    }

    private func render(_ story: Story, body: String = "<p>Body text.</p>", related: [Story] = []) -> String {
        ArticlePage(metadata: metadata, story: story, bodyHTML: body, related: related).render()
    }

    @Test func newsHasARedKickerAndBreakingNewsGetsTheLiveDot() {
        let normal = render(story(.news))
        #expect(normal.contains("class=\"article article-news\""))
        #expect(!normal.contains("class=\"live-dot\"") && !normal.contains("article-breaking\""))
        #expect(normal.contains("More detail."))              // extended summary under the standfirst

        let breaking = render(story(.news, priority: .high))
        #expect(breaking.contains("class=\"article article-news article-breaking\""))
        #expect(breaking.contains("class=\"live-dot\"") && breaking.contains("Breaking news"))
    }

    @Test func backgroundHasAnInBriefBoxAndAContentsList() {
        let page = render(story(.background), body: "<h2>First part</h2><p>a</p><h2>Second part</h2><p>b</p>")
        #expect(page.contains("class=\"article article-background\"") && page.contains("Analysis &amp; Background"))
        #expect(page.contains("In brief") && page.contains("More detail."))
        #expect(page.contains("In this article"))
        #expect(page.contains("href=\"#first-part\"") && page.contains("id=\"second-part\""))
    }

    @Test func backgroundWithoutHeadingsHasNoContentsListAndFallsBackToTheSummary() {
        let page = render(story(.background, extended: nil), body: "<p>plain</p>")
        #expect(!page.contains("In this article"))
        #expect(page.contains("In brief") && page.contains("The summary."))
    }

    @Test func opinionHasTheAuthorAndAClosingNote() {
        let page = render(story(.opinion))
        #expect(page.contains("class=\"article article-opinion\"") && page.contains("By Jane Doe"))
        #expect(page.contains("views of their authors"))
        #expect(!page.contains("In brief"))
        #expect(!page.contains("More detail."))               // the extended summary is only for news and background
    }

    @Test func newsAndBackgroundHaveNoOpinionNote() {
        #expect(!render(story(.news)).contains("views of their authors"))
        #expect(!render(story(.background)).contains("views of their authors"))
    }

    @Test func bylineAndPhotoCreditsAreOptional() {
        let bare = render(story(.news, author: nil, extended: nil))
        #expect(!bare.contains("By ") && !bare.contains("<figure"))

        let image = StoryImage(source: .endpoint(url: "/x.jpg"), altText: "Alt text", caption: "A caption", credit: "Photo: Someone")
        let withImage = render(story(.news, image: image))
        #expect(withImage.contains("src=\"/x.jpg\"") && withImage.contains("A caption") && withImage.contains("Photo: Someone"))
    }

    @Test func titleAndTextFromEditorsAreEscaped() {
        let page = render(story(.news, title: "<script>alert(1)</script> & more", author: "<b>Eve</b>"))
        #expect(!page.contains("<script>alert(1)"))
        #expect(page.contains("&lt;script&gt;alert(1)&lt;/script&gt; &amp; more"))
        #expect(page.contains("&lt;b&gt;Eve&lt;/b&gt;"))
    }

    @Test func moreInTheSectionLinksToOtherArticles() {
        let other = Story(category: .news, priority: .normal, title: "Other story", summary: "Other summary", slug: "other-story")
        let page = render(story(.news), related: [other])
        #expect(page.contains("More in News") && page.contains("href=\"/sections/news\""))
        #expect(page.contains("href=\"/articles/other-story\"") && page.contains("Other summary"))
        #expect(!render(story(.news)).contains("More in News"))
    }

    @Test func theSectionIsHighlightedInTheMasthead() {
        #expect(render(story(.opinion)).contains("nav-link active\">Opinion"))
    }
}

@Suite struct PublishedStoryTests {
    @Test func onlyPublishedStoriesCanBeRead() throws {
        let db = try PaperDatabase()
        let live = Story(category: .news, priority: .normal, title: "Live", summary: "s", slug: "live")
        let draft = Story(category: .news, priority: .normal, title: "Draft", summary: "s", slug: "draft")
        let inbox = Story(category: .news, priority: .normal, title: "Inbox", summary: "s", slug: "inbox")
        try db.save(live, body: "Live **body**"); try db.save(draft, body: ""); try db.save(inbox, body: "")
        try db.place(live.id, inIssue: "2026-11-19")
        try db.place(draft.id, inIssue: "2026-11-20")
        try db.publish(issue: "2026-11-19", mode: .prominent)

        let found = try #require(try db.publishedStory(slug: "live"))
        #expect(found.story.id == live.id && found.markdown == "Live **body**")
        #expect(try db.publishedStory(slug: "draft") == nil)
        #expect(try db.publishedStory(slug: "inbox") == nil)
        #expect(try db.publishedStory(slug: "nope") == nil)
    }

    @Test func aStoryStaysReadableWhileItIsInAnyPublishedIssue() throws {
        let db = try PaperDatabase()
        let s = Story(category: .opinion, priority: .normal, title: "T", summary: "s", slug: "t")
        try db.save(s, body: "")
        try db.place(s.id, inIssue: "2026-11-19"); try db.place(s.id, inIssue: "2026-11-20")
        try db.publish(issue: "2026-11-19", mode: .prominent)
        try db.remove(s.id, fromIssue: "2026-11-19")                  // still in the (draft) 20th only
        #expect(try db.publishedStory(slug: "t") == nil)
    }
}
