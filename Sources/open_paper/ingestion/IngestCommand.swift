import Foundation

/// `swift run open_paper ingest [folder-or-file ...]`
///
/// Runs every `.md` file (except README.md) through the `Ingestor` and prints
/// what the editor's review card would show. Nothing is stored.
enum IngestCommand {
    /// Returns `true` when every file was accepted.
    static func run(paths: [String]) -> Bool {
        let fileManager = FileManager.default
        var files: [(root: URL, file: URL)] = []
        var allFound = true

        for path in paths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                print("Not found: \(path)")
                allFound = false
                continue
            }
            if isDirectory.boolValue {
                let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil)
                while let file = enumerator?.nextObject() as? URL {
                    if file.pathExtension.lowercased() == "md",
                       file.lastPathComponent.lowercased() != "readme.md" {
                        files.append((url, file.standardizedFileURL))
                    }
                }
            } else {
                files.append((url.deletingLastPathComponent(), url))
            }
        }
        files.sort { $0.file.path < $1.file.path }

        let ingestor = Ingestor()
        var accepted = 0
        var warningCount = 0

        for (root, file) in files {
            let name = relativePath(of: file, in: root)
            guard let data = fileManager.contents(atPath: file.path),
                  let text = String(data: data, encoding: .utf8) else {
                print("REJECTED  \(name)")
                print("          error    could not be read as UTF-8 text\n")
                continue
            }

            let result = ingestor.ingest(text: text, fileName: name)
            if result.isAccepted { accepted += 1 }
            warningCount += result.warnings.count
            print(report(result, root: root, folder: file.deletingLastPathComponent()))
        }

        let rejected = files.count - accepted
        print("\(files.count) files: \(accepted) accepted, \(rejected) rejected, \(warningCount) warnings")
        return allFound && rejected == 0
    }

    // MARK: - Report

    private static func report(_ result: IngestionResult, root: URL, folder: URL) -> String {
        let indent = "          "
        var lines = ["\(result.isAccepted ? "ACCEPTED" : "REJECTED")  \(result.fileName)"]

        if let item = result.item {
            lines.append(indent + summary(of: item) + " · status \(result.status.rawValue)")
            if let image = imageRequest(of: item) {
                lines.append(indent + describe(image, root: root, folder: folder))
            }
            if let html = result.bodyHTML {
                lines.append(indent + "body: \(html.count) characters of HTML")
            }
        }

        for issue in result.issues {
            lines.append(indent + issue.description)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func summary(of item: IngestedItem) -> String {
        switch item {
        case .story(let story, _):
            return "story · \(story.category.rawValue) · priority \(label(story.priority)) · \"\(story.title)\""
        case .agenda(let point):
            return "agenda · \"\(point.subject)\" · \(point.place)"
        case .quoted(let quote):
            return "quoted · \(quote.speaker)"
        case .advertisement(let ad):
            return "advertisement · \(ad.sponsorName) · priority \(label(ad.priority))"
        }
    }

    private static func imageRequest(of item: IngestedItem) -> ImageRequest? {
        switch item {
        case .story(_, let image): return image
        case .advertisement(let ad): return ad.image
        case .agenda, .quoted: return nil
        }
    }

    private static func describe(_ image: ImageRequest, root: URL, folder: URL) -> String {
        let storage = image.storage.rawValue
        if let file = image.file {
            // In the server this is matched against the files uploaded alongside;
            // here we look next to the .md file and in the folder that was passed in.
            let found = [folder, root].contains {
                FileManager.default.fileExists(atPath: $0.appendingPathComponent(file).path)
            }
            return "image: \(storage) \(file) · " + (found ? "file found" : "waiting for image upload")
        }
        if image.needsDownload, let url = image.url {
            return "image: \(storage) \(url) · server will download it"
        }
        return "image: link \(image.url ?? "") · no upload needed"
    }

    private static func label(_ priority: StoryPriority) -> String {
        priority == .high ? "2 (high)" : "1 (normal)"
    }

    private static func relativePath(of file: URL, in root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return file.path.hasPrefix(rootPath) ? String(file.path.dropFirst(rootPath.count)) : file.lastPathComponent
    }
}
