import AppKit
import ApplicationServices

enum AccessibilityHelper {

    /// Set to `true` while we're synthesizing a Cmd+C to capture selected text.
    /// PasteInterceptor checks this to avoid recursion.
    static var isSynthesizing = false

    static func isTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Returns the currently selected text in the frontmost application, or nil.
    /// Tries the Accessibility API first; falls back to simulating Cmd+C for apps like Chrome.
    static func getSelectedText() -> String? {
        if let text = getSelectedTextViaAX(), !text.isEmpty {
            return text
        }

        NSLog("[HyperPaste] AX API returned nil, trying Cmd+C fallback")
        return getSelectedTextViaCopy()
    }

    // MARK: - AX API (fast path — native apps)

    private static func getSelectedTextViaAX() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var focusedValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success else {
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement

        var selectedValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedValue) == .success else {
            return nil
        }

        return selectedValue as? String
    }

    // MARK: - Cmd+C fallback (Chrome, Firefox, Electron apps)

    private static func getSelectedTextViaCopy() -> String? {
        let pasteboard = NSPasteboard.general
        let changeCountBefore = pasteboard.changeCount

        // Save current clipboard (the URL) so we can restore after our synthetic copy
        let saved = savePasteboardContents()

        isSynthesizing = true

        // Disable the event tap so our synthetic Cmd+C passes through to the target app
        EventTapManager.shared?.disable()

        // Simulate Cmd+C (keycode 8 = 'C')
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else {
            NSLog("[HyperPaste] Failed to create CGEvents for Cmd+C")
            EventTapManager.shared?.enable()
            isSynthesizing = false
            restorePasteboardContents(saved)
            return nil
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // Wait for the target app to process the copy
        usleep(150_000) // 150ms

        // Re-enable event tap
        EventTapManager.shared?.enable()
        isSynthesizing = false

        // Check if clipboard changed (Cmd+C succeeded)
        guard pasteboard.changeCount != changeCountBefore else {
            NSLog("[HyperPaste] Cmd+C fallback: clipboard didn't change (no selection?)")
            restorePasteboardContents(saved)
            return nil
        }

        let text = pasteboard.string(forType: .string)
        NSLog("[HyperPaste] Cmd+C fallback captured: \(text ?? "nil")")

        // Restore the original clipboard contents (the URL)
        restorePasteboardContents(saved)

        return text
    }

    // MARK: - Clipboard save/restore (private, separate from PasteboardManager)

    private static func savePasteboardContents() -> [[NSPasteboard.PasteboardType: Data]] {
        let pasteboard = NSPasteboard.general
        return pasteboard.pasteboardItems?.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        } ?? []
    }

    private static func restorePasteboardContents(_ items: [[NSPasteboard.PasteboardType: Data]]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        for dict in items {
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }
}
