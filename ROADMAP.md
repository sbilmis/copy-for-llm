# Roadmap

Ordered by priority. Everything here is a frontend or a plug-in point over
`CopyForLLMCore` — see [DEVELOPING.md](DEVELOPING.md) for the architecture.

## Next

### 1. OCR and PDF text extraction

Right-click a screenshot or a PDF and get its **text** on the clipboard instead
of a binary file that's currently skipped outright. This is the priority
feature: it turns "unusable blob" into usable context, and text costs a fraction
of the tokens an image does when pasted into a multimodal model.

- Images (`.png`, `.jpg`, `.heic`, …) via Vision's `VNRecognizeTextRequest`
- PDFs via PDFKit, falling back to Vision for scanned pages with no text layer
- Mixed selections should work — OCR the images, read the code, one clipboard

Design note: the pipeline already has the seam for this. `FileScanner` currently
rejects these by extension and by binary sniffing, and `CopyPipeline` reads
files with `Data(contentsOf:)` + `EncodingDetector`. Introduce a
`ContentExtractor` protocol with a plain-text default, and register OCR/PDF
extractors for the relevant UTIs. The formatters and budget layer need no
changes.

Open questions: OCR is slow enough to need progress reporting and a per-file
timeout; the Quick Action's memory ceiling may push large PDFs to the Options
window path; and OCR quality should probably be a setting (fast vs. accurate).

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
