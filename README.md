# Copy for LLM

Select files or folders in Finder, right-click, and get a clean, LLM-ready dump of your
project on the clipboard — directory tree plus file contents, filtered and budgeted.

Tools like [repomix](https://github.com/yamadashy/repomix) do this from a terminal.
Copy for LLM does it from the Finder context menu, with no terminal, no config file,
and no window to keep open.

```text
project/
├── README.md
├── pyproject.toml
├── src/
│   ├── main.py
│   └── util.py
└── docs/
    └── guide.md
```

…followed by the contents of every file, in the format your model likes best.

## Install

Download the latest `.dmg` from [Releases](../../releases), drag the app to
`/Applications`, and **launch it once**. Then enable the Quick Actions in
**System Settings → General → Login Items & Extensions → Finder Quick Actions**.

Or with Homebrew:

```bash
brew install --cask copy-for-llm
```

## The four Quick Actions

| Action | What it copies |
| --- | --- |
| **Copy for LLM** | Folders → tree + contents. Files → contents. Uses your saved defaults. |
| **Copy Tree for LLM** | The directory tree only. |
| **Copy Paths** | Absolute, relative, or filename-only paths. |
| **Copy for LLM (Options…)** | Opens the Options window: live preview, filters, formats, templates. |

Each one can be given a keyboard shortcut in System Settings → Keyboard → Keyboard
Shortcuts → Services.

## Output formats

- **Markdown** (default) — `## path` headings with language-hinted code fences.
- **XML** — `<file_tree>` and `<document path=…>` tags, following Claude prompt conventions.
- **Plain** — `===== path =====` separators.
- **JSON** — for API pipelines.

## What gets skipped

Rules are evaluated in this order, and **the first one that matches wins**:

1. **Your exclude globs** — always win. Nothing overrides an exclude.
2. **Your include globs** — when set, only matching files are copied, and a match
   overrides every rule below.
3. **`.llmignore`** — same syntax as `.gitignore`, for LLM-specific exclusions.
4. **`.gitignore`** — respected by default, including nested files and `!` negations.
5. **Built-in defaults** — `node_modules/`, `venv/`, `__pycache__/`, build output,
   images, archives, and credentials (`.env`, `*.pem`, `id_rsa*`). Fully editable
   in Settings.

Beyond the rules, binary files are detected and skipped by content (not just by
extension), symlinks are never followed, and text is decoded via BOM detection →
UTF-8 → Latin-1.

Files you select **directly** bypass the ignore rules — if you explicitly right-click
`debug.log`, you meant it.

## Size limits

Defaults are 1000 files, 4M characters, 10 MB total, 1 MB per file. When a limit is
hit you still get output, the omitted files are listed at the end, and the
notification tells you it was truncated. All four limits are configurable, and the
Options window shows a live token estimate so you know what you're pasting.

## Building from source

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
make bootstrap   # installs XcodeGen, generates CopyForLLM.xcodeproj
make test        # runs the CopyForLLMCore unit tests
make install     # builds and installs to /Applications
```

`CopyForLLM.xcodeproj` is generated and git-ignored — edit
[`project.yml`](project.yml) instead and re-run `make generate`.

There is also a CLI harness over the same engine:

```bash
cd CopyForLLMCore && swift run llmcopy ~/some/project --format xml --report
```

## Architecture

All logic lives in `CopyForLLMCore`, a dependency-free Swift package:

```
Scanning/   FileScanner — walks roots, applies rules, builds the tree
Ignore/     GlobMatcher, GitignoreParser, IgnoreEngine (layered, per-directory)
Content/    EncodingDetector, LanguageMap
Format/     TreeRenderer + Plain/Markdown/XML/JSON formatters
Budget/     Limits, BudgetEnforcer, TokenEstimator
Pipeline/   CopyPipeline — scan → budget → decode → format
Config/     AppSettings, Preset, Template, SharedStore
```

The app, the four Quick Action extensions, and the CLI are all thin frontends over
`CopyPipeline.run(_:)`. Adding a Raycast script, an Alfred workflow, or a real
tokenizer means writing a new frontend or swapping one protocol implementation —
not touching the engine.

## Roadmap

PDF and Office text extraction, git-diff mode ("copy changed files only"), real
tokenizer-based counts, automatic chunking, archive support, and a standalone CLI
release. The `TokenEstimating` protocol and the pipeline's content-extraction seam
are the intended extension points.

## License

MIT — see [LICENSE](LICENSE).
