import CopyForLLMCore
import SwiftUI

@main
struct CopyForLLMApp: App {

    @State private var model = AppModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Copy for LLM", id: "main") {
            WelcomeView()
                .environment(model)
                .onAppear { Notifier.requestPermissionIfNeeded() }
        }
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["main"])
        .commands {
            CommandGroup(after: .pasteboard) {
                Button("Re-copy Last Output") {
                    model.recopyLastOutput()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        Window("Copy for LLM — Options", id: "options") {
            OptionsView()
                .environment(model)
                .onOpenURL { _ in model.consumeHandoff() }
        }
        .handlesExternalEvents(matching: ["options"])

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
