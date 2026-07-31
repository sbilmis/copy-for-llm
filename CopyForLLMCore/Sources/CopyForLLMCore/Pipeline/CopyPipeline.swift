import Foundation

public enum OutputMode: String, Codable, Sendable, CaseIterable {
    /// Folders → tree + contents; only files selected → contents.
    case auto
    case contents
    case tree
    case treeAndContents
    case paths
}

public enum PathMode: String, Codable, Sendable, CaseIterable {
    case absolute
    case relative
    case nameOnly
}

public struct CopyRequest: Sendable {
    public var roots: [URL]
    public var mode: OutputMode
    public var format: OutputFormat
    public var pathMode: PathMode
    public var template: String?
    public var ignore: IgnoreConfiguration
    public var limits: Limits
    public var extraTextExtensions: Set<String>
    public var charsPerToken: Double
    public var extraction: ExtractionSettings

    public init(
        roots: [URL],
        mode: OutputMode = .auto,
        format: OutputFormat = .markdown,
        pathMode: PathMode = .absolute,
        template: String? = nil,
        ignore: IgnoreConfiguration = IgnoreConfiguration(),
        limits: Limits = .standard,
        extraTextExtensions: Set<String> = [],
        charsPerToken: Double = 4,
        extraction: ExtractionSettings = .disabled
    ) {
        self.extraction = extraction
        self.roots = roots
        self.mode = mode
        self.format = format
        self.pathMode = pathMode
        self.template = template
        self.ignore = ignore
        self.limits = limits
        self.extraTextExtensions = extraTextExtensions
        self.charsPerToken = charsPerToken
    }
}

public struct GeneratedOutput: Sendable {
    public var text: String
    public var report: RunReport

    public init(text: String, report: RunReport) {
        self.text = text
        self.report = report
    }
}

public enum CopyPipelineError: Error, LocalizedError {
    case emptySelection
    case nothingToCopy(RunReport)

    public var errorDescription: String? {
        switch self {
        case .emptySelection:
            "Nothing was selected."
        case .nothingToCopy:
            "No text files to copy in the selection (binary or ignored files only)."
        }
    }
}

/// scan → budget → read+decode → format. The single entry point shared by
/// the Quick Actions, the Options window, and the CLI.
public enum CopyPipeline {

    public static func run(
        _ request: CopyRequest,
        progress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async throws -> GeneratedOutput {
        guard !request.roots.isEmpty else { throw CopyPipelineError.emptySelection }
        let start = ContinuousClock.now

        if request.mode == .paths {
            return pathsOutput(request, start: start)
        }

        let mode = resolveMode(request)
        let options = ScanOptions(
            ignore: request.ignore,
            maxFileBytes: request.limits.maxFileBytes,
            extraTextExtensions: request.extraTextExtensions,
            extraction: request.extraction
        )
        let outcome = try FileScanner.scan(roots: request.roots, options: options, progress: progress)

        let wantsContents = mode != .tree
        var renderFiles: [RenderFile] = []
        var omitted: [String] = []
        var decodeSkipped: [SkippedItem] = []

        if wantsContents {
            let selection = BudgetEnforcer.select(files: outcome.files, limits: request.limits)
            omitted = selection.omitted.map(\.displayPath)

            var totalChars = 0
            for file in selection.selected {
                try Task.checkCancellation()
                let content: String
                do {
                    content = try await RichExtractor.extract(
                        url: file.url, kind: file.extraction, settings: request.extraction
                    )
                } catch ExtractionError.noTextFound {
                    decodeSkipped.append(
                        SkippedItem(displayPath: file.displayPath, reason: .noTextExtracted))
                    continue
                } catch {
                    decodeSkipped.append(
                        SkippedItem(displayPath: file.displayPath,
                                    reason: file.extraction == .plainText ? .binary : .unreadable))
                    continue
                }
                if let maxChars = request.limits.maxTotalChars, totalChars + content.count > maxChars {
                    omitted.append(file.displayPath)
                    continue
                }
                totalChars += content.count
                renderFiles.append(RenderFile(
                    displayPath: file.displayPath, language: file.language, content: content
                ))
            }
        }

        let wantsTree = mode == .tree || mode == .treeAndContents
        let tree = wantsTree ? TreeRenderer.render(outcome.trees) : nil

        if renderFiles.isEmpty && !wantsTree {
            throw CopyPipelineError.nothingToCopy(report(
                outcome: outcome, decodeSkipped: decodeSkipped, omitted: omitted,
                copied: 0, chars: 0, request: request, start: start
            ))
        }

        let payload = RenderPayload(
            template: request.template, tree: tree,
            files: renderFiles, omittedPaths: omitted
        )
        let text = request.format.formatter.render(payload)
        let copied = wantsContents ? renderFiles.count : outcome.files.count
        return GeneratedOutput(
            text: text,
            report: report(
                outcome: outcome, decodeSkipped: decodeSkipped, omitted: omitted,
                copied: copied, chars: text.count, request: request, start: start
            )
        )
    }

    static func resolveMode(_ request: CopyRequest) -> OutputMode {
        guard request.mode == .auto else { return request.mode }
        let anyDirectory = request.roots.contains {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
        return anyDirectory ? .treeAndContents : .contents
    }

    private static func pathsOutput(_ request: CopyRequest, start: ContinuousClock.Instant) -> GeneratedOutput {
        let sorted = request.roots.sorted { $0.path < $1.path }
        let lines: [String]
        switch request.pathMode {
        case .absolute:
            lines = sorted.map { $0.standardizedFileURL.path }
        case .nameOnly:
            lines = sorted.map { $0.lastPathComponent }
        case .relative:
            let parents = Set(sorted.map { $0.deletingLastPathComponent().standardizedFileURL.path })
            if parents.count == 1, let parent = parents.first {
                lines = sorted.map {
                    String($0.standardizedFileURL.path.dropFirst(parent.count).drop(while: { $0 == "/" }))
                }
            } else {
                lines = sorted.map { $0.standardizedFileURL.path }
            }
        }
        let text = lines.joined(separator: "\n") + "\n"
        let estimator = CharacterHeuristicEstimator(charsPerToken: request.charsPerToken)
        return GeneratedOutput(
            text: text,
            report: RunReport(
                filesCopied: lines.count, ignoredCount: 0, skipped: [], skippedTotal: 0,
                omittedByBudget: [], totalChars: text.count,
                estimatedTokens: estimator.estimateTokens(chars: text.count),
                duration: durationSince(start)
            )
        )
    }

    private static func report(
        outcome: ScanOutcome, decodeSkipped: [SkippedItem], omitted: [String],
        copied: Int, chars: Int, request: CopyRequest, start: ContinuousClock.Instant
    ) -> RunReport {
        let estimator = CharacterHeuristicEstimator(charsPerToken: request.charsPerToken)
        return RunReport(
            filesCopied: copied,
            ignoredCount: outcome.ignoredCount,
            skipped: Array((outcome.skipped + decodeSkipped).prefix(FileScanner.skipListCap)),
            skippedTotal: outcome.skippedTotal + decodeSkipped.count,
            omittedByBudget: omitted,
            totalChars: chars,
            estimatedTokens: estimator.estimateTokens(chars: chars),
            duration: durationSince(start)
        )
    }

    private static func durationSince(_ start: ContinuousClock.Instant) -> TimeInterval {
        let d = start.duration(to: .now)
        return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }
}
