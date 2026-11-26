import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Brings uploaded pictures down to what a screen can use (macOS ImageIO).
///
/// Only pixels matter on the web, not "ppi". The widest place a picture appears
/// is about 1000 points, and screens have two or more pixels per point, so
/// nothing wider than 2000 pixels is kept. Smaller versions are made for
/// smaller places, and the browser picks one.
///
/// Output is JPEG, or PNG when the picture has transparency (macOS cannot
/// write WebP). Re-encoding also drops all metadata and applies the rotation.
package enum ImageResizer {
    package static let maximumWidth = 2000
    package static let maximumHeight = 2400
    /// Larger pictures are refused: unpacking them could exhaust memory.
    package static let maximumPixels = 60_000_000
    package static let smallerWidths = [480, 960, 1600]
    /// An opaque picture heavier than this is re-encoded even if it is small enough.
    static let recompressAbove = 800_000
    static let quality = 0.82

    /// Size as displayed (rotation applied).
    package struct Info: Sendable, Equatable {
        package let width: Int
        package let height: Int
        let hasAlpha: Bool
    }

    package struct Rendered: Sendable {
        package let data: Data
        package let mimeType: String
        package let width: Int
        package let height: Int
    }

    /// Checks and prepares an upload: cleaned, readable, and no larger than
    /// needed. Nil if it is not a picture we accept. A picture that is already
    /// small enough keeps its original pixels.
    package static func accept(_ upload: Data) -> (data: Data, mimeType: String)? {
        guard let cleaned = ImageCleaner.clean(upload),
              let info = info(cleaned.data),
              info.width <= maximumPixels / max(info.height, 1),
              // Unpack a miniature to be sure the pixels can really be read.
              render(cleaned.data, width: 32) != nil
        else { return nil }

        let tooBig = info.width > maximumWidth || info.height > maximumHeight
        let tooHeavy = cleaned.data.count > recompressAbove && !info.hasAlpha
        guard tooBig || tooHeavy else { return cleaned }

        guard let smaller = render(cleaned.data, width: maximumWidth) else { return nil }
        // Re-encoding a picture that only seemed heavy must not make it heavier.
        if !tooBig, smaller.data.count >= cleaned.data.count { return cleaned }
        return (smaller.data, smaller.mimeType)
    }

    /// The size of a picture, read from its header.
    package static func info(_ data: Data) -> Info? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { return nil }
        let turned = (5...8).contains(properties[kCGImagePropertyOrientation] as? Int ?? 1)
        return Info(
            width: turned ? height : width, height: turned ? width : height,
            hasAlpha: properties[kCGImagePropertyHasAlpha] as? Bool ?? false
        )
    }

    /// The picture at most `width` pixels wide (and `maximumHeight` high),
    /// upright, never enlarged.
    package static func render(_ data: Data, width: Int) -> Rendered? {
        guard let info = info(data), let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let scale = min(1, Double(width) / Double(info.width), Double(maximumHeight) / Double(info.height))
        let longestSide = max(1, Int((Double(max(info.width, info.height)) * scale).rounded()))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let type: UTType = info.hasAlpha ? .png : .jpeg
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination), let clean = ImageCleaner.clean(output as Data) else { return nil }
        return Rendered(data: clean.data, mimeType: clean.mimeType, width: image.width, height: image.height)
    }
}
