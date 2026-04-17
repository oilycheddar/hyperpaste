import CoreGraphics
import AppKit

enum PasteInterceptor {

    /// Handles a key-down CGEvent. Returns the event to pass through, or nil to consume it.
    static func handleKeyEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        // Guard against recursive events from our own Cmd+C simulation
        guard !AccessibilityHelper.isSynthesizing else {
            return Unmanaged.passUnretained(event)
        }

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
            NSLog("[HyperPaste] No selected text (AX + Cmd+C fallback both failed)")
            let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
            if !isPlainTextApp(bundleID) {
                Diagnostics.reportFailure(step: "selected_text", bundleID: bundleID)
            }
            return Unmanaged.passUnretained(event)
        }

        NSLog("[HyperPaste] Selected text: \(selectedText)")

        // Both conditions met — create a hyperlink
        let url = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save clipboard, write hyperlink, let Cmd+V proceed, then restore
        PasteboardManager.saveState()
        RichTextBuilder.writeHyperlink(text: selectedText, url: url)

        // App-aware restore delay: Chromium apps need more time to read the clipboard
        let delay: Double = isChromiumApp() ? 0.75 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            PasteboardManager.restoreState()
        }

        return Unmanaged.passUnretained(event)
    }

    private static func isChromiumApp() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        let chromiumIDs = [
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "com.vivaldi.Vivaldi",
            "com.operasoftware.Opera",
            "org.chromium.Chromium"
        ]
        return chromiumIDs.contains(bundleID)
    }

    private static func isPlainTextApp(_ bundleID: String) -> Bool {
        let plainTextApps = [
            "com.apple.Terminal",
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92",  // Cursor
            "dev.warp.Warp-Stable",
            "com.googlecode.iterm2",
            "co.zeit.hyper",
            "com.sublimetext.4",
            "com.sublimetext.3",
            "org.vim.MacVim",
            "com.panic.Nova",
            "com.barebones.bbedit",
        ]
        return plainTextApps.contains(bundleID)
    }
}
