import AppKit
import CopyForLLMCore
import SwiftUI

@main
struct CopyForLLMApp: App {

    private static let hasLaunchedKey = "hasLaunchedBefore"

    @State private var model = AppModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // LSUIElement is set, so there is no Dock icon and no app menu bar —
        // this is the only always-available entry point to the app.
        MenuBarExtra {
            Button("Choose Files or Folder…") { chooseAndOpenOptions() }
                .keyboardShortcut("o")
            Button("Open Options Window") { openOptions() }
            Button("Re-copy Last Output") { model.recopyLastOutput() }
                .disabled(!model.hasLastOutput)
            Divider()
            Button("Settings…") { openSettings() }
                .keyboardShortcut(",")
            Button("Getting Started") { openWelcome() }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            // The label is built at launch, unlike the menu content, so this is
            // where first-run onboarding can be triggered.
            Image(systemName: "doc.on.clipboard")
                .task { showWelcomeOnFirstLaunch() }
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

    /// New users have no Finder selection yet and no reason to know the Quick
    /// Actions need enabling, so show the guide once.
    private func showWelcomeOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.hasLaunchedKey) else { return }
        defaults.set(true, forKey: Self.hasLaunchedKey)
        openWelcome()
    }

    private func openWelcome() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
    }

    private func chooseAndOpenOptions() {
        guard model.chooseSelection() else { return }
        openOptions()
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
