import Compression
import Foundation

/// Minimal read-only ZIP archive reader.
///
/// Office files (.docx/.pptx/.xlsx) are ZIP containers, and Foundation exposes no
/// ZIP API. This reads the central directory and inflates individual entries, which
/// is all OOXML extraction needs — no writing, no encryption, no ZIP64.
enum ZIPReader {

    enum ZIPError: Error {
        case notAnArchive
        case entryNotFound
        case corrupt
    }

    struct Entry {
        let name: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    private static let centralDirectorySignature: UInt32 = 0x0201_4B50
    private static let localHeaderSignature: UInt32 = 0x0403_4B50

    /// Lists every entry in the archive.
    static func entries(in data: Data) throws -> [Entry] {
        guard let eocd = findEndOfCentralDirectory(in: data) else { throw ZIPError.notAnArchive }
        let count = Int(read16(data, eocd + 10))
        var offset = Int(read32(data, eocd + 16))

        var entries: [Entry] = []
        for _ in 0..<count {
            guard offset + 46 <= data.count,
                  read32(data, offset) == centralDirectorySignature else { throw ZIPError.corrupt }
            let method = read16(data, offset + 10)
            let compressed = Int(read32(data, offset + 20))
            let uncompressed = Int(read32(data, offset + 24))
            let nameLength = Int(read16(data, offset + 28))
            let extraLength = Int(read16(data, offset + 30))
            let commentLength = Int(read16(data, offset + 32))
            let localOffset = Int(read32(data, offset + 42))

            let nameStart = offset + 46
            guard nameStart + nameLength <= data.count else { throw ZIPError.corrupt }
            let name = String(
                decoding: data[nameStart..<(nameStart + nameLength)], as: UTF8.self)

            entries.append(Entry(
                name: name, compressionMethod: method,
                compressedSize: compressed, uncompressedSize: uncompressed,
                localHeaderOffset: localOffset
            ))
            offset = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }

    /// Returns the decompressed bytes of one entry.
    static func contents(of entry: Entry, in data: Data) throws -> Data {
        let header = entry.localHeaderOffset
        guard header + 30 <= data.count,
              read32(data, header) == localHeaderSignature else { throw ZIPError.corrupt }
        let nameLength = Int(read16(data, header + 26))
        let extraLength = Int(read16(data, header + 28))
        let start = header + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard end <= data.count else { throw ZIPError.corrupt }
        let payload = data[start..<end]

        switch entry.compressionMethod {
        case 0:
            return Data(payload)
        case 8:
            return try inflate(Data(payload), expectedSize: entry.uncompressedSize)
        default:
            throw ZIPError.corrupt
        }
    }

    /// Convenience: find an entry by exact name and return its contents.
    static func contents(ofEntryNamed name: String, in data: Data) throws -> Data {
        guard let entry = try entries(in: data).first(where: { $0.name == name }) else {
            throw ZIPError.entryNotFound
        }
        return try contents(of: entry, in: data)
    }

    /// ZIP stores raw DEFLATE, which matches COMPRESSION_ZLIB's raw mode.
    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        var result = Data(count: expectedSize)
        let written = result.withUnsafeMutableBytes { destination -> Int in
            guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress else {
                return 0
            }
            return data.withUnsafeBytes { source -> Int in
                guard let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(
                    destinationBase, expectedSize,
                    sourceBase, data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written > 0 else { throw ZIPError.corrupt }
        return result.prefix(written)
    }

    /// Scans backwards for the end-of-central-directory record, which may be
    /// followed by a variable-length comment.
    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let earliest = max(0, data.count - 22 - 65_535)
        var offset = data.count - 22
        while offset >= earliest {
            if read32(data, offset) == endOfCentralDirectorySignature { return offset }
            offset -= 1
        }
        return nil
    }

    // Little-endian reads relative to the data's own start index.
    private static func read16(_ data: Data, _ offset: Int) -> UInt16 {
        let base = data.startIndex + offset
        guard base + 2 <= data.endIndex else { return 0 }
        return UInt16(data[base]) | UInt16(data[base + 1]) << 8
    }

    private static func read32(_ data: Data, _ offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        guard base + 4 <= data.endIndex else { return 0 }
        return UInt32(data[base]) | UInt32(data[base + 1]) << 8
            | UInt32(data[base + 2]) << 16 | UInt32(data[base + 3]) << 24
    }
}
