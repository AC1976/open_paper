import Foundation
import Ink
import Yams

/// Turns one uploaded markdown file into a checked item, or a list of problems.
///
/// Nothing is stored here: the result is what the editor's review card shows
/// before they confirm and the item goes into the database.
struct Ingestor {
    var now: Date = Date()
    var timeZone: TimeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .current

    func ingest(text: String, fileName: String) -> IngestionResult {
        let validator = UploadValidator(now: now, timeZone: timeZone)

        func rejected(_ type: UploadType? = nil) -> IngestionResult {
            IngestionResult(
                fileName: fileName, type: type, item: nil, status: .draft,
                issues: validator.issues.all, bodyHTML: nil
            )
        }

        // 1. Front matter and body
        let parts: FrontMatter.Parts
        do {
            parts = try FrontMatter.split(text)
        } catch {
            validator.issues.error("", "\(error)")
            return rejected()
        }
        guard !parts.yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validator.issues.error("", "The front matter is empty.")
            return rejected()
        }

        // 2. Raw YAML, used to spot unknown (often misspelled) keys
        let raw: [String: Any]
        do {
            guard let mapping = try Yams.load(yaml: parts.yaml) as? [AnyHashable: Any] else {
                validator.issues.error("", "The front matter must be a list of `key: value` lines.")
                return rejected()
            }
            raw = Self.stringKeys(mapping)
        } catch {
            validator.issues.error("", "The YAML could not be read: \(error)")
            return rejected()
        }

        // 3. Envelope
        guard let envelope = decode(UploadEnvelope.self, from: parts.yaml, validator) else {
            return rejected()
        }
        let type = validator.choice(envelope.type, "type", as: UploadType.self, required: true)
        if let version = validator.text(envelope.schemaVersion, "schemaVersion", required: true),
           version != "1" {
            validator.issues.error("schemaVersion", "must be 1; got '\(version)'")
        }
        let requestedStatus = validator.choice(envelope.status, "status", as: UploadStatus.self) ?? .draft

        var id = UUID()
        if let idText = validator.text(envelope.id, "id") {
            if let parsed = UUID(uuidString: idText) {
                id = parsed
            } else {
                validator.issues.error("id", "must be a UUID such as 3F2504E0-4F89-11D3-9A0C-0305E82C3301; got '\(idText)'")
            }
        }

        guard let type else { return rejected() }

        // 4. Unknown keys
        Self.checkKeys(raw, allowed: UploadEnvelope.keys.union(Self.keys(for: type)), prefix: "", validator)
        if let image = raw["image"] as? [AnyHashable: Any] {
            Self.checkKeys(Self.stringKeys(image), allowed: ImageUpload.keys, prefix: "image.", validator)
        }

        // 5. The item itself
        var item: IngestedItem?
        var bodyHTML: String?

        switch type {
        case .story:
            if let upload = decode(StoryUpload.self, from: parts.yaml, validator) {
                item = validator.story(upload, id: id, body: parts.body)
            }
            if !parts.body.isEmpty {
                bodyHTML = MarkdownParser().html(from: parts.body)
            }
        case .agenda:
            if let upload = decode(AgendaUpload.self, from: parts.yaml, validator) {
                item = validator.agenda(upload, id: id)
            }
        case .quoted:
            if let upload = decode(QuotedUpload.self, from: parts.yaml, validator) {
                item = validator.quoted(upload, id: id)
            }
        case .advertisement:
            if let upload = decode(AdvertisementUpload.self, from: parts.yaml, validator) {
                item = validator.advertisement(upload, id: id)
            }
        }

        if type != .story, !Self.withoutComments(parts.body).isEmpty {
            validator.issues.warning("body", "is ignored for \(type.rawValue) uploads")
        }

        // 6. Status: anything held keeps the item in draft
        var status = requestedStatus
        if status == .ready, validator.issues.isHeld {
            status = .draft
            validator.issues.warning("status", "lowered to draft until the 'held as draft' warnings are fixed")
        }

        let hasErrors = validator.issues.errorCount > 0
        return IngestionResult(
            fileName: fileName,
            type: type,
            item: hasErrors ? nil : item,
            status: status,
            issues: validator.issues.all,
            bodyHTML: bodyHTML
        )
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from yaml: String, _ validator: UploadValidator) -> T? {
        do {
            return try YAMLDecoder().decode(T.self, from: yaml)
        } catch let DecodingError.typeMismatch(_, context) {
            validator.issues.error(Self.path(context.codingPath), "has the wrong shape (expected a single value, not a list or block)")
        } catch let DecodingError.valueNotFound(_, context) {
            validator.issues.error(Self.path(context.codingPath), "has no value")
        } catch let DecodingError.dataCorrupted(context) {
            validator.issues.error(Self.path(context.codingPath), context.debugDescription)
        } catch {
            validator.issues.error("", "The front matter could not be read: \(error)")
        }
        return nil
    }

    private static func keys(for type: UploadType) -> Set<String> {
        switch type {
        case .story: return StoryUpload.keys
        case .agenda: return AgendaUpload.keys
        case .quoted: return QuotedUpload.keys
        case .advertisement: return AdvertisementUpload.keys
        }
    }

    private static func checkKeys(_ raw: [String: Any], allowed: Set<String>, prefix: String, _ validator: UploadValidator) {
        for key in raw.keys.sorted() where !allowed.contains(key) {
            if let match = allowed.first(where: { $0.lowercased() == key.lowercased() }) {
                validator.issues.warning(prefix + key, "unknown field is ignored; did you mean '\(match)'?")
            } else {
                validator.issues.warning(prefix + key, "unknown field is ignored")
            }
        }
    }

    private static func stringKeys(_ mapping: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in mapping {
            result[(key.base as? String) ?? "\(key.base)"] = value
        }
        return result
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
    }

    /// The body with `<!-- … -->` comments removed, for checking non-story bodies.
    private static func withoutComments(_ text: String) -> String {
        var result = text
        while let start = result.range(of: "<!--") {
            guard let end = result.range(of: "-->", range: start.upperBound..<result.endIndex) else {
                result.removeSubrange(start.lowerBound..<result.endIndex)
                break
            }
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
