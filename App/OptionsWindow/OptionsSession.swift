import CopyForLLMCore
import Foundation
import Observation

/// Drives the Options window: holds the knobs, re-runs the pipeline when they
/// change, and exposes live progress + the editable result.
@MainActor
@Observable
final class OptionsSession {

    var mode: OutputMode = .auto
    var format: OutputFormat = .markdown
    var templateID: UUID?
    var presetID: UUID?
    var includeGlobs = ""
    var excludeGlobs = ""
    var maxFiles: Int?
    var maxTotalChars: Int?
    var maxTotalBytes: Int64?

    private(set) var text = ""
    private(set) var report: RunReport?
    private(set) var progress: ScanProgress?
    private(set) var isRunning = false
    private(set) var errorMessage: String?

    private var generation = 0
    private var runningTask: Task<Void, Never>?

    /// Manual edits in the preview replace the generated text until the next regenerate.
    func overrideText(_ newText: String) {
        text = newText
    }

    func adopt(settings: AppSettings) {
        format = settings.defaultFormat
        templateID = settings.defaultTemplateID
        maxFiles = settings.limits.maxFiles
        maxTotalChars = settings.limits.maxTotalChars
        maxTotalBytes = settings.limits.maxTotalBytes
    }

    func apply(preset: Preset, settings: AppSettings) {
        presetID = preset.id
        mode = preset.mode
        format = preset.format
        includeGlobs = preset.includeGlobs.joined(separator: " ")
        excludeGlobs = preset.excludeGlobs.joined(separator: " ")
        if let limits = preset.limits {
            maxFiles = limits.maxFiles
            maxTotalChars = limits.maxTotalChars
            maxTotalBytes = limits.maxTotalBytes
        }
        if let template = preset.templateID { templateID = template }
    }

    func snapshotPreset(named name: String) -> Preset {
        Preset(
            name: name, mode: mode, format: format,
            includeGlobs: Self.parseGlobs(includeGlobs),
            excludeGlobs: Self.parseGlobs(excludeGlobs),
            limits: Limits(maxFiles: maxFiles, maxTotalChars: maxTotalChars,
                           maxTotalBytes: maxTotalBytes),
            templateID: templateID
        )
    }

    func request(roots: [URL], settings: AppSettings) -> CopyRequest {
        var ignore = settings.ignoreConfiguration
        ignore.includeGlobs = Self.parseGlobs(includeGlobs)
        ignore.excludeGlobs = Self.parseGlobs(excludeGlobs)
        var limits = settings.limits
        limits.maxFiles = maxFiles
        limits.maxTotalChars = maxTotalChars
        limits.maxTotalBytes = maxTotalBytes
        return CopyRequest(
            roots: roots, mode: mode, format: format,
            pathMode: settings.defaultPathMode,
            template: settings.template(id: templateID)?.text,
            ignore: ignore, limits: limits,
            extraTextExtensions: Set(settings.extraTextExtensions),
            charsPerToken: settings.charsPerToken
        )
    }

    func regenerate(roots: [URL], settings: AppSettings) {
        runningTask?.cancel()
        generation += 1
        let generation = generation
        guard !roots.isEmpty else {
            text = ""
            report = nil
            return
        }
        isRunning = true
        errorMessage = nil
        let request = request(roots: roots, settings: settings)

        runningTask = Task { [weak self] in
            // Small debounce so typing in a glob field doesn't rescan per keystroke.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            do {
                let output = try await CopyPipeline.run(request) { progress in
                    Task { @MainActor in
                        guard self.generation == generation else { return }
                        self.progress = progress
                    }
                }
                guard !Task.isCancelled, self.generation == generation else { return }
                self.text = output.text
                self.report = output.report
                self.isRunning = false
            } catch is CancellationError {
            } catch {
                guard self.generation == generation else { return }
                if case CopyPipelineError.nothingToCopy(let report) = error {
                    self.report = report
                }
                self.text = ""
                self.errorMessage = error.localizedDescription
                self.isRunning = false
            }
        }
    }

    static func parseGlobs(_ field: String) -> [String] {
        field.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
    }
}
