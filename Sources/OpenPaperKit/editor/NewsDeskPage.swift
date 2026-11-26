import Foundation
import Elementary

/// The three folders of the news desk.
package enum DeskFolder: String, Sendable, CaseIterable {
    case desk, published, archive

    /// The folder an item with this status is in.
    package init(_ status: ItemStatus) {
        switch status {
        case .submitted: self = .desk
        case .filed: self = .published
        case .rejected: self = .archive
        }
    }

    var label: String {
        switch self {
        case .desk: "News desk"
        case .published: "Published"
        case .archive: "Archive"
        }
    }

    var emptyText: String {
        switch self {
        case .desk: "Nothing waiting. New submissions appear here."
        case .published: "Nothing is published or scheduled yet."
        case .archive: "The archive is empty."
        }
    }
}

/// `/editor`, laid out like a mail inbox. Left: the folders and the items in
/// the open one. Right: the selected item, ready to edit, publish or archive.
/// `/editor/items/{id}` and `/editor/uploads/{id}` are the same page with that
/// item selected.
package struct NewsDeskPage: HTMLDocument {
    package let folder: DeskFolder
    package let desk: [DeskEntry]
    package let published: [DeskEntry]
    package let archived: [DeskEntry]
    /// Uploaded files not saved yet; listed on the news desk.
    package let uploads: [StagedUpload]
    package let selected: DeskItem?
    /// True when the page picked the item itself, so a narrow screen should
    /// still show the list.
    package let autoSelected: Bool
    package let today: String
    /// What just happened, e.g. "“Title” was archived."
    package let notice: DeskNotice?
    package let uploadProblems: [String]

    package init(
        folder: DeskFolder = .desk,
        desk: [DeskEntry] = [],
        published: [DeskEntry] = [],
        archived: [DeskEntry] = [],
        uploads: [StagedUpload] = [],
        selected: DeskItem? = nil,
        autoSelected: Bool = false,
        today: String = EditorDates.today(),
        notice: DeskNotice? = nil,
        uploadProblems: [String] = []
    ) {
        self.folder = folder
        self.desk = desk
        self.published = published
        self.archived = archived
        self.uploads = uploads
        self.selected = selected
        self.autoSelected = autoSelected
        self.today = today
        self.notice = notice
        self.uploadProblems = uploadProblems
    }

    package var title: String { "Editor — \(folder.label)" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }   // raw: the CSS uses ">" selectors
    }

    private var entries: [DeskEntry] { items(in: folder) }

    private func items(in folder: DeskFolder) -> [DeskEntry] {
        switch folder {
        case .desk: desk
        case .published: published
        case .archive: archived
        }
    }

    private var shellClass: String {
        selected == nil || autoSelected ? "desk-shell show-list" : "desk-shell show-item"
    }

    package var body: some HTML {
        div(.class(shellClass)) {
            EditorBar()

            main(.class("desk")) {
                div(.class("desk-list")) {
                    nav(.class("desk-folders")) {
                        for option in DeskFolder.allCases {
                            a(.href(option == .desk ? "/editor" : "/editor?folder=\(option.rawValue)")) {
                                option.label
                                span(.class("desk-count")) { "\(items(in: option).count)" }
                            }
                            .attributes(.custom(name: "aria-current", value: "page"), when: option == folder)
                        }
                    }

                    if folder == .desk {
                        uploadBox
                    }

                    if entries.isEmpty && (folder != .desk || uploads.isEmpty) {
                        p(.class("empty desk-empty")) { folder.emptyText }
                    }

                    ul(.class("desk-rows")) {
                        if folder == .desk {
                            for upload in uploads {
                                li {
                                    DeskRow(
                                        href: "/editor/uploads/\(upload.id.uuidString)", from: "Upload",
                                        date: EditorDates.day(upload.createdAt), title: upload.filename,
                                        kind: upload.kind, state: "Not saved", isSelected: selected?.id == upload.id
                                    )
                                }
                            }
                        }
                        for entry in entries {
                            li {
                                DeskRow(
                                    href: "/editor/items/\(entry.id.uuidString)",
                                    from: entry.contributor?.name ?? entry.author ?? "Editor upload",
                                    date: entry.publishDate ?? EditorDates.day(entry.uploadedAt), title: entry.title,
                                    kind: entry.kind, state: DeskStatus.tag(for: entry, today: today),
                                    isSelected: selected?.id == entry.id
                                )
                            }
                        }
                    }
                }

                div(.class("desk-reading")) {
                    a(.href(folder == .desk ? "/editor" : "/editor?folder=\(folder.rawValue)"), .class("desk-back")) {
                        "← Back to the list"
                    }
                    if let notice {
                        p(.class("desk-notice"), .custom(name: "role", value: "status")) {
                            notice.text
                            if let link = notice.link {
                                " "
                                a(.href(link)) { "Open it" }
                            }
                        }
                    }
                    if let selected {
                        DeskItemView(item: selected, today: today)
                    } else {
                        p(.class("empty desk-placeholder")) { "Select an item on the left to read it." }
                    }
                }
            }
        }

        dialog(.id("preview"), .class("preview-dialog")) {
            div(.class("preview-dialog-bar")) {
                strong { "Preview" }
                button(.type(.button), .class("button"), .id("preview-close")) { "Close" }
            }
            div(.id("preview-holder")) {}
        }
        script { HTMLRaw(Self.deskScript) }
    }

    private var uploadBox: some HTML {
        details(.class("desk-upload")) {
            summary { "Upload a file" }
            if !uploadProblems.isEmpty {
                div(.class("problems")) {
                    p { "The file was not uploaded:" }
                    ul {
                        for problem in uploadProblems { li { problem } }
                    }
                }
            }
            form(.method(.post), .action("/editor/uploads"), .enctype(.multipartFormData)) {
                div(.class("field")) {
                    label(.for("kind")) { "Type" }
                    select(.id("kind"), .name("kind")) {
                        for kind in [ItemKind.story, .agendaPoint, .quotedItem, .advertisement] {
                            option(.value(kind.rawValue)) { kind.label }
                        }
                    }
                }
                div(.class("field")) {
                    label(.for("file")) { "Markdown file" }
                    input(.type(.file), .id("file"), .name("file"), .accept(".md,text/markdown,text/plain"), .required)
                }
                button(.type(.submit), .class("button primary")) { "Upload and review" }
            }
        }
        .attributes(.custom(name: "open", value: ""), when: !uploadProblems.isEmpty)
    }

    /// Opens the preview over the page, and warns before unsaved edits are lost.
    /// Without it the preview opens in a new window.
    private static let deskScript = """
    (function () {
      var current = document.querySelector('.desk-row[aria-current]');
      if (current) { current.scrollIntoView({ block: 'nearest' }); }

      var form = document.querySelector('form.desk-item');
      if (!form) { return; }
      var dialog = document.getElementById('preview');
      var holder = document.getElementById('preview-holder');
      var dirty = false;
      var leaving = false;

      form.addEventListener('input', function (event) {
        if (event.target.name !== 'publishDate' && event.target.name !== 'publishUntil') { dirty = true; }
      });
      form.addEventListener('submit', function (event) {
        var button = event.submitter;
        if (button && button.hasAttribute('data-preview')) {
          // A new frame each time, so previews don't pile up in the history.
          var frame = document.createElement('iframe');
          frame.name = 'preview-frame';
          frame.title = 'Preview';
          holder.replaceChildren(frame);
          dialog.showModal();
          return;
        }
        if (dirty && button && button.hasAttribute('data-discards')
            && !window.confirm('Your changes to this item are not saved. Continue without them?')) {
          event.preventDefault();
          return;
        }
        leaving = true;
      });
      window.addEventListener('beforeunload', function (event) {
        if (dirty && !leaving) { event.preventDefault(); }
      });
      document.getElementById('preview-close').addEventListener('click', function () { dialog.close(); });
      dialog.addEventListener('click', function (event) {
        if (event.target === dialog) { dialog.close(); }
      });
    })();
    """
}

