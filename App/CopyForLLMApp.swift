import AppKit
import CopyForLLMCore
import SwiftUI

/// A menu-bar-only app (`LSUIElement`) gets no window when it is launched, and
/// AppKit sends no `open` event when an already-running one is opened again.
/// Both cases would otherwise leave the app with no visible response.
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Assigned by the scene once SwiftUI is able to open windows. Any request
    /// that arrived before then is replayed immediately.
    var showMainWindow: (() -> Void)? {
        didSet {
            guard pendingShow, showMainWindow != nil else { return }
            pendingShow = false
            showMainWindow?()
        }
    }

    private var pendingShow = false
    private var handledURL = false

    /// The Options… Quick Action launches us with a URL and opens its own window.
    func application(_ application: NSApplication, open urls: [URL]) {
        handledURL = true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `application(_:open:)` can arrive just after this, so wait a moment
        // before concluding this was a plain launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.handledURL else { return }
            self.requestMainWindow()
        }
    }

    /// Fires when the app is already running and the user opens it again.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        requestMainWindow()
        return true
    }

    private func requestMainWindow() {
        if let showMainWindow {
            showMainWindow()
        } else {
            pendingShow = true
        }
    }
}

@main
struct CopyForLLMApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // LSUIElement is set, so there is no Dock icon and no app menu bar —
        // this is the always-available entry point to the app.
        MenuBarExtra {
            Button("Choose Files or Folder…") { chooseAndOpenOptions() }
                .keyboardShortcut("o")
            Button("Open Options Window") { openOptions() }
            Button("Re-copy Last Output") { model.recopyLastOutput() }
                .disabled(!model.hasLastOutput)
            Divider()
            // SettingsLink, not NSApp.sendAction(showSettingsWindow:) — the latter
            // walks the responder chain, and an LSUIElement app has no main menu
            // for it to reach, so the Settings window never opened.
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")
            Button("Getting Started") { openWelcome() }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            // The label is built at launch, unlike the menu content, so this is
            // the earliest point the scene can hand a window opener to the delegate.
            Image(systemName: "doc.on.clipboard")
                .task { appDelegate.showMainWindow = { openWelcome() } }
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

}
