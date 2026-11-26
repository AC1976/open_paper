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
                a(.href("/editor"), .class("editor-link")) { "News desk" }
                a(.href("/editor/issues"), .class("editor-link")) { "Editions" }
                form(.method(.post), .action("/editor/logout"), .enctype(.multipartFormData), .class("editor-logout")) {
                    button(.type(.submit), .class("editor-link")) { "Log out" }
                }
            }
        }
    }
}

/// `/editor`, the news desk: submissions waiting to be filed, then what is
/// already filed or rejected. Click a title to edit, file or reject it.
package struct EditorHomePage: HTMLDocument {
    package let desk: [DeskEntry]
    package let waiting: [StagedUpload]
    package let filed: [DeskEntry]
    package let rejected: [DeskEntry]
    package let problems: [String]

    package init(
        desk: [DeskEntry], waiting: [StagedUpload], filed: [DeskEntry] = [],
        rejected: [DeskEntry] = [], problems: [String] = []
    ) {
        self.desk = desk
        self.waiting = waiting
        self.filed = filed
        self.rejected = rejected
        self.problems = problems
    }

    package var title: String { "Editor — News desk" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        EditorBar()

        main(.class("editor-main")) {
            h1 { "News desk (\(desk.count))" }
            if desk.isEmpty {
                p(.class("empty")) { "Nothing waiting. New submissions appear here." }
            } else {
                DeskTable(entries: desk, dateHeading: "Received")
            }

            h2 { "Upload" }
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
                h2 { "Uploads waiting for review" }
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

            if !filed.isEmpty {
                h2 { "Filed (\(filed.count))" }
                DeskTable(entries: filed, dateHeading: "Publish date")
            }

            if !rejected.isEmpty {
                details {
                    summary { "Rejected (\(rejected.count))" }
                    DeskTable(entries: rejected, dateHeading: "Received")
                }
            }
        }
    }
}

/// Items as a table; filed items show their publish date, others when they came in.
private struct DeskTable: HTML {
    let entries: [DeskEntry]
    let dateHeading: String

    var body: some HTML {
        table(.class("item-table")) {
            thead {
                tr { th { "Title" }; th { "Type" }; th { "Contributor" }; th { dateHeading } }
            }
            tbody {
                for entry in entries {
                    tr {
                        td { a(.href("/editor/items/\(entry.id.uuidString)")) { entry.title } }
                        td { entry.kind.label }
                        td {
                            if let contributor = entry.contributor {
                                contributor.name
                                a(.href("mailto:\(contributor.email)"), .class("contributor-email")) { contributor.email }
                            } else {
                                entry.author ?? "—"
                            }
                        }
                        td { entry.publishDate.map(EditorDates.longDay) ?? EditorDates.display(entry.uploadedAt) }
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
