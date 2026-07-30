import Foundation

// Exposed to Objective-C under a stable, module-independent name so the
// extension's NSExtensionPrincipalClass can reference it directly.
@objc(CopyForLLMCopyDefaultHandler)
final class ActionRequestHandler: CopyActionHandler, @unchecked Sendable {
    override var kind: QuickActionKind { .copyDefault }
}
