import Foundation

/// The smallest picture files the image check accepts. `marker` makes one
/// picture's bytes differ from another's.
enum TestImage {
    static func pngChunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
        let n = data.count
        return [UInt8(n >> 24 & 255), UInt8(n >> 16 & 255), UInt8(n >> 8 & 255), UInt8(n & 255)]
            + Array(type.utf8) + data + [0, 0, 0, 0]        // the checksum is not checked
    }

    static let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    static func png(_ marker: UInt8 = 0) -> Data {
        Data(pngHeader + pngChunk("IHDR", [UInt8](repeating: 0, count: 13)) + pngChunk("IDAT", [marker]) + pngChunk("IEND", []))
    }

    static func jpeg(_ marker: UInt8 = 0) -> Data {
        Data([0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x02, marker, 0xFF, 0xD9])
    }
}
