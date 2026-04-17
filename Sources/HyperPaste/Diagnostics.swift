import Foundation
import AppKit

enum Diagnostics {

    /// Tracks last report time per app to throttle to 1 email/app/hour.
    private static var lastReportTime: [String: Date] = [:]

    /// Reports a HyperPaste failure to the diagnostics endpoint.
    /// Throttled to max 1 email per app per hour.
    static func reportFailure(step: String, bundleID: String) {
        // Throttle: max 1 per app per hour
        if let lastTime = lastReportTime[bundleID],
           Date().timeIntervalSince(lastTime) < 3600 {
            NSLog("[HyperPaste] Diagnostics throttled for \(bundleID)")
            return
        }
        lastReportTime[bundleID] = Date()

        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"

        let payload: [String: String] = [
            "bundleId": bundleID,
            "osVersion": osVersion,
            "appVersion": appVersion,
            "failedStep": step,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        guard let url = URL(string: "https://georgevisan.com/api/hyperpaste-diagnostics"),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                NSLog("[HyperPaste] Diagnostics POST failed: \(error.localizedDescription)")
            } else {
                NSLog("[HyperPaste] Diagnostics sent for \(bundleID)")
            }
        }.resume()
    }
}
