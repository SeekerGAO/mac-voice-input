import ApplicationServices
import Foundation

final class HotkeyMonitor {
    var onActivationPressed: (@Sendable () -> Void)?
    var onActivationReleased: (@Sendable () -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isActivationDown = false
    private(set) var isMonitoringAvailable = false
    private(set) var activationHotkey: ActivationHotkey = .fn

    func start(activationHotkey: ActivationHotkey = .fn) {
        guard eventTap == nil else { return }
        self.activationHotkey = activationHotkey
        let mask = (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo!).takeUnretainedValue()
            return monitor.handleEvent(proxy: proxy, type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            isMonitoringAvailable = false
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        isMonitoringAvailable = true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        isActivationDown = false
        isMonitoringAvailable = false
    }

    func refresh(activationHotkey: ActivationHotkey? = nil) {
        let nextHotkey = activationHotkey ?? self.activationHotkey
        stop()
        start(activationHotkey: nextHotkey)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == activationHotkey.keyCode else {
            return Unmanaged.passUnretained(event)
        }

        let isActive = event.flags.contains(activationHotkey.activeFlag)
        if isActive, !isActivationDown {
            isActivationDown = true
            let handler = onActivationPressed
            DispatchQueue.main.async {
                handler?()
            }
        } else if !isActive, isActivationDown {
            isActivationDown = false
            let handler = onActivationReleased
            DispatchQueue.main.async {
                handler?()
            }
        }

        return nil
    }
}
