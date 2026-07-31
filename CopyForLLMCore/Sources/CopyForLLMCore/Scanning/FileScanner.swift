import Foundation

public struct ScanOptions: Sendable {
    public var ignore: IgnoreConfiguration
    public var maxFileBytes: Int64?
    public var extraTextExtensions: Set<String>
    public var extraction: ExtractionSettings

    public init(
        ignore: IgnoreConfiguration = IgnoreConfiguration(),
        maxFileBytes: Int64? = Limits.standard.maxFileBytes,
        extraTextExtensions: Set<String> = [],
        extraction: ExtractionSettings = .disabled
    ) {
        self.ignore = ignore
        self.maxFileBytes = maxFileBytes
        self.extraTextExtensions = extraTextExtensions
        self.extraction = extraction
    }
}

public enum FileScanner {

    static let skipListCap = 200

    /// Walks the selected roots, applying ignore rules, and returns the included tree
    /// plus flat file list. Files selected directly (as roots) bypass ignore rules —
    /// the user explicitly chose them — but still go through binary/size checks.
    public static func scan(
        roots: [URL],
        options: ScanOptions = ScanOptions(),
        progress: (@Sendable (ScanProgress) -> Void)? = nil
    ) throws -> ScanOutcome {
        var state = ScanState(options: options, progress: progress)
        let multipleRoots = roots.count > 1

        for root in roots.sorted(by: { sortKey($0.lastPathComponent) < sortKey($1.lastPathComponent) }) {
            try Task.checkCancellation()
            let name = root.lastPathComponent
            guard let values = try? root.resourceValues(forKeys: [
                .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey,
            ]) else {
                state.skip(name, .unreadable)
                continue
            }
            if values.isSymbolicLink == true {
                state.skip(name, .symlink)
                continue
            }
            if values.isDirectory == true {
                let prefix = multipleRoots ? name : ""
                let engine = IgnoreEngine(config: options.ignore)
                var node = FileNode(name: name, isDirectory: true)
                try walk(directory: root, components: [], displayPrefix: prefix,
                         engine: engine, node: &node, state: &state)
                state.trees.append(node)
            } else {
                // Explicitly selected file.
                if let file = state.admitFile(url: root, displayPath: name,
                                              size: Int64(values.fileSize ?? 0),
                                              directlySelected: true) {
                    state.trees.append(FileNode(name: name, isDirectory: false))
                    state.files.append(file)
                }
            }
        }
        return state.outcome()
    }

    private static func walk(
        directory: URL,
        components: [String],
        displayPrefix: String,
        engine: IgnoreEngine,
        node: inout FileNode,
        state: inout ScanState
    ) throws {
        try Task.checkCancellation()
        engine.push(directory: directory, depth: components.count)
        defer { engine.pop() }

        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
            options: []
        )) ?? []

        for entry in entries.sorted(by: { sortKey($0.lastPathComponent) < sortKey($1.lastPathComponent) }) {
            let name = entry.lastPathComponent
            let comps = components + [name]
            state.scannedCount += 1
            state.reportProgress()

            guard let values = try? entry.resourceValues(forKeys: [
                .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey,
            ]) else {
                state.skip(displayPath(displayPrefix, comps), .unreadable)
                continue
            }
            if values.isSymbolicLink == true {
                state.skip(displayPath(displayPrefix, comps), .symlink)
                continue
            }
            let isDir = values.isDirectory == true

            if case .exclude(let reason) = engine.decision(components: comps, isDirectory: isDir) {
                // The built-in defaults exclude *.pdf, *.png and friends. When the
                // user has switched extraction on for those, the default rule must
                // yield — but their own excludes and .gitignore still win.
                let extractable = !isDir && ExtractionPlanner.kind(
                    forFileName: name, settings: state.options.extraction, directlySelected: false
                ) != nil
                guard reason == .defaultRule, extractable else {
                    state.ignoredCount += 1
                    continue
                }
            }

            if isDir {
                var child = FileNode(name: name, isDirectory: true)
                try walk(directory: entry, components: comps, displayPrefix: displayPrefix,
                         engine: engine, node: &child, state: &state)
                // Directories with nothing included are dropped from the tree.
                if !child.children.isEmpty {
                    node.children.append(child)
                }
            } else {
                let display = displayPath(displayPrefix, comps)
                if let file = state.admitFile(url: entry, displayPath: display,
                                              size: Int64(values.fileSize ?? 0)) {
                    node.children.append(FileNode(name: name, isDirectory: false))
                    state.files.append(file)
                }
            }
        }
    }

    private static func displayPath(_ prefix: String, _ components: [String]) -> String {
        let rel = components.joined(separator: "/")
        return prefix.isEmpty ? rel : prefix + "/" + rel
    }

    /// Deterministic, locale-independent ordering: case-insensitive, name as tiebreak.
    static func sortKey(_ name: String) -> (String, String) {
        (name.lowercased(), name)
    }

    private struct ScanState {
        let options: ScanOptions
        let progress: (@Sendable (ScanProgress) -> Void)?
        var trees: [FileNode] = []
        var files: [ScannedFile] = []
        var skipped: [SkippedItem] = []
        var skippedTotal = 0
        var ignoredCount = 0
        var scannedCount = 0

        mutating func skip(_ path: String, _ reason: SkipReason) {
            skippedTotal += 1
            if skipped.count < FileScanner.skipListCap {
                skipped.append(SkippedItem(displayPath: path, reason: reason))
            }
        }

        mutating func reportProgress() {
            if scannedCount % 64 == 0 {
                progress?(ScanProgress(scanned: scannedCount, included: files.count, ignored: ignoredCount))
            }
        }

        /// Size cap + text detection. Returns nil (and records the skip) if rejected.
        mutating func admitFile(
            url: URL, displayPath: String, size: Int64, directlySelected: Bool = false
        ) -> ScannedFile? {
            let name = url.lastPathComponent

            // PDFs, images and Word documents are binary, so they must be matched
            // before the text checks below would reject them — and they get their
            // own, larger size cap.
            if let kind = ExtractionPlanner.kind(
                forFileName: name, settings: options.extraction, directlySelected: directlySelected
            ) {
                if let cap = options.extraction.maxSourceBytes, size > cap {
                    skip(displayPath, .tooLarge)
                    return nil
                }
                return ScannedFile(
                    url: url, displayPath: displayPath, sizeBytes: size,
                    language: "", extraction: kind
                )
            }

            if let cap = options.maxFileBytes, size > cap {
                skip(displayPath, .tooLarge)
                return nil
            }

            if !LanguageMap.isKnownText(fileName: name, extraExtensions: options.extraTextExtensions) {
                guard let handle = try? FileHandle(forReadingFrom: url) else {
                    skip(displayPath, .unreadable)
                    return nil
                }
                let head = (try? handle.read(upToCount: EncodingDetector.sniffLength)) ?? Data()
                try? handle.close()
                if head.isEmpty && size > 0 {
                    skip(displayPath, .unreadable)
                    return nil
                }
                if EncodingDetector.looksBinary(head) {
                    skip(displayPath, .binary)
                    return nil
                }
            }
            return ScannedFile(
                url: url, displayPath: displayPath, sizeBytes: size,
                language: LanguageMap.language(forFileName: name)
            )
        }

        func outcome() -> ScanOutcome {
            progress?(ScanProgress(scanned: scannedCount, included: files.count, ignored: ignoredCount))
            return ScanOutcome(
                trees: trees, files: files, skipped: skipped, skippedTotal: skippedTotal,
                ignoredCount: ignoredCount, scannedCount: scannedCount
            )
        }
    }
}
