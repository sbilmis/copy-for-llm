import Foundation

public struct Limits: Codable, Sendable, Hashable {
    public var maxFiles: Int?
    public var maxTotalChars: Int?
    public var maxTotalBytes: Int64?
    public var maxFileBytes: Int64?

    public init(
        maxFiles: Int? = nil,
        maxTotalChars: Int? = nil,
        maxTotalBytes: Int64? = nil,
        maxFileBytes: Int64? = nil
    ) {
        self.maxFiles = maxFiles
        self.maxTotalChars = maxTotalChars
        self.maxTotalBytes = maxTotalBytes
        self.maxFileBytes = maxFileBytes
    }

    public static let standard = Limits(
        maxFiles: 1000,
        maxTotalChars: 4_000_000,
        maxTotalBytes: 10_000_000,
        maxFileBytes: 1_048_576
    )
}

public enum BudgetEnforcer {

    public struct Selection: Sendable {
        public var selected: [ScannedFile]
        public var omitted: [ScannedFile]
        public var hitLimit: Bool
    }

    /// Applies file-count and byte budgets in deterministic tree order. A file that
    /// would blow the byte budget is skipped, but smaller later files may still fit.
    /// (The character budget is applied post-decode, in the pipeline.)
    public static func select(files: [ScannedFile], limits: Limits) -> Selection {
        var selected: [ScannedFile] = []
        var omitted: [ScannedFile] = []
        var totalBytes: Int64 = 0
        var hitLimit = false

        for file in files {
            if let maxFiles = limits.maxFiles, selected.count >= maxFiles {
                omitted.append(file)
                hitLimit = true
                continue
            }
            // Only plain text is budgeted by source size. For an extracted file the
            // bytes on disk say nothing about how much text comes out — a 20 MB
            // scanned PDF may yield a page — so the character budget governs those.
            if file.extraction == .plainText {
                if let maxBytes = limits.maxTotalBytes, totalBytes + file.sizeBytes > maxBytes {
                    omitted.append(file)
                    hitLimit = true
                    continue
                }
                totalBytes += file.sizeBytes
            }
            selected.append(file)
        }
        return Selection(selected: selected, omitted: omitted, hitLimit: hitLimit)
    }
}

public protocol TokenEstimating: Sendable {
    func estimateTokens(chars: Int) -> Int
}

/// The chars-per-token heuristic (~4 for English/code). A real tokenizer can replace
/// this behind the same protocol later.
public struct CharacterHeuristicEstimator: TokenEstimating {
    public var charsPerToken: Double

    public init(charsPerToken: Double = 4) {
        self.charsPerToken = max(1, charsPerToken)
    }

    public func estimateTokens(chars: Int) -> Int {
        Int((Double(chars) / charsPerToken).rounded(.up))
    }
}
