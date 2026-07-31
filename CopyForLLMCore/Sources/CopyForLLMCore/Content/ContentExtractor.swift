import Foundation

/// How a file's text should be obtained.
public enum ExtractionKind: String, Sendable, Codable {
    /// Read the bytes and decode them (source code, markdown, config…).
    case plainText
    /// PDF text layer, with OCR for pages that have none.
    case pdf
    /// Optical character recognition on an image.
    case imageOCR
    /// Word/RTF/OpenDocument/HTML via AppKit's document readers.
    case richDocument
}

public enum OCRMode: String, Codable, Sendable, CaseIterable {
    /// Never OCR images.
    case off
    /// Only OCR images the user selected directly in Finder, not ones found
    /// while walking a folder — otherwise an assets directory makes every copy slow.
    case selectedOnly
    /// OCR every image encountered, including inside folders.
    case always

    public var displayName: String {
        switch self {
        case .off: "Never"
        case .selectedOnly: "Only files I select directly"
        case .always: "Always, including inside folders"
        }
    }
}

public struct ExtractionSettings: Codable, Sendable, Equatable {
    /// Extract text from PDFs.
    public var pdf: Bool
    /// Extract text from Word, RTF, OpenDocument and HTML files.
    public var richDocuments: Bool
    public var ocr: OCRMode
    /// OCR accuracy. Fast is roughly an order of magnitude quicker and fine for
    /// screenshots of text; accurate handles photographs and awkward layouts.
    public var accurateOCR: Bool
    /// Run OCR on PDF pages that have no text layer (i.e. scans).
    public var ocrScannedPDFs: Bool
    /// Size cap for files we extract from. Separate from the plain-text cap
    /// because a 20 MB PDF can still yield only a few pages of text, while the
    /// text cap exists to stop one giant source file eating the whole budget.
    public var maxSourceBytes: Int64?

    public init(
        pdf: Bool = true,
        richDocuments: Bool = true,
        ocr: OCRMode = .selectedOnly,
        accurateOCR: Bool = true,
        ocrScannedPDFs: Bool = true,
        maxSourceBytes: Int64? = 50_000_000
    ) {
        self.maxSourceBytes = maxSourceBytes
        self.pdf = pdf
        self.richDocuments = richDocuments
        self.ocr = ocr
        self.accurateOCR = accurateOCR
        self.ocrScannedPDFs = ocrScannedPDFs
    }

    public static let disabled = ExtractionSettings(
        pdf: false, richDocuments: false, ocr: .off,
        accurateOCR: true, ocrScannedPDFs: false
    )

    public var isEnabled: Bool {
        pdf || richDocuments || ocr != .off
    }
}

public enum ExtractionError: Error, LocalizedError {
    case unreadable
    case noTextFound

    public var errorDescription: String? {
        switch self {
        case .unreadable: "The file could not be read."
        case .noTextFound: "No text was found in the file."
        }
    }
}

/// Decides which extractor applies to a file, based on its extension and the
/// user's settings. Extension-based on purpose: it runs during the scan, before
/// any file is opened.
public enum ExtractionPlanner {

    static let pdfExtensions: Set<String> = ["pdf"]

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp",
    ]

    static let richDocumentExtensions: Set<String> = [
        "docx", "doc", "rtf", "rtfd", "odt", "webarchive",
    ]

    /// The extraction kind for `fileName`, or nil if the file isn't one we can
    /// extract beyond plain text.
    /// - Parameter directlySelected: true when the user picked this exact file in
    ///   Finder, as opposed to it being discovered inside a selected folder.
    public static func kind(
        forFileName fileName: String,
        settings: ExtractionSettings,
        directlySelected: Bool
    ) -> ExtractionKind? {
        let ext = (fileName as NSString).pathExtension.lowercased()
        if pdfExtensions.contains(ext) {
            return settings.pdf ? .pdf : nil
        }
        if imageExtensions.contains(ext) {
            switch settings.ocr {
            case .off: return nil
            case .selectedOnly: return directlySelected ? .imageOCR : nil
            case .always: return .imageOCR
            }
        }
        if richDocumentExtensions.contains(ext) {
            return settings.richDocuments ? .richDocument : nil
        }
        return nil
    }
}
