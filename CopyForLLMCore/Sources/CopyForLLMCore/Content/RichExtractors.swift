#if canImport(AppKit)
import AppKit
import PDFKit
import Vision

/// Text extraction for formats that aren't plain text. All of it runs on-device
/// with system frameworks — no network, no API keys, nothing to install.
public enum RichExtractor {

    /// Extracts text according to `kind`. Throws `ExtractionError` if nothing usable
    /// comes out, so callers can report the file as skipped rather than emit a blank.
    public static func extract(
        url: URL, kind: ExtractionKind, settings: ExtractionSettings
    ) async throws -> String {
        switch kind {
        case .plainText:
            guard let data = try? Data(contentsOf: url) else { throw ExtractionError.unreadable }
            guard case .text(let text, _) = EncodingDetector.decode(data) else {
                throw ExtractionError.unreadable
            }
            return text
        case .pdf:
            return try await pdfText(url: url, settings: settings)
        case .imageOCR:
            return try await imageText(url: url, settings: settings)
        case .richDocument:
            return try richDocumentText(url: url)
        }
    }

    // MARK: PDF

    static func pdfText(url: URL, settings: ExtractionSettings) async throws -> String {
        guard let document = PDFDocument(url: url) else { throw ExtractionError.unreadable }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            let layer = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !layer.isEmpty {
                pages.append(layer)
            } else if settings.ocrScannedPDFs {
                // A scanned page: rasterise and OCR it.
                if let text = try? await ocr(cgImage: render(page: page), settings: settings),
                   !text.isEmpty {
                    pages.append(text)
                }
            }
        }
        let combined = pages.enumerated()
            .map { "--- page \($0.offset + 1) ---\n\($0.element)" }
            .joined(separator: "\n\n")
        guard !combined.isEmpty else { throw ExtractionError.noTextFound }
        return combined
    }

    /// Renders a PDF page at 2× for legible OCR without exploding memory.
    private static func render(page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    // MARK: Images

    static func imageText(url: URL, settings: ExtractionSettings) async throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ExtractionError.unreadable
        }
        let text = try await ocr(cgImage: image, settings: settings)
        guard !text.isEmpty else { throw ExtractionError.noTextFound }
        return text
    }

    static func ocr(cgImage: CGImage?, settings: ExtractionSettings) async throws -> String {
        guard let cgImage else { throw ExtractionError.unreadable }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = settings.accurateOCR ? .accurate : .fast
        request.usesLanguageCorrection = settings.accurateOCR
        // Recognise whatever the system supports rather than assuming English.
        request.recognitionLanguages =
            (try? VNRecognizeTextRequest.supportedRecognitionLanguages(
                for: request.recognitionLevel, revision: request.revision
            )) ?? ["en-US"]

        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        let observations = request.results ?? []
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    // MARK: Word / RTF / OpenDocument / HTML

    static func richDocumentText(url: URL) throws -> String {
        guard let attributed = try? NSAttributedString(
            url: url, options: [:], documentAttributes: nil
        ) else {
            throw ExtractionError.unreadable
        }
        let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ExtractionError.noTextFound }
        return text
    }
}
#endif
