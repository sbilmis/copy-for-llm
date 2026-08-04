# Copy for LLM

Right-click a folder in Finder. Get your whole project on the clipboard, formatted
for Claude, ChatGPT, or Gemini: directory tree, file contents, junk filtered out.

No terminal. No config file. No app window to keep open.

![Right-clicking a project folder in Finder, choosing Copy for LLM from the
Quick Actions submenu, then pasting into Claude, which reports three policy
violations and a SQL injection](docs/images/demo.gif)

The folder above contains a `.env` full of API keys, a `venv/`, and a
`server.log`. None of them were copied. The PDF in `docs/` was, as text.

```text
project/
├── README.md
├── src/
│   ├── main.py
│   └── util.py
└── docs/
    └── guide.md
```

…followed by the contents of every file, in the format your model likes best.

Need more control? **Copy for LLM (Options…)** previews the output first, with
filters and a live token count:

![The Options window: a live preview of the generated output, with format and
filter controls and a running file, token and character count](docs/images/options-window.png)

## Install

1. Download the latest `.dmg` from [Releases](../../releases) and drag the app to
   **Applications**
2. **Launch it once.** This registers the right-click actions
3. Turn them on in **System Settings → General → Login Items & Extensions →
   Finder Quick Actions**

That third step is required, and it's easy to miss. Without it nothing appears in
Finder.

## Use it

Select files or a folder in Finder, right-click, and open the
**Quick Actions ▸** submenu:

| Action | What lands on your clipboard |
| --- | --- |
| **Copy for LLM** | A folder → tree + every file's contents. Files → their contents. |
| **Copy Tree for LLM** | Just the directory tree. |
| **Copy Paths** | The file paths. |
| **Copy for LLM (Options…)** | Opens a window to preview and tweak before copying. |

Then paste into your chat. A notification tells you what you got, such as
*"Copied 47 files (~85k tokens)"*, so you know whether it fits before you paste.

**Keyboard shortcut:** System Settings → Keyboard → Keyboard Shortcuts… →
Services → Files and Folders → **Copy for LLM**. Click to the right of the name
and press your combination (`⌃⌥⌘C` works well). macOS doesn't let apps ship a
default, so this is a one-time setup.

**Menu bar icon:** Copy for LLM has no Dock icon. The clipboard icon in your menu
bar opens Settings, the Options window, or a file picker if you'd rather not use
Finder. Opening the app itself brings up this window:

![The Getting Started window, explaining the three setup steps and offering a
Choose Files or Folder button](docs/images/getting-started.png)

## PDFs, slides and screenshots become text

Turn on **Settings → Documents** and PDFs, Word documents, PowerPoint decks,
Excel sheets and screenshots copy as their *text* instead of being skipped as
binary. Scanned PDFs and images are read with OCR.

All of it runs on your Mac, using Apple's Vision framework for OCR and a native
parser for Office files. Nothing is uploaded, no API key is needed, and it works
offline. Extracted text also costs a fraction of the tokens an image does.

![The Documents settings tab, with switches for PDF extraction, OCR of scanned
pages, Office documents, and a picker controlling when images are read](docs/images/settings-documents.png)

## Junk is skipped automatically

`node_modules`, `venv`, `__pycache__`, build output, images, archives, and
anything in your `.gitignore`. Credentials like `.env` and `*.pem` are never
copied. Binary files are detected and skipped by content, not just extension.

All of it is editable in Settings, and you can add your own include/exclude
patterns. Full details in the [User Guide](MANUAL.md).

## Too big to paste?

Defaults cap a copy at 1000 files / 4M characters / 10 MB. Hit a limit and you
still get output. The skipped files are listed at the end and the notification
says it was truncated. Use **Options…** to filter down and watch the token
estimate update live.

## Documentation

- **[User Guide](MANUAL.md)**: output formats, filters, presets, prompt
  templates, troubleshooting
- **[DEVELOPING.md](DEVELOPING.md)**: building from source, architecture,
  release process

## Roadmap

Next up: git-diff mode ("copy only what changed"), exact tokenizer counts, and
archive support. See [ROADMAP.md](ROADMAP.md).

Requires macOS 14 or later. MIT licensed; see [LICENSE](LICENSE).
