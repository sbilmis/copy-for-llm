import Foundation

/// `===== path =====` separators, matching the spec's example.
public struct PlainFormatter: OutputFormatter {

    public init() {}

    public func render(_ payload: RenderPayload) -> String {
        var sections: [String] = []
        if let template = payload.template, !template.isEmpty {
            sections.append(template)
        }
        if let tree = payload.tree {
            sections.append(tree)
        }
        for file in payload.files {
            let body = file.content.hasSuffix("\n") ? String(file.content.dropLast()) : file.content
            sections.append("===== \(file.displayPath) =====\n\n" + body)
        }
        if !payload.omittedPaths.isEmpty {
            sections.append(Self.omittedNote(payload.omittedPaths))
        }
        return sections.joined(separator: "\n\n") + "\n"
    }

    static func omittedNote(_ paths: [String]) -> String {
        var lines = ["----- \(paths.count) file(s) omitted due to size limits -----"]
        lines.append(contentsOf: paths.prefix(20))
        if paths.count > 20 { lines.append("… and \(paths.count - 20) more") }
        return lines.joined(separator: "\n")
    }
}
