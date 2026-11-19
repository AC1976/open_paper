import Foundation
import Elementary

enum ImageSource: Codable, Sendable {
    case endpoint(url: String)
    case blob(data: Data, mimeType: String) // e.g., "image/jpeg" or "image/webp"

    var htmlSrc: String {
        switch self {
        case .endpoint(let url):
            return url
        case .blob(let data, let mimeType):
            return "data:\(mimeType);base64,\(data.base64EncodedString())"
        }
    }
}

struct StoryImage: Codable, Sendable {
    let source: ImageSource
    let altText: String
    let caption: String?
    let credit: String? // e.g., "Jane Doe for The Daily Chronicle"
}
