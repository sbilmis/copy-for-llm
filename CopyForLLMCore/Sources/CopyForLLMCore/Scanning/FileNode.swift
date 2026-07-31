import Foundation

/// A node in the post-filter tree of included items.
public struct FileNode: Sendable {
    public var name: String
    public var isDirectory: Bool
    public var children: [FileNode]

    public init(name: String, isDirectory: Bool, children: [FileNode] = []) {
        self.name = name
        self.isDirectory = isDirectory
        self.children = children
    }
}

/// A text file selected for content extraction.
public struct ScannedFile: Sendable {
    public let url: URL
    /// Path shown in headers/trees: relative to the selected root (prefixed with the
    /// root's name when several roots are selected).
    public let displayPath: String
    public let sizeBytes: Int64
    public let language: String
    /// How this file's text should be obtained.
    public let extraction: ExtractionKind

    public init(
        url: URL, displayPath: String, sizeBytes: Int64, language: String,
        extraction: ExtractionKind = .plainText
    ) {
        self.url = url
        self.displayPath = displayPath
        self.sizeBytes = sizeBytes
        self.language = language
        self.extraction = extraction
    }
}

public struct SkippedItem: Sendable, Codable {
    public let displayPath: String
    public let reason: SkipReason

    public init(displayPath: String, reason: SkipReason) {
        self.displayPath = displayPath
        self.reason = reason
    }
}

public struct ScanProgress: Sendable {
    public var scanned: Int
    public var included: Int
    public var ignored: Int
}

public struct ScanOutcome: Sendable {
    /// One tree per selected root, containing only included items.
    public var trees: [FileNode]
    /// Included text files in deterministic tree order.
    public var files: [ScannedFile]
    /// Non-ignore skips (binary, symlink, too large, unreadable), capped at `skipListCap`.
    public var skipped: [SkippedItem]
    public var skippedTotal: Int
    /// Items excluded by ignore/filter rules (directories counted once, not recursed).
    public var ignoredCount: Int
    /// Everything visited.
    public var scannedCount: Int
}
