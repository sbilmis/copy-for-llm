import CopyForLLMCore
import SwiftUI

/// The flagship UI: live preview of the generated output with filters, formats,
/// templates, presets, stats, and search — then one click to copy.
struct OptionsView: View {

    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var session = OptionsSession()
    @State private var showingSavePreset = false
    @State private var newPresetName = ""
    @State private var justCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            selectionHeader
            controlsRow
            filtersRow
            preview
            statsBar
        }
        .padding(16)
        // Wide enough that the four pickers sit on one row without clipping.
        .frame(minWidth: 900, minHeight: 540)
        .onAppear {
            model.consumeHandoff()
            session.adopt(settings: model.settings)
            session.regenerate(roots: model.optionsRoots, settings: model.settings)
        }
        .onChange(of: model.optionsRoots) { regenerate() }
        .onChange(of: session.mode) { regenerate() }
        .onChange(of: session.format) { regenerate() }
        .onChange(of: session.templateID) { regenerate() }
        .onChange(of: session.includeGlobs) { regenerate() }
        .onChange(of: session.excludeGlobs) { regenerate() }
        .sheet(isPresented: $showingSavePreset) { savePresetSheet }
    }

    private func regenerate() {
        session.regenerate(roots: model.optionsRoots, settings: model.settings)
    }

    // MARK: Sections

    private var selectionHeader: some View {
        HStack {
            Image(systemName: "folder.badge.gearshape").foregroundStyle(.tint)
            Text(selectionSummary).lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("Change…") { chooseSelection() }
        }
        .font(.callout)
    }

    private var selectionSummary: String {
        let roots = model.optionsRoots
        switch roots.count {
        case 0: return "Nothing selected"
        case 1: return roots[0].path
        default: return "\(roots.count) items in \(roots[0].deletingLastPathComponent().path)"
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            Picker("Preset:", selection: Binding(
                get: { session.presetID },
                set: { id in
                    if let id, let preset = model.settings.presets.first(where: { $0.id == id }) {
                        session.apply(preset: preset, settings: model.settings)
                        regenerate()
                    } else {
                        session.presetID = nil
                    }
                }
            )) {
                Text("Custom").tag(UUID?.none)
                ForEach(model.settings.presets) { Text($0.name).tag(UUID?.some($0.id)) }
            }
            .fixedSize()

            Picker("Mode:", selection: $session.mode) {
                ForEach(OutputMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .fixedSize()

            Picker("Format:", selection: $session.format) {
                ForEach(OutputFormat.allCases) { Text($0.displayName).tag($0) }
            }
            .fixedSize()

            Picker("Template:", selection: $session.templateID) {
                Text("None").tag(UUID?.none)
                ForEach(model.settings.templates) { Text($0.name).tag(UUID?.some($0.id)) }
            }
            .fixedSize()

            Spacer(minLength: 0)
        }
    }

    private var filtersRow: some View {
        HStack(spacing: 12) {
            TextField("Include only:", text: $session.includeGlobs, prompt: Text("*.py *.md"))
                .frame(maxWidth: 220)
            TextField("Exclude:", text: $session.excludeGlobs, prompt: Text("tests/ *.lock"))
                .frame(maxWidth: 220)
            Spacer(minLength: 0)
            Button {
                OutputTextView.showFindBar()
            } label: {
                Label("Find", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            .help("Search within the generated output (⌘F)")
            Button("Save as Preset…") {
                newPresetName = ""
                showingSavePreset = true
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    @ViewBuilder
    private var preview: some View {
        if let message = session.errorMessage {
            ContentUnavailableView(
                "Nothing to Copy", systemImage: "doc.on.clipboard",
                description: Text(message)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            OutputTextView(text: Binding(
                get: { session.text },
                set: { session.overrideText($0) }
            ))
            .overlay(alignment: .center) {
                if session.isRunning {
                    ProgressView(label: {
                        if let progress = session.progress {
                            Text("Scanned \(progress.scanned) items…")
                        } else {
                            Text("Scanning…")
                        }
                    })
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
        }
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            if let report = session.report {
                Label("\(report.filesCopied) files", systemImage: "doc.text")
                Label("~\(RunReport.abbreviate(report.estimatedTokens)) tokens", systemImage: "number")
                Label("\(RunReport.abbreviate(report.totalChars)) chars", systemImage: "textformat.size")
                if report.skippedTotal > 0 {
                    Label("\(report.skippedTotal) skipped", systemImage: "eye.slash")
                        .help(report.skipped.prefix(15)
                            .map { "\($0.displayPath) — \($0.reason.rawValue)" }
                            .joined(separator: "\n"))
                }
                if report.wasTruncated {
                    Label("\(report.omittedByBudget.count) omitted by limits", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .help(report.omittedByBudget.prefix(15).joined(separator: "\n"))
                }
            }
            Spacer()
            if justCopied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
            Button("Copy to Clipboard") { copy() }
                .keyboardShortcut(.defaultAction)
                .disabled(session.text.isEmpty)
        }
        .font(.callout)
        .labelStyle(.titleAndIcon)
    }

    private var savePresetSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save Current Options as Preset").font(.headline)
            TextField("Preset name", text: $newPresetName)
                .frame(width: 260)
            HStack {
                Spacer()
                Button("Cancel") { showingSavePreset = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    model.settings.presets.append(
                        session.snapshotPreset(named: newPresetName.isEmpty ? "Untitled" : newPresetName)
                    )
                    model.save()
                    showingSavePreset = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPresetName.isEmpty)
            }
        }
        .padding(20)
    }

    // MARK: Actions

    private func copy() {
        let estimator = CharacterHeuristicEstimator(charsPerToken: model.settings.charsPerToken)
        var report = session.report ?? RunReport(
            filesCopied: 0, ignoredCount: 0, skipped: [], skippedTotal: 0,
            omittedByBudget: [], totalChars: 0, estimatedTokens: 0, duration: 0
        )
        report.totalChars = session.text.count
        report.estimatedTokens = estimator.estimateTokens(chars: session.text.count)
        model.copyToClipboard(GeneratedOutput(text: session.text, report: report))
        withAnimation { justCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            dismissWindow(id: "options")
        }
    }

    private func chooseSelection() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        model.optionsRoots = panel.urls
    }
}
