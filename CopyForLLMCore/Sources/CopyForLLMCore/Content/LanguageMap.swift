import Foundation

public enum LanguageMap {

    /// File extensions treated as text without content sniffing.
    /// Superset of the supported-format list in the spec; user-extensible via Settings.
    public static let knownTextExtensions: Set<String> = [
        "txt", "md", "markdown", "py", "c", "cpp", "cc", "h", "hpp", "java",
        "js", "jsx", "mjs", "cjs", "ts", "tsx", "html", "htm", "css", "scss",
        "json", "yaml", "yml", "xml", "sh", "bash", "zsh", "fish", "tex", "bib",
        "org", "ini", "conf", "toml", "csv", "tsv", "log", "swift", "rs", "go",
        "rb", "php", "kt", "kts", "m", "mm", "sql", "r", "jl", "lua", "pl", "pm",
        "scala", "hs", "el", "vim", "gradle", "properties", "cfg", "rst", "adoc",
        "svg", "graphql", "proto", "cmake", "make", "mk", "diff", "patch",
        "gitignore", "gitattributes", "editorconfig", "dockerfile", "plist",
        "entitlements", "strings", "resolved", "lock", "sty", "cls",
    ]

    /// Extensionless file names treated as text.
    public static let knownTextFilenames: Set<String> = [
        "makefile", "dockerfile", "gemfile", "rakefile", "brewfile", "justfile",
        "license", "readme", "changelog", "authors", "contributing", "codeowners",
        "notice", "vagrantfile", "procfile", "cmakelists.txt",
    ]

    /// Syntax-highlighting hint for Markdown fences.
    public static func language(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "py": "python"
        case "js", "mjs", "cjs": "javascript"
        case "jsx": "jsx"
        case "ts": "typescript"
        case "tsx": "tsx"
        case "rb": "ruby"
        case "rs": "rust"
        case "kt", "kts": "kotlin"
        case "md", "markdown": "markdown"
        case "yml", "yaml": "yaml"
        case "sh", "bash", "zsh": "bash"
        case "h", "c": "c"
        case "hpp", "cc", "cpp": "cpp"
        case "m", "mm": "objectivec"
        case "htm", "html": "html"
        case "pl", "pm": "perl"
        case "tex", "sty", "cls": "latex"
        case "hs": "haskell"
        case "jl": "julia"
        case "gradle": "groovy"
        case "mk", "make": "makefile"
        case "el": "lisp"
        case "adoc": "asciidoc"
        case "": ""
        default: ext.lowercased()
        }
    }

    public static func language(forFileName name: String) -> String {
        let lower = name.lowercased()
        if lower == "makefile" { return "makefile" }
        if lower == "dockerfile" { return "dockerfile" }
        if lower == "cmakelists.txt" { return "cmake" }
        let ext = (name as NSString).pathExtension
        return language(forExtension: ext)
    }

    public static func isKnownText(fileName: String, extraExtensions: Set<String> = []) -> Bool {
        let lower = fileName.lowercased()
        if knownTextFilenames.contains(lower) { return true }
        let ext = (lower as NSString).pathExtension
        if ext.isEmpty {
            // Dotfiles like `.zshrc`: try the name without the leading dot.
            if lower.hasPrefix(".") {
                let stripped = String(lower.dropFirst())
                return knownTextExtensions.contains(stripped) || stripped.hasSuffix("rc")
            }
            return false
        }
        return knownTextExtensions.contains(ext) || extraExtensions.contains(ext)
    }
}
