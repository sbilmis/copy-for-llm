import Foundation

/// XML-tagged output following Claude prompt conventions
/// (`<instructions>`, `<file_tree>`, `<documents><document path=…>`).
public struct XMLFormatter: OutputFormatter {

    public init() {}

    public func render(_ payload: RenderPayload) -> String {
        var out = "<context>\n"
        if let template = payload.template, !template.isEmpty {
            out += "<instructions>\n\(Self.escape(template))\n</instructions>\n"
        }
        if let tree = payload.tree {
            out += "<file_tree>\n\(Self.escape(tree))\n</file_tree>\n"
        }
        if !payload.files.isEmpty {
            out += "<documents>\n"
            for file in payload.files {
                let language = file.language.isEmpty ? "" : " language=\"\(Self.escapeAttribute(file.language))\""
                out += "<document path=\"\(Self.escapeAttribute(file.displayPath))\"\(language)>\n"
                var body = Self.escape(file.content)
                if !body.hasSuffix("\n") { body += "\n" }
                out += body
                out += "</document>\n"
            }
            out += "</documents>\n"
        }
        if !payload.omittedPaths.isEmpty {
            out += "<omitted_files count=\"\(payload.omittedPaths.count)\">\n"
            for path in payload.omittedPaths.prefix(50) {
                out += "<path>\(Self.escape(path))</path>\n"
            }
            out += "</omitted_files>\n"
        }
        out += "</context>\n"
        return out
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func escapeAttribute(_ s: String) -> String {
        escape(s).replacingOccurrences(of: "\"", with: "&quot;")
    }
}
