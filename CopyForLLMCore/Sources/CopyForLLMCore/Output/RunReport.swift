import Foundation

/// What happened during a copy run — feeds the notification/HUD and the Options stats bar.
public struct RunReport: Sendable {
    public var filesCopied: Int
    public var ignoredCount: Int
    public var skipped: [SkippedItem]
    public var skippedTotal: Int
    public var omittedByBudget: [String]
    public var totalChars: Int
    public var estimatedTokens: Int
    public var duration: TimeInterval

    public var wasTruncated: Bool { !omittedByBudget.isEmpty }

    public init(filesCopied: Int, ignoredCount: Int, skipped: [SkippedItem], skippedTotal: Int,
                omittedByBudget: [String], totalChars: Int, estimatedTokens: Int, duration: TimeInterval) {
        self.filesCopied = filesCopied
        self.ignoredCount = ignoredCount
        self.skipped = skipped
        self.skippedTotal = skippedTotal
        self.omittedByBudget = omittedByBudget
        self.totalChars = totalChars
        self.estimatedTokens = estimatedTokens
        self.duration = duration
    }

    /// "Copied 47 files (~85k tokens)" style summary for notifications.
    public var summaryLine: String {
        let noun = filesCopied == 1 ? "file" : "files"
        return "Copied \(filesCopied) \(noun) (~\(Self.abbreviate(estimatedTokens)) tokens)"
    }

    public var detailLine: String {
        var parts: [String] = []
        if skippedTotal > 0 { parts.append("\(skippedTotal) skipped") }
        if !omittedByBudget.isEmpty {
            parts.append("\(omittedByBudget.count) omitted by size limits — use Options… for control")
        }
        return parts.joined(separator: ", ")
    }

    static func abbreviate(_ n: Int) -> String {
        switch n {
        case ..<1000: "\(n)"
        case ..<1_000_000: String(format: "%.1fk", Double(n) / 1000).replacingOccurrences(of: ".0k", with: "k")
        default: String(format: "%.1fM", Double(n) / 1_000_000).replacingOccurrences(of: ".0M", with: "M")
        }
    }
}
