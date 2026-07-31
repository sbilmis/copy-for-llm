import AppKit
import Foundation
import PDFKit
import Testing
@testable import CopyForLLMCore

@Suite struct ExtractionPlannerTests {

    @Test func pdfHonoursSetting() {
        var settings = ExtractionSettings()
        #expect(ExtractionPlanner.kind(forFileName: "a.pdf", settings: settings,
                                       directlySelected: false) == .pdf)
        settings.pdf = false
        #expect(ExtractionPlanner.kind(forFileName: "a.pdf", settings: settings,
                                       directlySelected: false) == nil)
    }

    @Test func ocrModeControlsImages() {
        var settings = ExtractionSettings(ocr: .off)
        #expect(ExtractionPlanner.kind(forFileName: "s.png", settings: settings,
                                       directlySelected: true) == nil)

        settings.ocr = .selectedOnly
        #expect(ExtractionPlanner.kind(forFileName: "s.png", settings: settings,
                                       directlySelected: true) == .imageOCR)
        // Found while walking a folder — skipped, so an assets dir stays fast.
        #expect(ExtractionPlanner.kind(forFileName: "s.png", settings: settings,
                                       directlySelected: false) == nil)

        settings.ocr = .always
        #expect(ExtractionPlanner.kind(forFileName: "s.png", settings: settings,
                                       directlySelected: false) == .imageOCR)
    }

    @Test func richDocumentsAndUnknowns() {
        let settings = ExtractionSettings()
        // .docx goes to the OOXML parser; .rtf/.odt to AppKit's reader.
        #expect(ExtractionPlanner.kind(forFileName: "r.docx", settings: settings,
                                       directlySelected: false) == .officeXML)
        #expect(ExtractionPlanner.kind(forFileName: "r.odt", settings: settings,
                                       directlySelected: false) == .richDocument)
        #expect(ExtractionPlanner.kind(forFileName: "m.swift", settings: settings,
                                       directlySelected: false) == nil)
        #expect(ExtractionPlanner.kind(forFileName: "a.zip", settings: settings,
                                       directlySelected: true) == nil)
    }

    @Test func disabledSettingsExtractNothing() {
        let settings = ExtractionSettings.disabled
        #expect(!settings.isEnabled)
        for name in ["a.pdf", "b.png", "c.docx"] {
            #expect(ExtractionPlanner.kind(forFileName: name, settings: settings,
                                           directlySelected: true) == nil)
        }
    }
}

@Suite struct RichExtractorTests {

    /// Writes a one-page PDF containing `text` as a real text layer.
    private func makePDF(at url: URL, text: String) throws {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
        ctx.beginPDFPage(nil)
        let attributed = NSAttributedString(
            string: text, attributes: [.font: NSFont.systemFont(ofSize: 24)])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: 50, y: 500, width: 500, height: 250), transform: nil)
        CTFrameDraw(CTFramesetterCreateFrame(framesetter, CFRange(), path, nil), ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        try data.write(to: url)
    }

    /// Renders `text` into a PNG so OCR has something to read.
    private func makeImage(at url: URL, text: String) throws {
        let size = NSSize(width: 600, height: 140)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSAttributedString(string: text, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 46), .foregroundColor: NSColor.black,
        ]).draw(at: NSPoint(x: 20, y: 45))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try png.write(to: url)
    }

    private func tempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func extractsPDFTextLayer() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("doc.pdf")
        try makePDF(at: url, text: "Quarterly results summary.")

        let text = try await RichExtractor.extract(
            url: url, kind: .pdf, settings: ExtractionSettings())
        #expect(text.contains("Quarterly results summary."))
        #expect(text.contains("--- page 1 ---"))
    }

    @Test func ocrsAnImage() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("shot.png")
        try makeImage(at: url, text: "INVOICE 4471")

        let text = try await RichExtractor.extract(
            url: url, kind: .imageOCR, settings: ExtractionSettings())
        #expect(text.contains("INVOICE"))
        #expect(text.contains("4471"))
    }

    @Test func readsRichDocument() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("note.rtf")
        try "{\\rtf1\\ansi Meeting notes from Tuesday.}".write(
            to: url, atomically: true, encoding: .utf8)

        let text = try await RichExtractor.extract(
            url: url, kind: .richDocument, settings: ExtractionSettings())
        #expect(text.contains("Meeting notes from Tuesday."))
    }

    @Test func blankImageReportsNoText() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("blank.png")
        try makeImage(at: url, text: " ")

        await #expect(throws: ExtractionError.self) {
            _ = try await RichExtractor.extract(
                url: url, kind: .imageOCR, settings: ExtractionSettings())
        }
    }

    @Test func pipelineExtractsSelectedPDF() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("report.pdf")
        try makePDF(at: url, text: "Extracted by the pipeline.")

        var request = CopyRequest(roots: [url], mode: .contents, format: .plain)
        request.extraction = ExtractionSettings()
        let output = try await CopyPipeline.run(request)
        #expect(output.text.contains("Extracted by the pipeline."))
        #expect(output.report.filesCopied == 1)
    }

    @Test func extractionOverridesDefaultIgnoreButNotUserExclude() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let project = dir.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try makePDF(at: project.appendingPathComponent("spec.pdf"), text: "Spec body text.")
        try "code".write(to: project.appendingPathComponent("a.swift"),
                         atomically: true, encoding: .utf8)

        // *.pdf is in the built-in defaults; enabling PDF extraction must override it.
        var options = ScanOptions(extraction: ExtractionSettings())
        var outcome = try FileScanner.scan(roots: [project], options: options)
        #expect(outcome.files.contains { $0.displayPath == "spec.pdf" })

        // An explicit user exclude still wins.
        options = ScanOptions(
            ignore: IgnoreConfiguration(excludeGlobs: ["*.pdf"]),
            extraction: ExtractionSettings()
        )
        outcome = try FileScanner.scan(roots: [project], options: options)
        #expect(!outcome.files.contains { $0.displayPath == "spec.pdf" })

        // With extraction off, the default rule applies again.
        outcome = try FileScanner.scan(roots: [project], options: ScanOptions())
        #expect(!outcome.files.contains { $0.displayPath == "spec.pdf" })
    }

    @Test func extractableFilesBypassTheTextByteBudget() {
        let pdf = ScannedFile(url: URL(fileURLWithPath: "/a.pdf"), displayPath: "a.pdf",
                              sizeBytes: 20_000_000, language: "", extraction: .pdf)
        let code = ScannedFile(url: URL(fileURLWithPath: "/b.swift"), displayPath: "b.swift",
                               sizeBytes: 500, language: "swift", extraction: .plainText)
        let selection = BudgetEnforcer.select(
            files: [pdf, code], limits: Limits(maxTotalBytes: 1_000_000))
        #expect(selection.selected.count == 2)
        #expect(selection.omitted.isEmpty)
    }
}
