import Foundation
import Elementary

extension ItemKind {
    package var label: String {
        switch self {
        case .story: "Story"
        case .agendaPoint: "Agenda point"
        case .quotedItem: "Quote"
        case .advertisement: "Advertisement"
        }
    }
}

/// Styles and the top bar shared by the editor pages.
package struct EditorBar: HTML {
    package init() {}

    package var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Editor" }
            nav(.class("editor-nav")) {
                a(.href("/editor"), .class("editor-link")) { "Inbox" }
                a(.href("/editor/issues"), .class("editor-link")) { "Issues" }
                form(.method(.post), .action("/editor/logout"), .enctype(.multipartFormData), .class("editor-logout")) {
                    button(.type(.submit), .class("editor-link")) { "Log out" }
                }
            }
        }
    }
}

/// `/editor`: upload one item, see what is waiting for review, and the inbox
/// of saved items that are not in an issue yet.
package struct EditorHomePage: HTMLDocument {
    package let inbox: [InboxEntry]
    package let waiting: [StagedUpload]
    package let problems: [String]

    package init(inbox: [InboxEntry], waiting: [StagedUpload], problems: [String] = []) {
        self.inbox = inbox
        self.waiting = waiting
        self.problems = problems
    }

    package var title: String { "Editor — Inbox" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        EditorBar()

        main(.class("editor-main")) {
            h1 { "Upload" }

            if !problems.isEmpty {
                div(.class("problems")) {
                    p { "The file was not uploaded:" }
                    ul {
                        for problem in problems { li { problem } }
                    }
                }
            }

            form(.method(.post), .action("/editor/uploads"), .enctype(.multipartFormData), .class("upload-form")) {
                div(.class("field")) {
                    label(.for("kind")) { "Type" }
                    select(.id("kind"), .name("kind")) {
                        for kind in [ItemKind.story, .agendaPoint, .quotedItem, .advertisement] {
                            option(.value(kind.rawValue)) { kind.label }
                        }
                    }
                }
                div(.class("field grow")) {
                    label(.for("file")) { "Markdown file" }
                    input(.type(.file), .id("file"), .name("file"), .accept(".md,text/markdown,text/plain"), .required)
                }
                button(.type(.submit), .class("button primary")) { "Upload and review" }
            }

            if !waiting.isEmpty {
                h2 { "Waiting for review" }
                table(.class("item-table")) {
                    thead {
                        tr { th { "File" }; th { "Type" }; th { "Uploaded" } }
                    }
                    tbody {
                        for upload in waiting {
                            tr {
                                td { a(.href("/editor/uploads/\(upload.id.uuidString)")) { upload.filename } }
                                td { upload.kind.label }
                                td { EditorDates.display(upload.createdAt) }
                            }
                        }
                    }
                }
            }

            h2 { "Inbox" }
            if inbox.isEmpty {
                p(.class("empty")) { "Nothing here yet. Saved items that are not in an issue appear in this list." }
            } else {
                table(.class("item-table")) {
                    thead {
                        tr { th { "Title" }; th { "Type" }; th { "Uploaded" } }
                    }
                    tbody {
                        for entry in inbox {
                            tr {
                                td { entry.title }
                                td { entry.kind.label }
                                td { EditorDates.display(entry.uploadedAt) }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// How a story looks on the front page and on its own page.
package struct StoryPreview: HTML {
    package let story: Story
    package let bodyHTML: String

    package var body: some HTML {
        h2(.class("preview-label")) { "Front page" }
        div(.class("preview-frame broadsheet mode-prominent")) {
            StoryCard(placed: PlacedStory(story: story, columnSpan: 2, imageStyle: .standardLead))
        }

        h2(.class("preview-label")) { "Article page" }
        div(.class("preview-frame article-body")) {
            h1(.class("headline")) { story.title }
            if let author = story.author {
                p(.class("byline")) { "By \(author)" }
            }
            HTMLRaw(bodyHTML)
        }
    }
}
