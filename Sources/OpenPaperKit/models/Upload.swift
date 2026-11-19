import Foundation
import Ink
import Yams

/// Reads a markdown upload.
///
/// The YAML front matter (between the two `---` lines) is decoded straight into
/// the model you ask for (`Story`, `AgendaPoint`, `QuotedItem` or `Advertisement`).
/// The text after it is converted from markdown to HTML.
///
///     let upload = try loadUpload(Story.self, from: fileURL)
///     upload.item   // the Story
///     upload.markdown // the body as written
///     upload.html   // the body as HTML
package func loadUpload<T: Decodable>(_ type: T.Type, from file: URL) throws -> (item: T, markdown: String, html: String) {
    let text = try String(contentsOf: file, encoding: .utf8)
    return try parseUpload(type, text: text, name: file.lastPathComponent)
}

/// Markdown to HTML, the same conversion uploads use.
package func markdownToHTML(_ markdown: String) -> String {
    MarkdownParser().html(from: markdown)
}

/// Same as `loadUpload`, for text that is already in memory (a web upload).
/// `name` is only used in error messages.
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

    // Every model needs an `id`; give new uploads one so editors don't have to.
    if !yaml.split(separator: "\n").contains(where: { $0.hasPrefix("id:") }) {
        yaml = "id: \(UUID().uuidString)\n" + yaml
    }

    let item = try YAMLDecoder().decode(T.self, from: yaml)
    let html = MarkdownParser().html(from: body)
    return (item, body, html)
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

    package init(kind: ItemKind, text: String, name: String) throws {
        switch kind {
        case .story:
            let upload = try parseUpload(Story.self, text: text, name: name)
            self = .story(upload.item, markdown: upload.markdown, html: upload.html)
        case .agendaPoint:
            self = .agendaPoint(try parseUpload(AgendaPoint.self, text: text, name: name).item)
        case .quotedItem:
            self = .quotedItem(try parseUpload(QuotedItem.self, text: text, name: name).item)
        case .advertisement:
            self = .advertisement(try parseUpload(Advertisement.self, text: text, name: name).item)
        }
    }

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
