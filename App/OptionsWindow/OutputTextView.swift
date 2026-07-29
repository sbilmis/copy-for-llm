import AppKit
import SwiftUI

/// Editable monospaced preview backed by NSTextView so the system find bar
/// (⌘F) works — that's the "search within output" feature.
struct OutputTextView: NSViewRepresentable {

    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }

    /// Pops the find bar open, as if the user pressed ⌘F.
    static func showFindBar() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView
                ?? NSApp.keyWindow?.contentView?.firstTextView() else { return }
        NSApp.keyWindow?.makeFirstResponder(textView)
        textView.performFindPanelAction(NSMenuItem())
    }
}

private extension NSView {
    func firstTextView() -> NSTextView? {
        if let textView = self as? NSTextView { return textView }
        for subview in subviews {
            if let found = subview.firstTextView() { return found }
        }
        return nil
    }
}
