import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import OpenPaperKit

/// Real pictures made with ImageIO. Small ones come out exactly as the upload
/// path stores them. `marker` makes one picture's bytes differ from another's.
enum TestImage {
    static let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    static func png(_ marker: UInt8 = 0) -> Data { ImageCleaner.clean(make(.png, 8, 4, marker: marker))!.data }

    static func jpeg(_ marker: UInt8 = 0) -> Data { ImageCleaner.clean(make(.jpeg, 8, 4, marker: marker))!.data }

    /// A picture of any size. `noise` makes it hard to compress, like a photograph.
    static func make(
        _ type: UTType, _ width: Int, _ height: Int, marker: UInt8 = 0,
        transparent: Bool = false, noise: Bool = false, orientation: Int = 1
    ) -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: (transparent ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue
        )!
        context.setFillColor(CGColor(red: Double(marker) / 255, green: 0.4, blue: 0.7, alpha: transparent ? 0.5 : 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if noise {
            var generator = SystemRandomNumberGenerator()
            let pixels = context.data!.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
            for i in 0..<(context.bytesPerRow * height) { pixels[i] = UInt8.random(in: 0...255, using: &generator) }
        }
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        precondition(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
