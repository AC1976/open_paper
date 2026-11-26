import Foundation
import Ink
import Yams

/// Markdown to HTML. Every article body goes through here, and the result is
/// cleaned: raw HTML a writer typed is shown as text, not run.
package func markdownToHTML(_ markdown: String) -> String {
    HTMLSanitizer.clean(MarkdownParser().html(from: markdown))
}

/// Reads a markdown upload.
///
/// The YAML front matter (between the two `---` lines) is decoded straight into
/// the model you ask for (`Story`, `AgendaPoint`, `QuotedItem` or `Advertisement`).
/// The text after it is converted from markdown to HTML. `name` is only used in
/// error messages.
///
///     let upload = try parseUpload(Story.self, text: fileText, name: "story.md")
///     upload.item     // the Story
///     upload.markdown // the body as written
///     upload.html     // the body as HTML
package func parseUpload<T: Decodable>(_ type: T.Type, text rawText: String, name: String) throws -> (item: T, markdown: String, html: String) {
    let text = rawText.replacingOccurrences(of: "\r\n", with: "\n")

    // Split: "---\n<yaml>\n---\n<body>"
    guard text.hasPrefix("---\n"),
          let end = text.range(of: "\n---", range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex)
    else {
        throw UploadError.noFrontMatter(name)
    }
    var yaml = String(text[text.index(text.startIndex, offsetBy: 4)..<end.lowerBound])
    let body = String(text[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

    // Models need an `id`; give files without one a new id.
    if !yaml.split(separator: "\n").contains(where: { $0.hasPrefix("id:") }) {
        yaml = "id: \(UUID().uuidString)\n" + yaml
    }

    let item = try YAMLDecoder().decode(T.self, from: yaml)
    return (item, body, markdownToHTML(body))
}

package enum UploadError: Error, CustomStringConvertible {
    case noFrontMatter(String)

    package var description: String {
        switch self {
        case .noFrontMatter(let name):
            return "\(name) must start with a '---' line, then the YAML, then another '---' line."
        }
    }
}

/// An upload parsed into the model its kind asks for.
package enum ParsedUpload: Sendable {
    case story(Story, markdown: String, html: String)
    case agendaPoint(AgendaPoint)
    case quotedItem(QuotedItem)
    case advertisement(Advertisement)

    package var id: UUID {
        switch self {
        case .story(let story, _, _): story.id
        case .agendaPoint(let item): item.id
        case .quotedItem(let item): item.id
        case .advertisement(let item): item.id
        }
    }

    package var kind: ItemKind {
        switch self {
        case .story: .story
        case .agendaPoint: .agendaPoint
        case .quotedItem: .quotedItem
        case .advertisement: .advertisement
        }
    }
}
