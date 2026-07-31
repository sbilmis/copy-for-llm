import AppKit
import Foundation
import Testing
@testable import CopyForLLMCore

/// Builds store-only (uncompressed) ZIP archives so tests can construct synthetic
/// .pptx/.xlsx fixtures without external tooling.
enum ZIPWriter {

    static func archive(_ files: [(name: String, data: Data)]) -> Data {
        var output = Data()
        var directory = Data()
        var offset = 0

        for file in files {
            let nameBytes = Data(file.name.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)

            var local = Data()
            local.append(le32(0x0403_4B50))
            local.append(le16(20))            // version needed
            local.append(le16(0))             // flags
            local.append(le16(0))             // method: stored
            local.append(le16(0))             // mod time
            local.append(le16(0))             // mod date
            local.append(le32(crc))
            local.append(le32(size))          // compressed
            local.append(le32(size))          // uncompressed
            local.append(le16(UInt16(nameBytes.count)))
            local.append(le16(0))             // extra length
            local.append(nameBytes)
            local.append(file.data)

            var central = Data()
            central.append(le32(0x0201_4B50))
            central.append(le16(20))          // version made by
            central.append(le16(20))          // version needed
            central.append(le16(0))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le32(crc))
            central.append(le32(size))
            central.append(le32(size))
            central.append(le16(UInt16(nameBytes.count)))
            central.append(le16(0))           // extra
            central.append(le16(0))           // comment
            central.append(le16(0))           // disk number
            central.append(le16(0))           // internal attrs
            central.append(le32(0))           // external attrs
            central.append(le32(UInt32(offset)))
            central.append(nameBytes)

            output.append(local)
            directory.append(central)
            offset += local.count
        }

        var eocd = Data()
        eocd.append(le32(0x0605_4B50))
        eocd.append(le16(0))
        eocd.append(le16(0))
        eocd.append(le16(UInt16(files.count)))
        eocd.append(le16(UInt16(files.count)))
        eocd.append(le32(UInt32(directory.count)))
        eocd.append(le32(UInt32(offset)))
        eocd.append(le16(0))

        output.append(directory)
        output.append(eocd)
        return output
    }

    private static func le16(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)])
    }

    private static func le32(_ value: UInt32) -> Data {
        Data([
            UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF),
        ])
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

@Suite struct ZIPReaderTests {

    @Test func readsStoredEntries() throws {
        let archive = ZIPWriter.archive([
            (name: "a.txt", data: Data("first entry".utf8)),
            (name: "nested/b.xml", data: Data("<x>second</x>".utf8)),
        ])
        let entries = try ZIPReader.entries(in: archive)
        #expect(entries.map(\.name) == ["a.txt", "nested/b.xml"])

        let second = try ZIPReader.contents(ofEntryNamed: "nested/b.xml", in: archive)
        #expect(String(decoding: second, as: UTF8.self) == "<x>second</x>")
    }

    @Test func readsDeflatedEntriesFromARealOfficeFile() throws {
        // NSAttributedString writes a genuine .docx, i.e. a DEFLATE-compressed ZIP.
        let attributed = NSAttributedString(string: String(repeating: "compressible ", count: 200))
        let docx = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        let entries = try ZIPReader.entries(in: docx)
        #expect(entries.contains { $0.name == "word/document.xml" })
        #expect(entries.contains { $0.compressionMethod == 8 })  // proves DEFLATE path

        let xml = try ZIPReader.contents(ofEntryNamed: "word/document.xml", in: docx)
        #expect(String(decoding: xml, as: UTF8.self).contains("compressible"))
    }

    @Test func rejectsNonArchives() {
        #expect(throws: (any Error).self) {
            _ = try ZIPReader.entries(in: Data("not a zip at all".utf8))
        }
    }

    @Test func missingEntryThrows() throws {
        let archive = ZIPWriter.archive([(name: "a.txt", data: Data("x".utf8))])
        #expect(throws: (any Error).self) {
            _ = try ZIPReader.contents(ofEntryNamed: "absent.xml", in: archive)
        }
    }
}

@Suite struct OOXMLExtractorTests {