/// One line of the list: who and when, the title, and what it is.
private struct DeskRow: HTML {
    let href: String
    let from: String
    /// "yyyy-MM-dd": the publish date, or the day it came in.
    let date: String
    let title: String
    let kind: ItemKind
    let state: String?
    let isSelected: Bool

    var body: some HTML {
        a(.href(href), .class("desk-row")) {
            span(.class("desk-row-top")) {
                span(.class("desk-row-from")) { from }
                span(.class("desk-row-date")) { EditorDates.shortDay(date) }
            }
            span(.class("desk-row-title")) { title }
            span(.class("desk-row-tags")) {
                span(.class("desk-tag")) { kind.label }
                if let state {
                    span(.class("desk-tag state")) { state }
                }
            }
        }
        .attributes(.custom(name: "aria-current", value: "true"), when: isSelected)
    }
}

/// The line shown after saving, publishing or archiving.
package struct DeskNotice: Sendable {
    package let text: String
    /// Set when the item it is about is no longer the one on screen.
    package let link: String?

    package init(text: String, link: String? = nil) {
        self.text = text
        self.link = link
    }
}

/// How an item's place in the paper is described.
package enum DeskStatus {
    /// A short label for the list; nil when the folder says enough.
    static func tag(for entry: DeskEntry, today: String) -> String? {
        guard entry.status == .filed, let first = entry.publishDate else { return nil }
        if first > today { return "Scheduled" }
        if let last = entry.publishUntil, last < today { return "Ended" }
        return nil
    }

    /// A sentence for the reading pane. `until` is set for advertisements.
    package static func sentence(
        _ status: ItemStatus, publishDate: String?, until: String?, today: String
    ) -> String {
        switch status {
        case .submitted: return "On the news desk. Not in the paper yet."
        case .rejected: return "Archived. It does not appear in the paper."
        case .filed:
            let first = publishDate ?? ""
            let days = EditorDates.run(from: first, until: until)
            if first > today { return "Scheduled for \(days)." }
            guard let until else { return "Published \(days)." }
            return until < today ? "Ran \(days)." : "Running \(days)."
        }
    }
}
