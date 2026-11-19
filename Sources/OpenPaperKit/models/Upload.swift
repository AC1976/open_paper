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
        .replacingOccurrences(of: "\r\n", with: "\n")

    // Split: "---\n<yaml>\n---\n<body>"
    guard text.hasPrefix("---\n"),
          let end = text.range(of: "\n---", range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex)
    else {
        throw UploadError.noFrontMatter(file.lastPathComponent)
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
