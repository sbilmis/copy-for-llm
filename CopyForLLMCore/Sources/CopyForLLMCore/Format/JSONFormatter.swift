import Foundation

/// Machine-readable output for API pipelines.
public struct JSONFormatter: OutputFormatter {

    struct Document: Codable {
        var instructions: String?
        var tree: String?
        var files: [File]
        var omittedFiles: [String]?

        struct File: Codable {
            var path: String
            var language: String?
            var content: String
        }
    }

    public init() {}

    public func render(_ payload: RenderPayload) -> String {
        let document = Document(
            instructions: payload.template.flatMap { $0.isEmpty ? nil : $0 },
            tree: payload.tree,
            files: payload.files.map {
                Document.File(
                    path: $0.displayPath,
                    language: $0.language.isEmpty ? nil : $0.language,
                    content: $0.content
                )
            },
            omittedFiles: payload.omittedPaths.isEmpty ? nil : payload.omittedPaths
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(document),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text + "\n"
    }
}
