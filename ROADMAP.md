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

## Next

### 1. PowerPoint and Excel

The one real gap left. `.pptx` / `.xlsx` / `.epub` have no native macOS text
extraction. Options, in preference order:

- **Pandoc** — a single self-contained Homebrew binary, no Python environment.
  Shell out when present, degrade gracefully when absent.
- **MarkItDown** — wider format list, but needs Python plus `pip install`.
- **Native ZIP+XML parsing** — both are zipped XML; no dependency, but real work
  and ongoing maintenance.

Either external tool can only run from the **main app**, never the sandboxed
Quick Actions, so this belongs on the Options window path.

### 2. First-run extension check

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
