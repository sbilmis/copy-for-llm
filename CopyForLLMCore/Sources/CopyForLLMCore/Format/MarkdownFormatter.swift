import Foundation

/// `## path` headings with language-hinted code fences.
public struct MarkdownFormatter: OutputFormatter {

    public init() {}

    public func render(_ payload: RenderPayload) -> String {
        var sections: [String] = []
        if let template = payload.template, !template.isEmpty {
            sections.append(template)
        }
        if let tree = payload.tree {
            sections.append("## Directory structure\n\n" + fenced(tree, language: "text"))
        }
        for file in payload.files {
            sections.append("## \(file.displayPath)\n\n" + fenced(file.content, language: file.language))
        }
        if !payload.omittedPaths.isEmpty {
            var note = "> \(payload.omittedPaths.count) file(s) omitted due to size limits: "
            note += payload.omittedPaths.prefix(10).joined(separator: ", ")
            if payload.omittedPaths.count > 10 { note += ", …" }
            sections.append(note)
        }
        return sections.joined(separator: "\n\n") + "\n"
    }

    /// Fences content with enough backticks to survive fences inside the content.
    func fenced(_ content: String, language: String) -> String {
        var longestRun = 0
        var run = 0
        for char in content {
            if char == "`" {
                run += 1
                longestRun = max(longestRun, run)
            } else {
                run = 0
            }
        }
        let fence = String(repeating: "`", count: max(3, longestRun + 1))
        let body = content.hasSuffix("\n") ? content : content + "\n"
        return fence + language + "\n" + body + fence
    }
}
