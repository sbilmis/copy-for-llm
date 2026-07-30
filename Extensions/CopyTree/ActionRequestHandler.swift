import Foundation

// The principal class must (a) carry a stable @objc name matching
// NSExtensionPrincipalClass in project.yml, and (b) declare
// beginRequestWithExtensionContext: itself — ShareKit does not accept an
// inherited implementation. See Extensions/Shared/QuickActionRunner.swift.
@objc(CopyForLLMCopyTreeHandler)
final class ActionRequestHandler: NSObject, NSExtensionRequestHandling, @unchecked Sendable {

    @objc func beginRequest(with context: NSExtensionContext) {
        QuickActionRunner.begin(kind: .tree, context: context)
    }
}
