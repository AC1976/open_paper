import Foundation

/// Checks that an upload really is a JPEG, PNG or WebP (by its bytes, not its
/// name) and removes metadata: location, camera details, comments and anything
/// appended after the picture. The pixels are not re-encoded. A JPEG keeps its
/// orientation, so phone photos stay upright.
package enum ImageCleaner {
    package static func clean(_ data: Data) -> (data: Data, mimeType: String)? {
        let bytes = [UInt8](data)
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return jpeg(bytes).map { (Data($0), "image/jpeg") } }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return png(bytes).map { (Data($0), "image/png") } }
        if bytes.count >= 12, Array(bytes[0..<4]) == Array("RIFF".utf8), Array(bytes[8..<12]) == Array("WEBP".utf8) {
            return webp(bytes).map { (Data($0), "image/webp") }
        }
        return nil
    }

    // MARK: JPEG

    private static func jpeg(_ bytes: [UInt8]) -> [UInt8]? {
        var kept: [UInt8] = []
        var orientation: UInt16?
        var i = 2
        var sawScan = false

        while i + 1 < bytes.count {
            guard bytes[i] == 0xFF else { return nil }
            let marker = bytes[i + 1]
            if marker == 0xFF { i += 1; continue }                      // fill byte
            if marker == 0xD9 {                                         // end of image
                guard sawScan else { return nil }
                var result: [UInt8] = [0xFF, 0xD8]
                if let orientation { result += orientationSegment(orientation) }
                return result + kept + [0xFF, 0xD9]
            }
            if marker == 0x01 || (0xD0...0xD7).contains(marker) { kept += [0xFF, marker]; i += 2; continue }

            guard i + 3 < bytes.count else { return nil }
            let length = Int(bytes[i + 2]) << 8 | Int(bytes[i + 3])
            guard length >= 2, i + 2 + length <= bytes.count else { return nil }
            let segment = Array(bytes[i..<(i + 2 + length)])
            let payload = segment.dropFirst(4)
            i += 2 + length

            switch marker {
            case 0xE1:
                if orientation == nil { orientation = exifOrientation(Array(payload)) }
            case 0xE0, 0xEE:                                            // JFIF, Adobe colour
                kept += segment
            case 0xE2 where payload.starts(with: Array("ICC_PROFILE\0".utf8)):
                kept += segment
            case 0xE2...0xEF, 0xFE:                                     // other metadata, comments
                break
            case 0xDA:                                                  // scan: copy up to the next marker
                sawScan = true
                kept += segment
                let start = i
                while i + 1 < bytes.count {
                    if bytes[i] == 0xFF, bytes[i + 1] != 0x00, !(0xD0...0xD7).contains(bytes[i + 1]) { break }
                    i += 1
                }
                kept += bytes[start..<i]
            default:
                kept += segment
            }
        }
        return nil   // no end marker: cut off or damaged
    }

    /// The orientation tag from an EXIF block, if it asks for any turning.
    private static func exifOrientation(_ payload: [UInt8]) -> UInt16? {
        guard payload.starts(with: Array("Exif\0\0".utf8)) else { return nil }
        let t = Array(payload.dropFirst(6))
        guard t.count >= 8 else { return nil }
        let little = t[0] == 0x49
        func u16(_ o: Int) -> Int { little ? Int(t[o]) | Int(t[o + 1]) << 8 : Int(t[o]) << 8 | Int(t[o + 1]) }
        func u32(_ o: Int) -> Int { little ? u16(o) | u16(o + 2) << 16 : u16(o) << 16 | u16(o + 2) }
        let directory = u32(4)
        guard directory >= 8, directory + 2 <= t.count else { return nil }
        for entry in 0..<u16(directory) {
            let offset = directory + 2 + entry * 12
            guard offset + 12 <= t.count else { return nil }
            if u16(offset) == 0x0112 {
                let value = u16(offset + 8)
                return (2...8).contains(value) ? UInt16(value) : nil
            }
        }
        return nil
    }

    /// An EXIF block that holds the orientation and nothing else.
    private static func orientationSegment(_ value: UInt16) -> [UInt8] {
        let tiff: [UInt8] = [
            0x4D, 0x4D, 0x00, 0x2A, 0, 0, 0, 8,                 // big-endian header
            0x00, 0x01,                                         // one entry
            0x01, 0x12, 0x00, 0x03, 0, 0, 0, 1,                 // orientation, SHORT, count 1
            UInt8(value >> 8), UInt8(value & 0xFF), 0, 0,
            0, 0, 0, 0,                                         // no further directory
        ]
        let payload = Array("Exif\0\0".utf8) + tiff
        let length = payload.count + 2
        return [0xFF, 0xE1, UInt8(length >> 8), UInt8(length & 0xFF)] + payload
    }

    // MARK: PNG

    private static let pngChunks: Set<String> = [
        "IHDR", "PLTE", "IDAT", "IEND", "tRNS", "gAMA", "cHRM", "sRGB", "iCCP",
        "sBIT", "bKGD", "pHYs", "acTL", "fcTL", "fdAT", "cICP",
    ]

    private static func png(_ bytes: [UInt8]) -> [UInt8]? {
        var result = Array(bytes[0..<8])
        var i = 8
        var sawData = false
        while i + 12 <= bytes.count {
            let length = bytes[i..<(i + 4)].reduce(0) { $0 << 8 | Int($1) }
            guard length <= bytes.count - i - 12 else { return nil }
            let type = String(decoding: bytes[(i + 4)..<(i + 8)], as: UTF8.self)
            let chunk = bytes[i..<(i + 12 + length)]
            if i == 8, type != "IHDR" { return nil }
            if pngChunks.contains(type) { result += chunk }
            if type == "IDAT" { sawData = true }
            if type == "IEND" { return sawData ? result : nil }
            i += 12 + length
        }
        return nil
    }

    // MARK: WebP

    private static func webp(_ bytes: [UInt8]) -> [UInt8]? {
        let declared = Int(bytes[4]) | Int(bytes[5]) << 8 | Int(bytes[6]) << 16 | Int(bytes[7]) << 24
        let end = declared + 8
        guard declared >= 4, end <= bytes.count else { return nil }

        var chunks: [UInt8] = []
        var i = 12
        var sawPicture = false
        while i + 8 <= end {
            let type = String(decoding: bytes[i..<(i + 4)], as: UTF8.self)
            let length = Int(bytes[i + 4]) | Int(bytes[i + 5]) << 8 | Int(bytes[i + 6]) << 16 | Int(bytes[i + 7]) << 24
            let padded = length + (length & 1)
            guard i + 8 + length <= end else { return nil }
            var chunk = Array(bytes[i..<min(i + 8 + padded, end)])
            if chunk.count < 8 + padded { chunk.append(0) }

            switch type {
            case "VP8X":
                guard length >= 10 else { return nil }
                chunk[8] &= ~UInt8(0x08 | 0x04)                         // no EXIF, no XMP
                chunks += chunk
            case "VP8 ", "VP8L", "ANMF":
                sawPicture = true
                chunks += chunk
            case "ALPH", "ANIM", "ICCP":
                chunks += chunk
            default:
                break
            }
            i += 8 + padded
        }
        guard sawPicture else { return nil }
        let size = chunks.count + 4
        let header = Array("RIFF".utf8) + (0..<4).map { UInt8((size >> ($0 * 8)) & 0xFF) } + Array("WEBP".utf8)
        return header + chunks
    }
}
