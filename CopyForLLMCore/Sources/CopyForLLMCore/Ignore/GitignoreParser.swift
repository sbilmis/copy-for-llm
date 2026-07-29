import Foundation

/// One parsed gitignore-syntax rule.
public struct GitignoreRule: Sendable {
    public let negated: Bool
    public let dirOnly: Bool
    public let anchored: Bool
    public let segments: [String]
    public let source: String

    /// - Parameter relativePath: path relative to the directory holding the ignore file, `/`-separated.
    public func matches(relativePath: String, isDirectory: Bool) -> Bool {
        if dirOnly && !isDirectory { return false }
        let parts = relativePath.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { return false }
        if anchored {
            return GlobMatcher.matchPath(segments, parts)
        }
        // Unanchored patterns match at any depth.
        return GlobMatcher.matchPath(["**"] + segments, parts)
    }
}

/// An ordered list of rules from one ignore source; last matching rule wins.
public struct GitignoreFile: Sendable {
    public let rules: [GitignoreRule]

    public init(rules: [GitignoreRule]) {
        self.rules = rules
    }

    public init(lines: [String], source: String) {
        self.rules = lines.compactMap { GitignoreParser.parse(line: $0, source: source) }
    }

    public init(contentsOf url: URL) {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        self.init(lines: text.components(separatedBy: .newlines), source: url.lastPathComponent)
    }

    public var isEmpty: Bool { rules.isEmpty }

    /// nil = no rule matched; true = ignored; false = explicitly re-included (negation).
    public func verdict(relativePath: String, isDirectory: Bool) -> Bool? {
        var result: Bool?
        for rule in rules where rule.matches(relativePath: relativePath, isDirectory: isDirectory) {
            result = !rule.negated
        }
        return result
    }
}

public enum GitignoreParser {

    public static func parse(line raw: String, source: String) -> GitignoreRule? {
        var line = raw
        // Trailing whitespace is stripped unless escaped; we don't support the escape.
        while line.hasSuffix(" ") || line.hasSuffix("\t") { line.removeLast() }
        guard !line.isEmpty, !line.hasPrefix("#") else { return nil }

        var negated = false
        if line.hasPrefix("!") {
            negated = true
            line.removeFirst()
        } else if line.hasPrefix("\\!") || line.hasPrefix("\\#") {
            line.removeFirst()
        }
        guard !line.isEmpty else { return nil }

        var dirOnly = false
        if line.hasSuffix("/") {
            dirOnly = true
            line.removeLast()
        }
        guard !line.isEmpty else { return nil }

        // A slash anywhere (now that the trailing one is stripped) anchors the pattern.
        var anchored = line.contains("/")
        if line.hasPrefix("/") {
            line.removeFirst()
            anchored = true
        }
        guard !line.isEmpty else { return nil }

        var segments = line.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        // A trailing `/**` means "everything inside", which for traversal is the same set of
        // paths as the bare directory pattern followed by any suffix.
        if segments.count > 1, segments.last == "**" {
            segments[segments.count - 1] = "*"
            segments.append("**")
        }
        // Leading `**/` makes the pattern effectively unanchored at any depth; matchPath handles it.
        guard !segments.isEmpty else { return nil }
        return GitignoreRule(
            negated: negated, dirOnly: dirOnly, anchored: anchored,
            segments: segments, source: source
        )
    }
}
