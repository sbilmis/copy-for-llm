# Roadmap

Ordered by priority. Everything here is a frontend or a plug-in point over
`CopyForLLMCore` — see [DEVELOPING.md](DEVELOPING.md) for the architecture.

## Done

### OCR and PDF text extraction ✅

Shipped. PDFs (text layer, with Vision OCR for scanned pages), images, and
Word/RTF/OpenDocument files are extracted to text via PDFKit, Vision and
`NSAttributedString` — all on-device, no dependencies, no API keys. Configurable
in Settings → Documents.

Deliberately **not** built on [MarkItDown](https://github.com/microsoft/markitdown):
it performs no local OCR (images need an LLM client or the `markitdown-ocr`
plugin, which calls an LLM Vision API), scanned PDFs need Azure Document
Intelligence, and it's a Python package — which the sandboxed Quick Action
extensions cannot invoke at all. Apple's Vision is better for this job and keeps
the "nothing leaves your Mac" promise.

### PowerPoint, Excel and Word ✅

Shipped. `.pptx`, `.xlsx` and `.docx` are parsed natively — a minimal ZIP reader
over the `Compression` framework, then the XML text parts. No dependency, and it
works inside the sandboxed Quick Actions, so right-click and the Options window
behave identically.

Pandoc was considered and deferred rather than rejected: it reads `.pptx`,
`.xlsx`, `.docx`, `.odt` and `.epub`, and would give better *structure*
(Markdown tables and headings) than raw text. But it cannot read PDF at all, it
is an external binary the sandboxed extensions cannot invoke, and shipping both
paths would mean the same file producing different output depending on which
entry point was used. The `ExtractionKind` seam makes adding it cheap if anyone
hits the limits of the native parser.

## Next

### 1. Optional Pandoc for richer structure

Only worth building on real demand. Would preserve headings, lists and tables as
Markdown instead of flat text, and add `.epub`. Must be opt-in, must report
clearly when Pandoc isn't installed, and must not silently diverge from the
native path — probably by routing the Quick Action through the main app when
enabled.

### 2. Apple Keynote and Pages

`.key` and `.pages` are undocumented protobuf bundles; no third-party tool reads
them. The only reliable route is AppleScript automation of the Apple app itself
to export, which needs the app installed, an Automation permission prompt, and
main-app-only execution.

### 3. First-run extension check

Detect whether the Quick Actions are actually enabled and say so in the Getting
Started window, with a button to the right settings pane. Right now a new user
who misses that step sees nothing in Finder and assumes the app is broken.

### 3. Screenshots in the README

The whole pitch is visual and the README currently asks people to imagine it.

## Later

- **Git diff mode** — "copy only what changed" against `HEAD` or a branch
- **Exact token counts** — swap the chars÷4 heuristic for a real tokenizer
  behind the existing `TokenEstimating` protocol
- **Automatic chunking** — split output that exceeds a context window
- **Office documents** — `.docx`, `.pptx`, `.xlsx` text extraction
- **Archives** — read inside `.zip` / `.tar.gz` without unpacking
- **Drag-and-drop window** — drop files onto the menu bar icon
- **Standalone CLI release** — `llmcopy` already exists as a dev harness in
  `CopyForLLMCore`; it needs argument polish, a Homebrew formula, and docs
- **Raycast / Alfred / Keyboard Maestro** — thin frontends over the same engine
- **Global hotkey** — trigger from any app, not just Finder (needs Automation
  permission to read the Finder selection)
- **Mac App Store build** — requires replacing the extensions'
  `temporary-exception` entitlement with a real App Group and sandboxing the
  main app

## Not planned

- **Clipboard history.** Maccy, Raycast, and Paste already do this well, and
  storing full codebase dumps on disk is a privacy liability. "Re-copy Last
  Output" covers the real need.
- **Sending directly to an LLM.** Would mean API keys, network access, and a
  privacy story this app currently doesn't need — everything stays on your Mac.
