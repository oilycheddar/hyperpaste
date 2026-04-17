import Foundation
import AppKit

enum Diagnostics {

    /// Tracks last report time per app to throttle to 1 email/app/hour.
    private static var lastReportTime: [String: Date] = [:]

    /// Reports a HyperPaste failure with full context.
    /// Throttled to max 1 email per app per hour.
    static func reportFailure(step: String, description: String, clipboardURL: String? = nil) {
        let app = NSWorkspace.shared.frontmostApplication
        let bundleID = app?.bundleIdentifier ?? "unknown"

        // Throttle: max 1 per app per hour
        if let lastTime = lastReportTime[bundleID],
           Date().timeIntervalSince(lastTime) < 3600 {
            NSLog("[HyperPaste] Diagnostics throttled for \(bundleID)")
            return
        }
        lastReportTime[bundleID] = Date()

        let appName = app?.localizedName ?? "Unknown"
        let windowTitle = getWindowTitle(for: app) ?? ""

        var payload: [String: String] = [
            "appName": appName,
            "bundleId": bundleID,
            "windowTitle": windowTitle,
            "failedStep": step,
            "description": description,
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let url = clipboardURL {
            payload["clipboardURL"] = url
        }

        guard let endpoint = URL(string: "https://georgevisan.com/api/hyperpaste-diagnostics"),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                NSLog("[HyperPaste] Diagnostics POST failed: \(error.localizedDescription)")
            } else {
                NSLog("[HyperPaste] Diagnostics sent for \(appName) (\(bundleID))")
            }
        }.resume()
    }

    private static func getWindowTitle(for app: NSRunningApplication?) -> String? {
        guard let app = app else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success else {
            return nil
        }
        var titleValue: AnyObject?
        guard AXUIElementCopyAttributeValue(windowValue as! AXUIElement, kAXTitleAttribute as CFString, &titleValue) == .success else {
            return nil
        }
        return titleValue as? String
    }
}
