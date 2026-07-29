import Foundation

public struct IgnoreConfiguration: Sendable {
    /// User exclude globs (gitignore syntax). Highest precedence.
    public var excludeGlobs: [String]
    /// User include globs. When non-empty, only matching *files* are included,
    /// and a match overrides ignore-file/default rules (but never excludes).
    public var includeGlobs: [String]
    public var respectGitignore: Bool
    public var respectLlmignore: Bool
    /// Built-in default rules, gitignore syntax. Lowest precedence.
    public var defaultRules: [String]

    public init(
        excludeGlobs: [String] = [],
        includeGlobs: [String] = [],
        respectGitignore: Bool = true,
        respectLlmignore: Bool = true,
        defaultRules: [String] = DefaultIgnoreRules.standard
    ) {
        self.excludeGlobs = excludeGlobs
        self.includeGlobs = includeGlobs
        self.respectGitignore = respectGitignore
        self.respectLlmignore = respectLlmignore
        self.defaultRules = defaultRules
    }
}

public enum DefaultIgnoreRules {
    /// Ships as the editable default in Settings.
    public static let standard: [String] = [
        // VCS / tooling metadata
        ".git/", ".hg/", ".svn/",
        // Dependency + build output directories
        "node_modules/", "venv/", ".venv/", "__pycache__/", "target/", "build/",
        "dist/", ".build/", ".cache/", ".mypy_cache/", ".pytest_cache/", ".ruff_cache/",
        ".idea/", ".DS_Store",
        // Compiled artifacts
        "*.o", "*.so", "*.a", "*.dylib", "*.pyc", "*.class", "*.jar",
        // Images / media / archives / documents
        "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.tiff", "*.heic",
        "*.ico", "*.icns", "*.pdf",
        "*.zip", "*.tar", "*.gz", "*.bz2", "*.xz", "*.7z", "*.dmg", "*.iso",
        "*.mp3", "*.wav", "*.mp4", "*.mov", "*.avi", "*.mkv",
        "*.woff", "*.woff2", "*.ttf", "*.otf", "*.eot",
        // Secrets — never ship credentials to an LLM by accident
        ".env", ".env.*", "*.pem", "*.der", "*.p12", "*.pfx", "id_rsa*", "id_ed25519*",
    ]
}

public enum SkipReason: String, Sendable, Codable {
    case userExclude = "excluded by filter"
    case notIncluded = "not in include patterns"
    case llmignore = ".llmignore"
    case gitignore = ".gitignore"
    case defaultRule = "default ignore rule"
    case binary = "binary content"
    case undecodable = "undecodable text"
    case symlink = "symbolic link"
    case tooLarge = "exceeds per-file size limit"
    case budget = "output size limit reached"
    case unreadable = "unreadable"
}

public enum IgnoreDecision: Sendable, Equatable {
    case include
    case exclude(SkipReason)
}

/// Layered ignore evaluation used during directory traversal.
/// Push a layer per directory entered (which loads that directory's ignore files),
/// pop on exit. Not thread-safe; owned by a single scan.
public final class IgnoreEngine {

    private struct Layer {
        /// Depth in components from the scan root, used to relativize paths per ignore file.
        let depth: Int
        let gitignore: GitignoreFile?
        let llmignore: GitignoreFile?
    }

    private let config: IgnoreConfiguration
    private let defaultRules: GitignoreFile
    private let excludeRules: GitignoreFile
    private let includeRules: GitignoreFile?
    private var layers: [Layer] = []

    public init(config: IgnoreConfiguration) {
        self.config = config
        self.defaultRules = GitignoreFile(lines: config.defaultRules, source: "defaults")
        self.excludeRules = GitignoreFile(lines: config.excludeGlobs, source: "exclude")
        self.includeRules = config.includeGlobs.isEmpty
            ? nil
            : GitignoreFile(lines: config.includeGlobs, source: "include")
    }

    /// Enter `directory`, whose path relative to the scan root has `depth` components
    /// (0 for the root itself).
    public func push(directory: URL, depth: Int) {
        var gitignore: GitignoreFile?
        var llmignore: GitignoreFile?
        if config.respectGitignore {
            let url = directory.appendingPathComponent(".gitignore")
            if FileManager.default.fileExists(atPath: url.path) {
                let parsed = GitignoreFile(contentsOf: url)
                if !parsed.isEmpty { gitignore = parsed }
            }
        }
        if config.respectLlmignore {
            let url = directory.appendingPathComponent(".llmignore")
            if FileManager.default.fileExists(atPath: url.path) {
                let parsed = GitignoreFile(contentsOf: url)
                if !parsed.isEmpty { llmignore = parsed }
            }
        }
        layers.append(Layer(depth: depth, gitignore: gitignore, llmignore: llmignore))
    }

    public func pop() {
        _ = layers.popLast()
    }

    /// Decide whether the item at `components` (path relative to scan root) is included.
    public func decision(components: [String], isDirectory: Bool) -> IgnoreDecision {
        let path = components.joined(separator: "/")

        if excludeRules.verdict(relativePath: path, isDirectory: isDirectory) == true {
            return .exclude(.userExclude)
        }

        if let includeRules {
            if !isDirectory {
                if includeRules.verdict(relativePath: path, isDirectory: false) == true {
                    return .include  // include match overrides ignore files and defaults
                }
                return .exclude(.notIncluded)
            }
            // Directories still fall through so ignore rules can prune traversal.
        }

        if let verdict = layeredVerdict(components: components, isDirectory: isDirectory, keyPath: \.llmignore) {
            return verdict ? .exclude(.llmignore) : .include
        }
        if let verdict = layeredVerdict(components: components, isDirectory: isDirectory, keyPath: \.gitignore) {
            return verdict ? .exclude(.gitignore) : .include
        }
        if defaultRules.verdict(relativePath: path, isDirectory: isDirectory) == true {
            return .exclude(.defaultRule)
        }
        return .include
    }

    /// Evaluates nested ignore files shallow→deep; the deepest file with an opinion wins.
    private func layeredVerdict(
        components: [String],
        isDirectory: Bool,
        keyPath: KeyPath<Layer, GitignoreFile?>
    ) -> Bool? {
        var result: Bool?
        for layer in layers {
            guard let file = layer[keyPath: keyPath] else { continue }
            guard components.count > layer.depth else { continue }
            let relative = components[layer.depth...].joined(separator: "/")
            if let verdict = file.verdict(relativePath: relative, isDirectory: isDirectory) {
                result = verdict
            }
        }
        return result
    }
}
