import Foundation

/// Splits an upload into its YAML front matter and markdown body.
///
/// The file must start with a line containing only `---`; the front matter runs
/// until the next such line. Handles a UTF-8 BOM and Windows (CRLF) line endings.
enum FrontMatter {
    struct Parts {
        let yaml: String
        let body: String
    }

    enum SplitError: Error, CustomStringConvertible {
        case missingOpeningFence
        case missingClosingFence

        var description: String {
            switch self {
            case .missingOpeningFence:
                return "The file must start with a line containing only '---'."
            case .missingClosingFence:
                return "The front matter is not closed: add a line containing only '---' after the YAML."
            }
        }
    }

    static func split(_ text: String) throws -> Parts {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }

        let lines = normalized.components(separatedBy: "\n")
        guard let first = lines.first, isFence(first) else {
            throw SplitError.missingOpeningFence
        }
        guard let closing = lines.dropFirst().firstIndex(where: isFence) else {
            throw SplitError.missingClosingFence
        }

        let yaml = lines[1..<closing].joined(separator: "\n")
        let body = lines[(closing + 1)...].joined(separator: "\n")
        return Parts(yaml: yaml, body: body.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func isFence(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == "---"
    }
}
