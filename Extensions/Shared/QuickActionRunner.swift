import AppKit
import CopyForLLMCore
import OSLog
import UniformTypeIdentifiers
import UserNotifications

enum QuickActionKind {
    case copyDefault
    case tree
    case paths
    case options
}

/// Shared implementation behind all four Quick Actions.
///
/// This is deliberately *not* a base class for the extensions' principal
/// objects: ShareKit requires `beginRequestWithExtensionContext:` to be
/// declared on the principal class itself, and an inherited implementation
/// leaves the extension context without a principal object at runtime. Each
/// target's `ActionRequestHandler` therefore implements the method directly
/// and forwards here.
enum QuickActionRunner {

    /// Carries AppKit types that predate `Sendable` across the task boundary.
    /// `nonisolated(unsafe)` locals are not portable across Swift versions here,
    /// so use an explicit box instead.
    private struct Unchecked<T>: @unchecked Sendable {
        let value: T
    }

    static func begin(kind: QuickActionKind, context: NSExtensionContext) {
        let providers = Unchecked(value: context.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] })
        let context = Unchecked(value: context)

        Task {
            let urls = await fileURLs(from: providers.value)
            guard !urls.isEmpty else {
                context.value.cancelRequest(withError: CocoaError(.userCancelled))
                return
            }
            await perform(kind: kind, urls: urls)
            context.value.completeRequest(returningItems: nil)
        }
    }

    static let log = Logger(subsystem: "app.copyforllm", category: "quickaction")

    static func fileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            log.debug("provider types: \(provider.registeredTypeIdentifiers.joined(separator: ", "))")
            if let url = await fileURL(from: provider) {
                urls.append(url)
            } else {
                log.error("no file URL from provider \(provider.registeredTypeIdentifiers)")
            }
        }
        return urls
    }

    /// Finder registers each attachment under the file's own UTI (a `.md` file
    /// arrives as `net.daringfireball.markdown`, not `public.file-url`), so
    /// filtering on one identifier drops the whole selection. Try the URL types
    /// first, then fall back to whatever the provider actually advertises.
    private static func fileURL(from provider: NSItemProvider) async -> URL? {
        var identifiers = [UTType.fileURL.identifier, UTType.url.identifier, UTType.item.identifier]
        identifiers.append(contentsOf: provider.registeredTypeIdentifiers)

        for identifier in identifiers {
            guard let item = try? await provider.loadItem(forTypeIdentifier: identifier) else { continue }
            if let url = item as? URL, url.isFileURL { return url }
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
                return url
            }
            if let string = item as? String,
               let url = URL(string: string), url.isFileURL {
                return url
            }
        }
        return nil
    }

    static func perform(kind: QuickActionKind, urls: [URL]) async {
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
