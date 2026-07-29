import Foundation

/// Selection passed from the Options… Quick Action to the main app.
public struct SelectionHandoff: Codable, Sendable {
    public var paths: [String]
    /// Security-scoped bookmarks, stored so a future sandboxed build works unchanged.
    public var bookmarks: [Data]
    public var date: Date

    public init(paths: [String], bookmarks: [Data] = [], date: Date = Date()) {
        self.paths = paths
        self.bookmarks = bookmarks
        self.date = date
    }
}

/// JSON-file persistence shared by the app, the Quick Action extensions, and the CLI.
///
/// Direct distribution runs unsandboxed, so `~/Library/Application Support/CopyForLLM`
/// is readable by every process. A future sandboxed (App Store) build would switch to
/// an App Group container by passing its URL to `init(directory:)`.
public struct SharedStore: Sendable {

    public let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            self.directory = Self.realHomeDirectory()
                .appendingPathComponent("Library/Application Support/CopyForLLM", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    /// The user's actual home, not the sandbox container — the sandboxed Quick Action
    /// extensions reach the shared directory through a temporary-exception entitlement,
    /// which is expressed relative to the real home.
    static func realHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private var settingsURL: URL { directory.appendingPathComponent("settings.json") }
    private var handoffURL: URL { directory.appendingPathComponent("handoff.json") }
    private var lastOutputURL: URL { directory.appendingPathComponent("last-output.txt") }

    // MARK: Settings

    public func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    public func saveSettings(_ settings: AppSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: settingsURL, options: .atomic)
    }

    // MARK: Selection hand-off

    public func writeHandoff(_ handoff: SelectionHandoff) throws {
        try JSONEncoder().encode(handoff).write(to: handoffURL, options: .atomic)
    }

    /// Reads and consumes the pending hand-off. Stale hand-offs (>2 min) are discarded.
    public func takeHandoff() -> SelectionHandoff? {
        guard let data = try? Data(contentsOf: handoffURL),
              let handoff = try? JSONDecoder().decode(SelectionHandoff.self, from: data) else {
            return nil
        }
        try? FileManager.default.removeItem(at: handoffURL)
        guard Date().timeIntervalSince(handoff.date) < 120 else { return nil }
        return handoff
    }

    // MARK: Last output ("re-copy" without a full clipboard history)

    public func saveLastOutput(_ text: String) throws {
        try Data(text.utf8).write(to: lastOutputURL, options: .atomic)
    }

    public func loadLastOutput() -> String? {
        guard let data = try? Data(contentsOf: lastOutputURL) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
