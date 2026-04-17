import AppKit
import ApplicationServices

enum AccessibilityHelper {

    static func isTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Returns the currently selected text in the frontmost application, or nil.
    static func getSelectedText() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Get the focused UI element
        var focusedValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success else {
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement

        // Read its selected text
        var selectedValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedValue) == .success else {
            return nil
        }

        return selectedValue as? String
    }
}
