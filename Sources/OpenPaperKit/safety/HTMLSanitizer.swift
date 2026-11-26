import Foundation

/// Cleans the HTML made from a writer's markdown. Markdown passes raw HTML
/// through, so the result is rebuilt from an allowlist:
///
/// - only plain formatting tags survive, and without any attributes;
/// - a link keeps its `href`, if that is http(s), mailto, `#…` or a path on
///   this site;
/// - every other `<` becomes text, so nothing typed can run in a reader's browser.
///
/// Images in the article text are dropped: pictures must be uploaded, not
/// loaded from other servers.
package enum HTMLSanitizer {
    private static let allowed: Set<String> = [
        "p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "blockquote",
        "strong", "em", "b", "i", "del", "s", "code", "pre", "br", "hr", "a",
        "table", "thead", "tbody", "tr", "th", "td", "sup", "sub",
    ]
    private static let empty: Set<String> = ["br", "hr"]

    package static func clean(_ html: String) -> String {
        var output = ""
        var open: [String] = []
        var rest = Substring(html)

        while let start = rest.firstIndex(of: "<") {
            output += text(rest[..<start])
            rest = rest[start...]

            guard let tag = Tag(rest) else {
                output += "&lt;"
                rest = rest.dropFirst()
                continue
            }
            rest = rest[tag.end...]

            if tag.name == "img" { continue }
            guard allowed.contains(tag.name) else {
                output += text("<") + text(tag.source.dropFirst())     // shown as typed
                continue
            }

            if tag.closing {
                // Only close what is open, closing anything left open inside it.
                guard let index = open.lastIndex(of: tag.name) else { continue }
                while open.count > index { output += "</\(open.removeLast())>" }
            } else if empty.contains(tag.name) {
                output += "<\(tag.name)>"
            } else if tag.name == "a" {
                guard !open.contains("a"), let href = safeLink(tag.attribute("href")) else { continue }
                output += "<a href=\"\(escapeAttribute(href))\" rel=\"nofollow noopener\">"
                open.append("a")
            } else {
                output += "<\(tag.name)>"
                open.append(tag.name)
            }
        }

        output += text(rest)
        while let name = open.popLast() { output += "</\(name)>" }
        return output
    }

    /// The link if it is safe to follow, otherwise nil.
    static func safeLink(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let link = decode(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        // Control characters and spaces can hide a scheme from a naive check.
        guard !link.isEmpty, !link.unicodeScalars.contains(where: { $0.value <= 0x20 || $0.value == 0x7F || $0 == "\\" })
        else { return nil }
        let lower = link.lowercased()
        if ["https://", "http://", "mailto:"].contains(where: lower.hasPrefix) || link.hasPrefix("#") { return link }
        if link.hasPrefix("/"), !link.hasPrefix("//") { return link }
        return nil
    }

    /// Text between tags: `<` and `>` are escaped, existing entities are kept.
    private static func text(_ value: some StringProtocol) -> String {
        String(value).replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func decode(_ value: String) -> String {
        value.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func escapeAttribute(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// One `<name …>` or `</name>` at the start of the text.
    private struct Tag {
        let name: String
        let closing: Bool
        let source: Substring
        let end: Substring.Index

        init?(_ text: Substring) {
            var index = text.index(after: text.startIndex)
            let closing = index < text.endIndex && text[index] == "/"
            if closing { index = text.index(after: index) }

            let nameStart = index
            while index < text.endIndex, text[index].isASCII, text[index].isLetter || text[index].isNumber {
                index = text.index(after: index)
            }
            guard index > nameStart, text[nameStart].isLetter else { return nil }
            let name = text[nameStart..<index].lowercased()
            guard index < text.endIndex, text[index] == ">" || text[index] == "/" || text[index].isWhitespace else { return nil }

            // Find the closing ">", skipping any inside quoted attribute values.
            var quote: Character?
            while index < text.endIndex {
                let character = text[index]
                if let open = quote {
                    if character == open { quote = nil }
                } else if character == "\"" || character == "'" {
                    quote = character
                } else if character == ">" {
                    self.name = name
                    self.closing = closing
                    self.end = text.index(after: index)
                    self.source = text[text.startIndex..<self.end]
                    return
                } else if character == "<" {
                    return nil
                }
                index = text.index(after: index)
            }
            return nil
        }

        func attribute(_ wanted: String) -> String? {
            let pattern = "\\s\(wanted)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')"
            let string = String(source)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string))
            else { return nil }
            for group in 1...2 {
                if let range = Range(match.range(at: group), in: string) { return String(string[range]) }
            }
            return nil
        }
    }
}
