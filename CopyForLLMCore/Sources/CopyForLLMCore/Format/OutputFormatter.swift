import Foundation

public enum OutputFormat: String, Codable, Sendable, CaseIterable, Identifiable {
    case plain
    case markdown
    case xml
    case json

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .plain: "Plain Text"
        case .markdown: "Markdown"
        case .xml: "XML"
        case .json: "JSON"
        }
    }

    public var formatter: any OutputFormatter {
        switch self {
        case .plain: PlainFormatter()
        case .markdown: MarkdownFormatter()
        case .xml: XMLFormatter()
        case .json: JSONFormatter()
        }
    }
}

public struct RenderFile: Sendable {
    public var displayPath: String
    public var language: String
    public var content: String

    public init(displayPath: String, language: String, content: String) {
        self.displayPath = displayPath
        self.language = language
        self.content = content
    }
}

public struct RenderPayload: Sendable {
    /// Prompt template text, prepended as instructions.
    public var template: String?
    /// Pre-rendered directory tree; nil when the mode has no tree section.
    public var tree: String?
    public var files: [RenderFile]
    /// Display paths of files dropped by size budgets.
    public var omittedPaths: [String]

    public init(template: String? = nil, tree: String? = nil,
                files: [RenderFile] = [], omittedPaths: [String] = []) {
        self.template = template
        self.tree = tree
        self.files = files
        self.omittedPaths = omittedPaths
    }
}

public protocol OutputFormatter: Sendable {
    func render(_ payload: RenderPayload) -> String
}
