import AppKit
import CopyForLLMCore
import SwiftUI

@main
struct CopyForLLMApp: App {

    @State private var model = AppModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // LSUIElement is set, so there is no Dock icon and no app menu bar —
        // this is the only always-available entry point to the app.
        MenuBarExtra("Copy for LLM", systemImage: "doc.on.clipboard") {
            Button("Copy for LLM…") { openOptions() }
                .keyboardShortcut("o")
            Button("Re-copy Last Output") { model.recopyLastOutput() }
                .disabled(!model.hasLastOutput)
            Divider()
            Button("Settings…") { openSettings() }
                .keyboardShortcut(",")
            Button("Getting Started") { openWindow(id: "main") }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }

        Window("Copy for LLM", id: "main") {
            WelcomeView()
                .environment(model)
                .onAppear { Notifier.requestPermissionIfNeeded() }
        }
        .windowResizability(.contentSize)

        Window("Copy for LLM — Options", id: "options") {
            OptionsView()
                .environment(model)
                // Re-read the selection when the Options… Quick Action fires
                // again while the window is already open.
                .onOpenURL { _ in model.consumeHandoff() }
        }
        .handlesExternalEvents(matching: ["options"])

        Settings {
            SettingsView()
                .environment(model)
        }
    }

    private func openOptions() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "options")
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
