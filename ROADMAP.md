# Roadmap

Ordered by priority. Everything here is a frontend or a plug-in point over
`CopyForLLMCore`. See [DEVELOPING.md](DEVELOPING.md) for the architecture.

## Shipped

**Document and image text extraction** (v0.2.0). PDF text layers via PDFKit,
scanned pages and images via Vision OCR, and Word, RTF and OpenDocument files
via `NSAttributedString`. Configurable under Settings → Documents.

**PowerPoint, Excel and Word** (v0.2.0). Parsed natively with a minimal ZIP
reader over the `Compression` framework and an Office Open XML text extractor,
so behaviour is identical in the Quick Actions and the Options window.

## Design constraint: no external tools

Text extraction runs entirely on-device with system frameworks. Two constraints
drive that choice, and they apply to any future format work:

1. **The Quick Action extensions are sandboxed** and cannot invoke external
   binaries. Anything depending on a separate tool works only in the main app,
   which would make the same file produce different output depending on the
   entry point used.
2. **No content may leave the machine.** OCR that relies on a hosted model would
   require an API key and upload user files.

This rules out [MarkItDown](https://github.com/microsoft/markitdown) for the OCR
path: it performs no local recognition (images require an LLM client or the
`markitdown-ocr` plugin, which calls a hosted Vision API) and scanned PDFs
require Azure Document Intelligence. Pandoc reads `.pptx`, `.xlsx`, `.docx`,
`.odt` and `.epub`, but cannot read PDF at all and is an external binary.

## Next

### 1. Optional Pandoc for richer structure

Would preserve headings, lists and tables as Markdown rather than flat text, and
add `.epub`. Requires opt-in, a clear status when Pandoc is not installed, and a
way to avoid diverging from the native path, most likely by routing the Quick
Action through the main app when enabled.

### 2. Apple Keynote and Pages

`.key` and `.pages` are undocumented protobuf bundles; no third-party tool reads
them. The only reliable route is AppleScript automation of the Apple app itself
to export, which needs the app installed, an Automation permission prompt, and
main-app-only execution.

### 3. First-run extension check

Detect whether the Quick Actions are enabled and report it in the Getting
Started window, with a button to the relevant settings pane. A user who misses
that step sees nothing in Finder and has no indication why.

### 4. Verify the minimum supported macOS version

The manifest and cask both declare macOS 14. The extension, signing and
notarization behaviour documented in [DEVELOPING.md](DEVELOPING.md) has only
been exercised on macOS 26. Either test on 14 and 15 or raise the declared
minimum to a version that has been verified.

## Later

- **Git diff mode:** "copy only what changed" against `HEAD` or a branch
- **Exact token counts:** swap the chars÷4 heuristic for a real tokenizer
  behind the existing `TokenEstimating` protocol
- **Automatic chunking:** split output that exceeds a context window
- **Archives:** read inside `.zip` / `.tar.gz` without unpacking
- **Drag-and-drop window:** drop files onto the menu bar icon
- **Standalone CLI release:** `llmcopy` already exists as a dev harness in
  `CopyForLLMCore`; it needs argument polish, a Homebrew formula, and docs
- **Raycast / Alfred / Keyboard Maestro:** thin frontends over the same engine
- **Global hotkey:** trigger from any app, not just Finder (needs Automation
  permission to read the Finder selection)
- **Mac App Store build:** requires replacing the extensions'
  `temporary-exception` entitlement with a real App Group and sandboxing the
  main app

## Not planned

- **Clipboard history.** Maccy, Raycast, and Paste already do this well, and
  storing full codebase dumps on disk is a privacy liability. "Re-copy Last
  Output" covers the real need.
- **Sending directly to an LLM.** Would mean API keys, network access, and a
  privacy story this app currently doesn't need. Everything stays on your Mac.
