import AppKit
import CopyForLLMCore
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {

    static let shared = AppModel()

    let store = SharedStore()
    var settings: AppSettings
    /// Selection for the Options window (from the Quick Action hand-off or Open…).
    var optionsRoots: [URL] = []

    private init() {
        settings = store.loadSettings()
    }

    func save() {
        try? store.saveSettings(settings)
    }

    /// Pulls a pending Quick Action selection out of the App Group container.
    func consumeHandoff() {
        guard let handoff = store.takeHandoff() else { return }
        optionsRoots = handoff.paths.map { URL(fileURLWithPath: $0) }
    }

    var hasLastOutput: Bool {
        store.loadLastOutput() != nil
    }

    /// Shows the open panel and adopts the chosen items as the Options selection.
    /// Returns false if the user cancelled.
    @discardableResult
    func chooseSelection() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Select"
        panel.message = "Choose files or a folder to prepare for an LLM."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return false }
        optionsRoots = panel.urls
        return true
    }

    @discardableResult
    func recopyLastOutput() -> Bool {
        guard let text = store.loadLastOutput() else { return false }
        ClipboardWriter.write(text)
        Notifier.post(title: "Copy for LLM", body: "Previous output copied again.")
        return true
    }

    func copyToClipboard(_ output: GeneratedOutput) {
        ClipboardWriter.write(output.text)
        try? store.saveLastOutput(output.text)
        if settings.showNotification {
            Notifier.post(title: output.report.summaryLine, body: output.report.detailLine)
        }
    }
}
