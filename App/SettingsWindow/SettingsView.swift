import CopyForLLMCore
import SwiftUI

struct SettingsView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView {
            GeneralTab(settings: $model.settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            IgnoreTab(settings: $model.settings)
                .tabItem { Label("Ignore Rules", systemImage: "eye.slash") }
            ExtractionTab(settings: $model.settings)
                .tabItem { Label("Documents", systemImage: "doc.viewfinder") }
            LimitsTab(settings: $model.settings)
                .tabItem { Label("Limits", systemImage: "gauge.with.needle") }
            TemplatesTab(settings: $model.settings)
                .tabItem { Label("Templates", systemImage: "text.quote") }
            PresetsTab(settings: $model.settings)
                .tabItem { Label("Presets", systemImage: "star") }
        }
        // Grouped is the standard macOS settings look, and it top-aligns the rows
        // instead of floating them in the middle of the window.
        .formStyle(.grouped)
        .frame(width: 640, height: 480)
        .onChange(of: model.settings) { model.save() }
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            Picker("Default format:", selection: $settings.defaultFormat) {
                ForEach(OutputFormat.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Copy Paths mode:", selection: $settings.defaultPathMode) {
                ForEach(PathMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Default template:", selection: $settings.defaultTemplateID) {
                Text("None").tag(UUID?.none)
                ForEach(settings.templates) { Text($0.name).tag(UUID?.some($0.id)) }
            }
            TextField("Characters per token:", value: $settings.charsPerToken,
                      format: .number.precision(.fractionLength(0...2)))
                .help("Used for the token estimate. ~4 for English and code.")
            Toggle("Show notification after copying", isOn: $settings.showNotification)
        }
        .padding(20)
    }
}

// MARK: - Ignore rules

private struct IgnoreTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Respect .gitignore files", isOn: $settings.respectGitignore)
            Toggle("Respect .llmignore files", isOn: $settings.respectLlmignore)

            Text("Always skip (gitignore syntax, one pattern per line):")
                .padding(.top, 6)
            TextEditor(text: lineListBinding($settings.ignoreRules))
                .font(.body.monospaced())
                .frame(minHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))

            HStack {
                TextField("Extra text file extensions (comma-separated):",
                          text: Binding(
                            get: { settings.extraTextExtensions.joined(separator: ", ") },
                            set: {
                                settings.extraTextExtensions = $0
                                    .components(separatedBy: ",")
                                    .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                                    .filter { !$0.isEmpty }
                            }
                          ))
                Spacer()
                Button("Restore Defaults") {
                    settings.ignoreRules = DefaultIgnoreRules.standard
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Documents, PDFs and images

private struct ExtractionTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Extract text from PDFs", isOn: $settings.extraction.pdf)
                Toggle("Read scanned PDF pages with OCR", isOn: $settings.extraction.ocrScannedPDFs)
                    .disabled(!settings.extraction.pdf)
                    .padding(.leading, 18)
                Toggle("Extract text from Word, PowerPoint, Excel and OpenDocument files",
                       isOn: $settings.extraction.richDocuments)
            }

            Section {
                Picker("Read text in images:", selection: $settings.extraction.ocr) {
                    ForEach(OCRMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("OCR quality:", selection: $settings.extraction.accurateOCR) {
                    Text("Accurate").tag(true)
                    Text("Fast").tag(false)
                }
                .disabled(settings.extraction.ocr == .off && !settings.extraction.ocrScannedPDFs)
            }

            Text("""
                 Recognition runs entirely on your Mac using Apple's Vision framework — \
                 nothing is uploaded and no API key is needed. Accurate is slower but \
                 handles photos and awkward layouts; Fast suits screenshots of text.

                 “Only files I select directly” keeps folder copies quick: images inside \
                 a folder are skipped, but an image you right-click is read.
                 """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }
}

// MARK: - Limits

private struct LimitsTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            OptionalIntField(label: "Maximum files:", value: $settings.limits.maxFiles)
            OptionalIntField(label: "Maximum characters:", value: $settings.limits.maxTotalChars)
            OptionalMBField(label: "Maximum total size (MB):", bytes: $settings.limits.maxTotalBytes)
            OptionalMBField(label: "Maximum single file size (MB):", bytes: $settings.limits.maxFileBytes)
            Text("When a limit is hit, remaining files are listed in the output as omitted and the notification says so.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

// MARK: - Templates

private struct TemplatesTab: View {
    @Binding var settings: AppSettings
    @State private var selectedID: UUID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(settings.templates, selection: $selectedID) { template in
                    Text(template.name).tag(template.id)
                }
                ListFooter(
                    onAdd: {
                        let template = Template(name: "New Template", text: "")
                        settings.templates.append(template)
                        selectedID = template.id
                    },
                    onRemove: {
                        settings.templates.removeAll { $0.id == selectedID }
                        selectedID = nil
                    },
                    removeDisabled: selectedID == nil
                )
            }
            .frame(minWidth: 160, maxWidth: 220)

            if let index = settings.templates.firstIndex(where: { $0.id == selectedID }) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name:", text: $settings.templates[index].name)
                    Text("Prepended to the output as instructions:")
                        .foregroundStyle(.secondary)
                    TextEditor(text: $settings.templates[index].text)
                        .font(.body)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
                }
                .padding(12)
            } else {
                ContentUnavailableView(
                    "No Template Selected", systemImage: "text.quote",
                    description: Text("Select or add a template.")
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Presets

private struct PresetsTab: View {
    @Binding var settings: AppSettings
    @State private var selectedID: UUID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(settings.presets, selection: $selectedID) { preset in
                    Text(preset.name).tag(preset.id)
                }
                ListFooter(
                    onAdd: {
                        let preset = Preset(name: "New Preset")
                        settings.presets.append(preset)
                        selectedID = preset.id
                    },
                    onRemove: {
                        settings.presets.removeAll { $0.id == selectedID }
                        selectedID = nil
                    },
                    removeDisabled: selectedID == nil
                )
            }
            .frame(minWidth: 160, maxWidth: 220)

            if let index = settings.presets.firstIndex(where: { $0.id == selectedID }) {
                PresetEditor(preset: $settings.presets[index], templates: settings.templates)
            } else {
                ContentUnavailableView(
                    "No Preset Selected", systemImage: "star",
                    description: Text("Presets bundle format, filters, and template into one favorite.")
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct PresetEditor: View {
    @Binding var preset: Preset
    let templates: [Template]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name:", text: $preset.name)
                Picker("Mode:", selection: $preset.mode) {
                    ForEach(OutputMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Format:", selection: $preset.format) {
                    ForEach(OutputFormat.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Template:", selection: $preset.templateID) {
                    Text("Default").tag(UUID?.none)
                    ForEach(templates) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Text("Include only (one glob per line, empty = everything):")
                    .padding(.top, 4)
                TextEditor(text: lineListBinding($preset.includeGlobs))
                    .font(.body.monospaced())
                    .frame(height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
                Text("Also exclude:")
                TextEditor(text: lineListBinding($preset.excludeGlobs))
                    .font(.body.monospaced())
                    .frame(height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
            }
            .padding(12)
        }
    }
}

private struct ListFooter: View {
    let onAdd: () -> Void
    let onRemove: () -> Void
    let removeDisabled: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onAdd) { Image(systemName: "plus") }
                .frame(width: 24, height: 24)
            Button(action: onRemove) { Image(systemName: "minus") }
                .frame(width: 24, height: 24)
                .disabled(removeDisabled)
            Spacer()
        }
        .buttonStyle(.borderless)
        .padding(4)
    }
}
