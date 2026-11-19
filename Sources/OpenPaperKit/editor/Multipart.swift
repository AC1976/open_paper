import Foundation

/// A small `multipart/form-data` reader for the editor forms.
///
/// The whole body is already in memory (the server caps its size), so this
/// just splits on the boundary. It handles text fields and file parts.
package struct MultipartForm: Sendable {
    package struct Part: Sendable {
        package let name: String
        package let filename: String?
        package let contentType: String?
        package let data: Data

        package var text: String { String(decoding: data, as: UTF8.self) }
    }

    package let parts: [Part]

    package enum ParseError: Error, CustomStringConvertible {
        case noBoundary
        case malformed

        package var description: String {
            switch self {
            case .noBoundary: "The request is not a multipart form."
            case .malformed: "The form data could not be read."
            }
        }
    }

    /// The boundary from a `Content-Type: multipart/form-data; boundary=...` header.
    package static func boundary(fromContentType header: String?) -> String? {
        guard let header, header.lowercased().hasPrefix("multipart/form-data") else { return nil }
        for piece in header.split(separator: ";").dropFirst() {
            let pair = piece.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if pair.count == 2, pair[0].lowercased() == "boundary" {
                return pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return nil
    }

    package init(body: Data, contentType: String?) throws {
        guard let boundary = Self.boundary(fromContentType: contentType) else { throw ParseError.noBoundary }
        try self.init(body: body, boundary: boundary)
    }

    package init(body: Data, boundary: String) throws {
        // Every delimiter is preceded by CRLF, including the first one once we add it.
        let delimiter = Data("\r\n--\(boundary)".utf8)
        let data = Data("\r\n".utf8) + body

        guard var cursor = data.range(of: delimiter)?.upperBound else { throw ParseError.malformed }
        var parts: [Part] = []

        while true {
            // After a delimiter: "--" ends the form, CRLF starts a part.
            let after = data[cursor...]
            if after.starts(with: Data("--".utf8)) { break }
            guard after.starts(with: Data("\r\n".utf8)) else { throw ParseError.malformed }
            let partStart = cursor + 2

            guard let next = data.range(of: delimiter, in: partStart..<data.endIndex) else { throw ParseError.malformed }
            let partData = data[partStart..<next.lowerBound]

            guard let headerEnd = partData.range(of: Data("\r\n\r\n".utf8)) else {
                // A part with no headers is not something a browser sends.
                throw ParseError.malformed
            }
            let headerText = String(decoding: partData[partData.startIndex..<headerEnd.lowerBound], as: UTF8.self)
            let content = Data(partData[headerEnd.upperBound...])

            var name: String?
            var filename: String?
            var contentType: String?
            for line in headerText.components(separatedBy: "\r\n") {
                let lower = line.lowercased()
                if lower.hasPrefix("content-disposition:") {
                    name = Self.parameter("name", in: line)
                    filename = Self.parameter("filename", in: line)
                } else if lower.hasPrefix("content-type:") {
                    contentType = line.dropFirst("content-type:".count).trimmingCharacters(in: .whitespaces)
                }
            }
            if let name {
                parts.append(Part(name: name, filename: filename, contentType: contentType, data: content))
            }
            cursor = next.upperBound
        }
        self.parts = parts
    }

    /// The text of a field, trimmed; nil when missing or empty.
    package func text(_ name: String) -> String? {
        guard let part = parts.first(where: { $0.name == name && $0.filename == nil }) else { return nil }
        let value = part.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// The text of a field exactly as sent (for markdown bodies); nil when missing.
    package func rawText(_ name: String) -> String? {
        parts.first(where: { $0.name == name && $0.filename == nil })?.text
    }

    /// Every value sent under one name (a group of checkboxes).
    package func values(_ name: String) -> [String] {
        parts.filter { $0.name == name && $0.filename == nil }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// A chosen file; nil when no file was picked (browsers send an empty part).
    package func file(_ name: String) -> Part? {
        parts.first { $0.name == name && !($0.filename ?? "").isEmpty && !$0.data.isEmpty }
    }

    private static func parameter(_ key: String, in header: String) -> String? {
        // name="value" — match on a word boundary so `name` does not hit `filename`.
        guard let range = header.range(of: "[ ;]\(key)=\"", options: .regularExpression) else { return nil }
        let rest = header[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }
}
