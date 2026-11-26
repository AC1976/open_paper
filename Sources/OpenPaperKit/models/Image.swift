import Foundation

/// Where an advertisement's image comes from. Uploaded images are stored as
/// files and end up as an address on this site (`/images/{id}`); `blob` only
/// carries the bytes from a form to the database.
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

/// A picture as a page shows it. Stories do not contain their picture; pages
/// receive it alongside.
package struct Picture: Sendable, Equatable {
    package let src: String
    package let altText: String
    package let caption: String?
    package let credit: String? // e.g., "Jane Doe for The Daily Chronicle"

    package init(src: String, altText: String, caption: String? = nil, credit: String? = nil) {
        self.src = src
        self.altText = altText
        self.caption = caption
        self.credit = credit
    }
}

/// The words that go with a picture.
package struct PictureText: Sendable, Equatable {
    package let altText: String
    package let caption: String?
    package let credit: String?

    package init(altText: String, caption: String? = nil, credit: String? = nil) {
        self.altText = altText
        self.caption = caption
        self.credit = credit
    }
}

/// An uploaded picture that is not stored yet. Its bytes have been through `ImageCleaner`.
package struct NewPicture: Sendable, Equatable {
    package let data: Data
    package let mimeType: String
    package let text: PictureText

    package init(data: Data, mimeType: String, text: PictureText) {
        self.data = data
        self.mimeType = mimeType
        self.text = text
    }
}

/// What a submitted form wants done with a story's picture.
package enum PictureChange: Sendable, Equatable {
    case unchanged
    case remove
    case replace(NewPicture)
    case describe(PictureText)   // same picture, new words

    /// How the picture would look after saving, for a preview that is not saved.
    package func applied(to current: Picture?) -> Picture? {
        switch self {
        case .unchanged: current
        case .remove: nil
        case .replace(let new):
            Picture(src: ImageSource.blob(data: new.data, mimeType: new.mimeType).htmlSrc,
                    altText: new.text.altText, caption: new.text.caption, credit: new.text.credit)
        case .describe(let text):
            current.map { Picture(src: $0.src, altText: text.altText, caption: text.caption, credit: text.credit) }
        }
    }
}
