import Foundation
import Elementary

package enum ImageSource: Codable, Sendable {
    case endpoint(url: String)
    case blob(data: Data, mimeType: String) // e.g., "image/jpeg" or "image/webp"

    package var htmlSrc: String {
        switch self {
        case .endpoint(let url):
            return url
        case .blob(let data, let mimeType):
            return "data:\(mimeType);base64,\(data.base64EncodedString())"
        }
    }
}

package struct StoryImage: Codable, Sendable {
    package let source: ImageSource
    package let altText: String
    package let caption: String?
    package let credit: String? // e.g., "Jane Doe for The Daily Chronicle"
}
