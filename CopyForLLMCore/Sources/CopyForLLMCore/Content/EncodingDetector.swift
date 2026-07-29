import Foundation

public enum DecodedText: Sendable {
    case text(String, String.Encoding)
    case binary
}

public enum EncodingDetector {

    static let sniffLength = 8192

    /// True if the data looks binary (contains a null byte in the first 8 KB).
    public static func looksBinary(_ data: Data) -> Bool {
        data.prefix(sniffLength).contains(0)
    }

    /// BOM detection → strict UTF-8 → Latin-1 fallback. `.binary` for null-byte content.
    public static func decode(_ data: Data) -> DecodedText {
        if data.isEmpty { return .text("", .utf8) }

        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            if let s = String(data: data.dropFirst(3), encoding: .utf8) { return .text(s, .utf8) }
            return .binary
        }
        if data.starts(with: [0xFF, 0xFE]) {
            if let s = String(data: data, encoding: .utf16LittleEndian) { return .text(s, .utf16LittleEndian) }
            return .binary
        }
        if data.starts(with: [0xFE, 0xFF]) {
            if let s = String(data: data, encoding: .utf16BigEndian) { return .text(s, .utf16BigEndian) }
            return .binary
        }

        if looksBinary(data) { return .binary }

        if let s = String(data: data, encoding: .utf8) { return .text(s, .utf8) }
        if let s = String(data: data, encoding: .isoLatin1) { return .text(s, .isoLatin1) }
        return .binary
    }
}
