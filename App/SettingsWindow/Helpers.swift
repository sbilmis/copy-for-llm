import CopyForLLMCore
import SwiftUI

extension OutputMode {
    var displayName: String {
        switch self {
        case .auto: "Automatic"
        case .contents: "File Contents"
        case .tree: "Tree Only"
        case .treeAndContents: "Tree + Contents"
        case .paths: "Paths Only"
        }
    }
}

extension PathMode {
    var displayName: String {
        switch self {
        case .absolute: "Absolute Path"
        case .relative: "Relative Path"
        case .nameOnly: "Filename Only"
        }
    }
}

/// Empty field = no limit.
struct OptionalIntField: View {
    let label: String
    @Binding var value: Int?

    var body: some View {
        TextField(label, text: Binding(
            get: { value.map(String.init) ?? "" },
            set: { value = Int($0.trimmingCharacters(in: .whitespaces)) }
        ), prompt: Text("No limit"))
    }
}

/// Byte limit surfaced in megabytes. Empty field = no limit.
struct OptionalMBField: View {
    let label: String
    @Binding var bytes: Int64?

    var body: some View {
        TextField(label, text: Binding(
            get: {
                guard let bytes else { return "" }
                let mb = Double(bytes) / 1_000_000
                return mb == mb.rounded() ? String(Int(mb)) : String(format: "%.2f", mb)
            },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespaces)
                bytes = Double(trimmed).map { Int64($0 * 1_000_000) }
            }
        ), prompt: Text("No limit"))
    }
}

/// One entry per line ⇄ [String]. Lines are stored raw — blank lines and comments
/// are skipped by the gitignore-syntax parser at use time, and filtering here would
/// fight the TextEditor cursor mid-edit.
func lineListBinding(_ list: Binding<[String]>) -> Binding<String> {
    Binding(
        get: { list.wrappedValue.joined(separator: "\n") },
        set: { list.wrappedValue = $0.components(separatedBy: .newlines) }
    )
}
