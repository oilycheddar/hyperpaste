import CoreGraphics
import AppKit

enum PasteInterceptor {

    /// Handles a key-down CGEvent. Returns the event to pass through, or nil to consume it.
    static func handleKeyEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Keycode 9 = 'V'. Require Command, reject if Control or Option also held
        // (Cmd+Shift+V is fine — some apps use it for paste-without-formatting)
        guard keycode == 9,
              flags.contains(.maskCommand),
              !flags.contains(.maskControl),
              !flags.contains(.maskAlternate) else {
            return Unmanaged.passUnretained(event)
        }

        NSLog("[HyperPaste] Cmd+V detected")

        // Is the clipboard a URL?
        guard let clipboardText = PasteboardManager.getPlainText() else {
            NSLog("[HyperPaste] No plain text on clipboard")
            return Unmanaged.passUnretained(event)
        }

        NSLog("[HyperPaste] Clipboard: \(clipboardText)")

        guard URLDetector.isURL(clipboardText) else {
            NSLog("[HyperPaste] Not a URL")
            return Unmanaged.passUnretained(event)
        }

        NSLog("[HyperPaste] URL detected")

        // Is there selected text in the frontmost app?
        guard let selectedText = AccessibilityHelper.getSelectedText(),
              !selectedText.isEmpty else {
            NSLog("[HyperPaste] No selected text")
            return Unmanaged.passUnretained(event)
        }

        NSLog("[HyperPaste] Selected text: \(selectedText)")

        // Both conditions met — create a hyperlink
        let url = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save clipboard, write hyperlink, let Cmd+V proceed, then restore
        PasteboardManager.saveState()
        RichTextBuilder.writeHyperlink(text: selectedText, url: url)

        // Restore clipboard after the paste has been processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            PasteboardManager.restoreState()
        }

        return Unmanaged.passUnretained(event)
    }
}
