import Foundation
import CoreGraphics

class EventTapManager {
    /// Shared instance so AccessibilityHelper can disable/enable the tap during Cmd+C fallback.
    static var shared: EventTapManager?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    NSLog("[HyperPaste] Event tap was disabled by \(type == .tapDisabledByTimeout ? "timeout" : "user"), re-enabling...")
                    // proxy is CGEventTapProxy, need the CFMachPort to re-enable
                    // Re-enable is handled by the manager via a timer
                    return Unmanaged.passUnretained(event)
                }

                guard type == .keyDown else {
                    return Unmanaged.passUnretained(event)
                }

                return PasteInterceptor.handleKeyEvent(event)
            },
            userInfo: nil
        )

        guard let eventTap = eventTap else {
            NSLog("[HyperPaste] Failed to create event tap. Grant Accessibility permission in System Settings.")
            return
        }

        NSLog("[HyperPaste] Event tap created successfully")
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        NSLog("[HyperPaste] Event tap enabled and running")
    }

    func enable() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func disable() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }
}
