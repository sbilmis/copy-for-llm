import AppKit
import CopyForLLMCore
import SwiftUI

struct WelcomeView: View {

    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Copy for LLM").font(.title.bold())
                    Text("Prepare project context for LLMs, straight from Finder.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Select files or folders in Finder, right-click, and choose **Quick Actions → Copy for LLM**.")
                } icon: {
                    Image(systemName: "1.circle.fill").foregroundStyle(.tint)
                }
                Label {
                    Text("If the actions don't appear, enable them in **System Settings → General → Login Items & Extensions → Finder Quick Actions**.")
                } icon: {
                    Image(systemName: "2.circle.fill").foregroundStyle(.tint)
                }
                Label {
                    Text("Paste into Claude, ChatGPT, Gemini — the output includes a directory tree and file contents.")
                } icon: {
                    Image(systemName: "3.circle.fill").foregroundStyle(.tint)
                }
                Label {
                    Text("No Dock icon — Copy for LLM lives in the menu bar. Use the clipboard icon there for options, settings, or to pick files without Finder.")
                } icon: {
                    Image(systemName: "menubar.arrow.up.rectangle").foregroundStyle(.tint)
                }
            }
            .labelStyle(.titleAndIcon)

            Divider()

            HStack {
                Button("Open Extension Settings…") {
                    let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
                    NSWorkspace.shared.open(url)
                }
                Button("Choose Files or Folder…") { chooseSelection() }
                Spacer()
                Button("Re-copy Last Output") { model.recopyLastOutput() }
                    .disabled(model.store.loadLastOutput() == nil)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func chooseSelection() {
        guard model.chooseSelection() else { return }
        openWindow(id: "options")
    }
}
