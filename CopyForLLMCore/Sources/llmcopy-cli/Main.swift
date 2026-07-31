import CopyForLLMCore
import Foundation

/// Developer harness for the core engine — and the seed of the roadmap CLI.
///
///     swift run llmcopy <path>... [options]
@main
struct LLMCopyCLI {

    static let usage = """
    usage: llmcopy <path>... [options]

    options:
      --format <plain|markdown|xml|json>   output format (default: markdown)
      --mode <auto|contents|tree|tree-contents|paths>
      --path-mode <absolute|relative|name> for --mode paths
      --include <glob>                     repeatable; only matching files
      --exclude <glob>                     repeatable
      --no-gitignore                       don't respect .gitignore
      --max-files <n> | --max-chars <n> | --max-mb <n>
      --template <text>                    prepended instructions
      --extract                            read PDFs, Word docs, and selected images
      --ocr-all                            also OCR images found inside folders
      --no-extract                         plain text only (default)
      --copy                               write to clipboard instead of stdout
      --report                             print run report to stderr
    """

    static func main() async {
        var roots: [URL] = []
        var request = CopyRequest(roots: [])
        var copyToClipboard = false
        var showReport = false

        var args = Array(CommandLine.arguments.dropFirst())[...]
        func next(_ flag: String) -> String {
            guard let value = args.popFirst() else {
                fail("missing value for \(flag)")
            }
            return value
        }

        while let arg = args.popFirst() {
            switch arg {
            case "--format":
                guard let format = OutputFormat(rawValue: next(arg)) else { fail("bad --format") }
                request.format = format
            case "--mode":
                switch next(arg) {
                case "auto": request.mode = .auto
                case "contents": request.mode = .contents
                case "tree": request.mode = .tree
                case "tree-contents": request.mode = .treeAndContents
                case "paths": request.mode = .paths
                default: fail("bad --mode")
                }
            case "--path-mode":
                switch next(arg) {
                case "absolute": request.pathMode = .absolute
                case "relative": request.pathMode = .relative
                case "name": request.pathMode = .nameOnly
                default: fail("bad --path-mode")
                }
            case "--include": request.ignore.includeGlobs.append(next(arg))
            case "--exclude": request.ignore.excludeGlobs.append(next(arg))
            case "--no-gitignore": request.ignore.respectGitignore = false
            case "--max-files": request.limits.maxFiles = Int(next(arg))
            case "--max-chars": request.limits.maxTotalChars = Int(next(arg))
            case "--max-mb":
                guard let mb = Double(next(arg)) else { fail("bad --max-mb") }
                request.limits.maxTotalBytes = Int64(mb * 1_000_000)
            case "--template": request.template = next(arg)
            case "--extract": request.extraction = ExtractionSettings()
            case "--ocr-all": request.extraction = ExtractionSettings(ocr: .always)
            case "--no-extract": request.extraction = .disabled
            case "--copy": copyToClipboard = true
            case "--report": showReport = true
            case "-h", "--help":
                print(usage)
                return
            default:
                if arg.hasPrefix("-") { fail("unknown option \(arg)") }
                roots.append(URL(fileURLWithPath: arg))
            }
        }

        guard !roots.isEmpty else { fail("no paths given") }
        request.roots = roots

        do {
            let output = try await CopyPipeline.run(request)
            if copyToClipboard {
                await MainActor.run { ClipboardWriter.write(output.text) }
                FileHandle.standardError.write(Data((output.report.summaryLine + "\n").utf8))
            } else {
                print(output.text, terminator: "")
            }
            if showReport {
                let r = output.report
                var lines = [
                    r.summaryLine,
                    "chars: \(r.totalChars), ignored: \(r.ignoredCount), skipped: \(r.skippedTotal)",
                ]
                lines += r.skipped.prefix(20).map { "  skipped \($0.displayPath): \($0.reason.rawValue)" }
                if !r.omittedByBudget.isEmpty {
                    lines.append("omitted by limits: \(r.omittedByBudget.count)")
                }
                FileHandle.standardError.write(Data((lines.joined(separator: "\n") + "\n").utf8))
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data(("llmcopy: " + message + "\n" + usage + "\n").utf8))
        exit(1)
    }
}