    @Test func extractsWordText() throws {
        let attributed = NSAttributedString(string: "First paragraph.\nSecond paragraph.")
        let docx = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        let text = try OOXMLExtractor.docxText(data: docx)
        #expect(text.contains("First paragraph."))
        #expect(text.contains("Second paragraph."))
    }

    @Test func extractsSlidesInOrder() throws {
        func slide(_ lines: [String]) -> Data {
            let body = lines.map { "<a:p><a:r><a:t>\($0)</a:t></a:r></a:p>" }.joined()
            return Data("""
            <?xml version="1.0"?>
            <p:sld xmlns:p="p" xmlns:a="a"><p:cSld><p:spTree>\(body)</p:spTree></p:cSld></p:sld>
            """.utf8)
        }
        // Deliberately out of order, and slide10 present to catch string sorting.
        let pptx = ZIPWriter.archive([
            (name: "ppt/slides/slide2.xml", data: slide(["Second slide title"])),
            (name: "ppt/slides/slide10.xml", data: slide(["Tenth slide"])),
            (name: "ppt/slides/slide1.xml", data: slide(["Agenda", "Introduction"])),
        ])

        let text = try OOXMLExtractor.pptxText(data: pptx)
        let first = try #require(text.range(of: "Agenda"))
        let second = try #require(text.range(of: "Second slide title"))
        let tenth = try #require(text.range(of: "Tenth slide"))
        #expect(first.lowerBound < second.lowerBound)
        #expect(second.lowerBound < tenth.lowerBound)  // numeric, not lexicographic
        #expect(text.contains("--- slide 1 ---"))
        #expect(text.contains("Introduction"))
    }

    @Test func extractsSpreadsheetWithSharedStrings() throws {
        let sharedStrings = Data("""
        <?xml version="1.0"?>
        <sst><si><t>Region</t></si><si><t>Revenue</t></si><si><t>EMEA</t></si></sst>
        """.utf8)
        let sheet = Data("""
        <?xml version="1.0"?>
        <worksheet><sheetData>
          <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
          <row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2"><v>1250</v></c></row>
        </sheetData></worksheet>
        """.utf8)
        let xlsx = ZIPWriter.archive([
            (name: "xl/sharedStrings.xml", data: sharedStrings),
            (name: "xl/worksheets/sheet1.xml", data: sheet),
        ])

        let text = try OOXMLExtractor.xlsxText(data: xlsx)
        #expect(text.contains("Region\tRevenue"))
        #expect(text.contains("EMEA\t1250"))
    }

    @Test func emptyDocumentReportsNoText() throws {
        let pptx = ZIPWriter.archive([
            (name: "ppt/slides/slide1.xml",
             data: Data("<?xml version=\"1.0\"?><p:sld xmlns:p=\"p\"/>".utf8)),
        ])
        #expect(throws: ExtractionError.self) {
            _ = try OOXMLExtractor.pptxText(data: pptx)
        }
    }

    @Test func plannerRoutesOfficeFormats() {
        let settings = ExtractionSettings()
        for name in ["deck.pptx", "book.xlsx", "memo.docx"] {
            #expect(ExtractionPlanner.kind(forFileName: name, settings: settings,
                                           directlySelected: false) == .officeXML)
        }
        #expect(ExtractionPlanner.kind(forFileName: "old.rtf", settings: settings,
                                       directlySelected: false) == .richDocument)
    }

    @Test func pipelineCopiesAPresentation() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ooxml-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let slide = Data("""
        <?xml version="1.0"?>
        <p:sld xmlns:p="p" xmlns:a="a"><a:p><a:r><a:t>Roadmap 2027</a:t></a:r></a:p></p:sld>
        """.utf8)
        let url = dir.appendingPathComponent("deck.pptx")
        try ZIPWriter.archive([(name: "ppt/slides/slide1.xml", data: slide)]).write(to: url)

        var request = CopyRequest(roots: [url], mode: .contents, format: .plain)
        request.extraction = ExtractionSettings()
        let output = try await CopyPipeline.run(request)
        #expect(output.text.contains("Roadmap 2027"))
    }
}
