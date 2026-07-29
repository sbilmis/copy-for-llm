import AppKit
import CopyForLLMCore
import UniformTypeIdentifiers
import UserNotifications

enum QuickActionKind {
    case copyDefault
    case tree
    case paths
    case options
}

/// Shared no-UI Quick Action handler. Each extension target subclasses this
/// as `ActionRequestHandler` and overrides `kind`.
/// Stateless, hence the unchecked Sendable.
class CopyActionHandler: NSObject, NSExtensionRequestHandling, @unchecked Sendable {

    var kind: QuickActionKind { .copyDefault }

    func beginRequest(with context: NSExtensionContext) {
        nonisolated(unsafe) let providers = context.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }

        nonisolated(unsafe) let context = context
        Task {
            let urls = await Self.fileURLs(from: providers)
            guard !urls.isEmpty else {
                context.cancelRequest(withError: CocoaError(.userCancelled))
                return
            }
            await self.perform(urls: urls)
            context.completeRequest(returningItems: nil)
        }
    }

    static func fileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers
        where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
            if let url = item as? URL {
                urls.append(url)
            } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                urls.append(url)
            } else if let string = item as? String, let url = URL(string: string), url.isFileURL {
                urls.append(url)
            }
        }
        return urls
    }

    func perform(urls: [URL]) async {
        // Sandboxed extension: the provider URLs carry implicit security scope.
        let accessed = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer { accessed.forEach { $0.stopAccessingSecurityScopedResource() } }

        let store = SharedStore()
        let settings = store.loadSettings()

        if case .options = kind {
            try? store.writeHandoff(SelectionHandoff(paths: urls.map(\.path)))
            await MainActor.run {
                if let url = URL(string: "copyforllm://options") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        let defaultPreset = settings.presets.first { $0.id == settings.defaultPresetID }
        var request: CopyRequest
        switch kind {
        case .tree:
            request = settings.request(roots: urls, mode: .tree)
            request.format = .plain
        case .paths:
            request = settings.request(roots: urls, mode: .paths)
        default:
            request = settings.request(roots: urls, mode: .auto, preset: defaultPreset)
        }

        do {
            let output = try await CopyPipeline.run(request)
            await MainActor.run { ClipboardWriter.write(output.text) }
            try? store.saveLastOutput(output.text)
            if settings.showNotification {
                await ExtensionFeedback.notify(
                    title: output.report.summaryLine, body: output.report.detailLine
                )
            }
        } catch {
            await ExtensionFeedback.notify(
                title: "Copy for LLM", body: error.localizedDescription
            )
        }
    }
}

enum ExtensionFeedback {

    /// User notification when permitted, success sound as fallback.
    static func notify(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else {
            _ = await MainActor.run { NSSound(named: "Glass")?.play() }
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        if !body.isEmpty { content.body = body }
        try? await center.add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}
