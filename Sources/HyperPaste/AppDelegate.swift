import AppKit
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventTapManager: EventTapManager?
    private var enableMenuItem: NSMenuItem!
    private var accessibilityTimer: Timer?
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        setupMenuBar()

        if !AccessibilityHelper.isTrusted() {
            showAccessibilityPrompt()
            startAccessibilityPolling()
        } else {
            startEventTap()
        }

        // Auto-open menu on first launch so the user sees where HyperPaste lives
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.statusItem.button?.performClick(nil)
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "link", accessibilityDescription: "HyperPaste")
        }

        let menu = NSMenu()

        enableMenuItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enableMenuItem.state = .on
        enableMenuItem.target = self
        menu.addItem(enableMenuItem)

        menu.addItem(NSMenuItem.separator())

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)

        let aboutItem = NSMenuItem(title: "About HyperPaste", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit HyperPaste", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        if enableMenuItem.state == .on {
            enableMenuItem.state = .off
            enableMenuItem.title = "Enable"
            eventTapManager?.disable()
        } else {
            enableMenuItem.state = .on
            enableMenuItem.title = "Enabled"
            eventTapManager?.enable()
        }
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let alert = NSAlert()
        alert.messageText = "HyperPaste"
        alert.informativeText = "Add a link to any text just like in Slack. Works in any app that supports rich text, like Gmail, Apple Notes, Google Docs, Notion, and Outlook.\n\nVersion \(version)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func startEventTap() {
        eventTapManager = EventTapManager()
        EventTapManager.shared = eventTapManager
        eventTapManager?.start()
    }

    private func startAccessibilityPolling() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if AccessibilityHelper.isTrusted() {
                self?.accessibilityTimer?.invalidate()
                self?.accessibilityTimer = nil
                self?.startEventTap()
                NSLog("[HyperPaste] Accessibility granted, event tap started")
            }
        }
    }

    private func showAccessibilityPrompt() {
        let alert = NSAlert()
        alert.messageText = "HyperPaste needs Accessibility permission"
        alert.informativeText = "To read selected text and create hyperlinks when you paste, HyperPaste needs Accessibility access.\n\nClick \"Open Settings\" to grant permission."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AccessibilityHelper.requestAccess()
        }
    }
}
