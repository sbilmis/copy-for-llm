import Foundation

/// Path-aware glob matching with gitignore-style semantics:
/// `*` and `?` never cross `/`, `**` matches zero or more path segments,
/// `[abc]`/`[a-z]`/`[!a-z]` character classes.
public enum GlobMatcher {

    /// Matches a single path segment (no `/` on either side).
    public static func matchSegment(_ pattern: String, _ text: String) -> Bool {
        let p = Array(pattern)
        let t = Array(text)
        var pi = 0, ti = 0
        var starPi = -1, starTi = 0

        while ti < t.count {
            if pi < p.count, p[pi] == "*" {
                starPi = pi
                starTi = ti
                pi += 1
                continue
            }
            if pi < p.count, let len = matchToken(p, at: pi, char: t[ti]) {
                pi += len
                ti += 1
                continue
            }
            if starPi >= 0 {
                starTi += 1
                pi = starPi + 1
                ti = starTi
                continue
            }
            return false
        }
        while pi < p.count, p[pi] == "*" { pi += 1 }
        return pi == p.count
    }

    /// Matches a `/`-split pattern against `/`-split path components, honoring `**`.
    public static func matchPath(_ patternSegments: [String], _ pathSegments: [String]) -> Bool {
        matchPath(patternSegments, pathSegments, 0, 0)
    }

    private static func matchPath(_ pat: [String], _ path: [String], _ pi: Int, _ si: Int) -> Bool {
        if pi == pat.count { return si == path.count }
        if pat[pi] == "**" {
            for k in si...path.count where matchPath(pat, path, pi + 1, k) { return true }
            return false
        }
        guard si < path.count, matchSegment(pat[pi], path[si]) else { return false }
        return matchPath(pat, path, pi + 1, si + 1)
    }

    /// Returns the token length consumed if the token at `p[i]` matches `char`, else nil.
    /// Tokens: `?`, `[class]`, `\x` escape, or a literal character.
    private static func matchToken(_ p: [Character], at i: Int, char: Character) -> Int? {
        switch p[i] {
        case "?":
            return 1
        case "\\" where i + 1 < p.count:
            return p[i + 1] == char ? 2 : nil
        case "[":
            guard let (matches, len) = matchClass(p, at: i, char: char) else {
                // Unclosed bracket: treat as literal '['.
                return char == "[" ? 1 : nil
            }
            return matches ? len : nil
        default:
            return p[i] == char ? 1 : nil
        }
    }

    /// Parses `[...]` starting at `i`. Returns (didMatch, tokenLength), or nil if unclosed.
    private static func matchClass(_ p: [Character], at i: Int, char: Character) -> (Bool, Int)? {
        var j = i + 1
        var negated = false
        if j < p.count, p[j] == "!" || p[j] == "^" {
            negated = true
            j += 1
        }
        var matched = false
        var first = true
        while j < p.count {
            if p[j] == "]" && !first {
                return (matched != negated, j - i + 1)
            }
            first = false
            if j + 2 < p.count, p[j + 1] == "-", p[j + 2] != "]" {
                if p[j] <= char && char <= p[j + 2] { matched = true }
                j += 3
            } else {
                if p[j] == char { matched = true }
                j += 1
            }
        }
        return nil
    }
}
