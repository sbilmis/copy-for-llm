# Copy for LLM — User Guide

Everything the app can do. For a two-minute overview, see the [README](README.md).

## The four right-click actions

Select anything in Finder, right-click, open **Quick Actions ▸**.

**Copy for LLM** — the one you'll use most. On a folder you get the directory
tree followed by every text file's contents. On files you get just their
contents. Uses whatever defaults you've set.

**Copy Tree for LLM** — the tree alone. Good for asking "where should this new
file go?" without pasting a whole codebase.

**Copy Paths** — the file paths, as absolute paths, paths relative to the
enclosing folder, or bare filenames (Settings → General).

**Copy for LLM (Options…)** — opens a window instead of copying immediately.

## The Options window

Use this when the default copy is too big, or you want to shape it.

- **Preset** — a saved bundle of settings (see below)
- **Mode** — automatic, contents only, tree only, tree + contents, or paths
- **Format** — Markdown, XML, Plain, or JSON
- **Template** — a prompt prepended to the output
- **Include only / Exclude** — space-separated patterns, e.g. `*.py *.md`
- **Preview** — the actual output, editable before you copy. Press **⌘F** to
  search it.

The bar along the bottom shows file count, estimated tokens, character count,
and how many files were skipped or dropped. Hover any of those for the details.
Everything re-scans as you type, so you can watch the token count fall as you
filter.

## Output formats

**Markdown** (default) — `## path` headings with language-tagged code fences.
The best default for chat interfaces.

**XML** — `<file_tree>` and `<document path=…>` tags. Follows Claude's prompt
conventions and tends to work well for long contexts.

**Plain** — `===== path =====` separators. Smallest overhead, fewest tokens.

**JSON** — structured output for feeding an API rather than a chat window.

## What gets skipped, and in what order

Rules are checked in this order — **the first match wins**:

1. **Your exclude patterns** — always win, nothing overrides them
2. **Your include patterns** — when set, only matching files are copied, and a
   match here overrides everything below
3. **`.llmignore`** — same syntax as `.gitignore`, for LLM-specific exclusions
4. **`.gitignore`** — respected by default, including nested files and `!` rules
5. **Built-in defaults** — dependency folders, build output, media, archives,
   and credentials

Beyond those rules: binary files are detected by content (not just extension),
symlinks are never followed, and text is decoded as UTF-8 with a Latin-1
fallback.

**Files you select directly bypass all of it.** If you right-click `debug.log`
specifically, you meant it.

Patterns use `.gitignore` syntax: `*.log`, `build/`, `docs/*.md`, `**/temp`,
`!keep.log`.

## PDFs, images and Word documents

By default these are skipped as binary. Turn extraction on in
**Settings → Documents** and their text is copied like any source file:

- **PDFs** — the text layer, page by page. Scanned pages with no text layer are
  read with OCR.
- **Images** (`.png`, `.jpg`, `.heic`, …) — text read out of the picture, so a
  screenshot of an error message becomes text you can paste.
- **Word, RTF, OpenDocument** — the document's text.

**Images are handled carefully by default.** "Only files I select directly"
means an image you right-click is read, but images found while walking a folder
are skipped — otherwise copying a project with an assets directory would be slow
and mostly noise. Switch to "Always" if you want everything read.

**OCR quality**: Accurate is slower and handles photos and awkward layouts; Fast
suits clean screenshots of text.

All recognition runs on your Mac using Apple's Vision framework. Nothing is
uploaded, no API key is needed, and it works offline. Extracted text also costs
far fewer tokens than pasting the image into a multimodal model.

PowerPoint and Excel aren't supported yet — see [ROADMAP.md](ROADMAP.md).

## Presets

A preset saves mode, format, filters, limits, and template under one name. Four
ship with the app — Python Project, LaTeX Paper, Web Project, Configuration
Files — and you can edit them or add your own in Settings → Presets, or by
clicking **Save as Preset…** in the Options window.

Set a default preset in Settings and the plain **Copy for LLM** action will use
it.

## Prompt templates

A template is text prepended to the output, so a paste arrives with its
instruction already attached. Five ship with the app: Review Code, Find Security
Vulnerabilities, Explain Architecture, Refactor, Write Documentation. Edit them
or add your own in Settings → Templates.

## Size limits

Defaults: 1000 files, 4,000,000 characters, 10 MB total, 1 MB per file. Change
them in Settings → Limits; leave a field empty for no limit.

When a limit is hit you still get output. The omitted files are listed at the
end and the notification tells you it was truncated.

The token estimate is roughly characters ÷ 4, which is close for English and
code. Tune the divisor in Settings → General if your content differs.

## Re-copying

The most recent output is kept, so if you overwrite your clipboard you can get
it back: menu bar icon → **Re-copy Last Output**. Only the last one is stored —
this is deliberately not a clipboard history.

## Troubleshooting

**The actions don't appear in Finder.** Launch the app once, then check System
Settings → General → Login Items & Extensions → **Finder Quick Actions** and
make sure they're on. They live inside the **Quick Actions ▸** submenu, not at
the top level of the right-click menu.

**Each action appears twice.** You have two copies of the app — usually one in
`/Applications` and another elsewhere, such as a build folder or Downloads.
Delete the one you don't want.

**Nothing was copied.** If everything you selected was binary, ignored, or
empty, you'll get a notification saying so rather than a silent failure.

**The copy is enormous.** Use **Options…** and add include patterns, or lower
the limits in Settings.

**A file you wanted was skipped.** Check the skip count in the Options window
and hover it — it lists each file with the reason. Common causes: it's in
`.gitignore`, it matched a default rule, or it exceeded the 1 MB per-file cap.

## Privacy

Everything happens on your Mac. The app makes no network connections, collects
no analytics, and sends nothing anywhere. What reaches an LLM is only what you
paste yourself.
