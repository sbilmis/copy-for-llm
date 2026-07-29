#if canImport(AppKit)
import AppKit

public enum ClipboardWriter {

    @MainActor
    public static func write(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
#endif
