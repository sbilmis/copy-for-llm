import CopyForLLMCore
import SwiftUI

/// Placeholder shell — the full live-preview Options UI lands in M4.
struct OptionsView: View {

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selection").font(.headline)
            List(model.optionsRoots, id: \.self) { url in
                Label(url.path, systemImage: "folder")
            }
            .frame(minHeight: 120)
            Button("Copy with Current Defaults") {
                Task {
                    let request = model.settings.request(roots: model.optionsRoots, mode: .auto)
                    if let output = try? await CopyPipeline.run(request) {
                        model.copyToClipboard(output)
                    }
                }
            }
            .disabled(model.optionsRoots.isEmpty)
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 300)
        .onAppear { model.consumeHandoff() }
    }
}
