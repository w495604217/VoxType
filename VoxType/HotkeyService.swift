// HotkeyService.swift
// Global hotkey: configurable key + dual capture (CGEventTap + NSEvent)

import Foundation
import CoreGraphics
import AppKit

final class HotkeyService: @unchecked Sendable {

    /// Hotkey trigger callback
    var onToggle: (() -> Void)?

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var thread: Thread?
    private var nsEventMonitor: Any?

    /// Current target keyCode (can be changed at runtime)
    var targetKeyCode: UInt16 = 67  // default: numpad *

    /// Whether Accessibility permission is granted
    var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Human-readable name for the current hotkey
    var hotkeyDisplayName: String {
        Self.keyCodeToName(targetKeyCode)
    }

    func start() {
        // Layer 1: CGEventTap — native hardware keyboard events (requires Accessibility)
        if AXIsProcessTrusted() {
            thread = Thread { [weak self] in
                self?.setupEventTap()
                RunLoop.current.run()
            }
            thread?.name = "VoxType.HotkeyService"
            thread?.start()
        } else {
            print("[VoxType] Accessibility not granted — CGEventTap skipped, using NSEvent only")
        }

        // Layer 2: NSEvent global monitor — works without Accessibility for most keys
        setupNSEventMonitor()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        thread?.cancel()

        if let monitor = nsEventMonitor {
            NSEvent.removeMonitor(monitor)
            nsEventMonitor = nil
        }
    }

    /// Restart listeners (call after changing targetKeyCode)
    func restart() {
        stop()
        // Small delay to let old runloop tear down
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.start()
        }
    }

    // MARK: - Layer 1: CGEventTap

    private func setupEventTap() {
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: refcon
        ) else {
            print("[VoxType] CGEventTap failed — Accessibility permission not granted")
            print("[VoxType] System Settings → Privacy & Security → Accessibility → enable VoxType")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[VoxType] CGEventTap bound to keyCode \(targetKeyCode) (\(hotkeyDisplayName))")
    }

    // MARK: - Layer 2: NSEvent

    private func setupNSEventMonitor() {
        nsEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            guard let self else { return }

            let keyCode = event.keyCode

            let isTarget = keyCode == self.targetKeyCode
                || (event.characters == "*" && event.modifierFlags.contains(.numericPad) && self.targetKeyCode == 67)

            if isTarget {
                self.triggerWithDebounce()
            }
        }

        print("[VoxType] NSEvent monitor active (Synergy/KVM layer)")
    }

    // MARK: - Debounce

    fileprivate var lastTriggerTime: UInt64 = 0
    private let debounceNanos: UInt64 = 300_000_000 // 300ms

    fileprivate func triggerWithDebounce() {
        let now = DispatchTime.now().uptimeNanoseconds
        if now - lastTriggerTime < debounceNanos { return }
        lastTriggerTime = now
        onToggle?()
    }

    // MARK: - Key name mapping

    static func keyCodeToName(_ keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "Tab", 49: "Space", 50: "`", 51: "Delete",
            53: "Escape",
            65: "Numpad .", 67: "Numpad *", 69: "Numpad +",
            71: "Numpad Clear", 75: "Numpad /", 76: "Numpad Enter",
            78: "Numpad -",
            82: "Numpad 0", 83: "Numpad 1", 84: "Numpad 2", 85: "Numpad 3",
            86: "Numpad 4", 87: "Numpad 5", 88: "Numpad 6", 89: "Numpad 7",
            91: "Numpad 8", 92: "Numpad 9",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15", 114: "Help",
            115: "Home", 116: "Page Up", 117: "Forward Delete",
            118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
            123: "Left Arrow", 124: "Right Arrow",
            125: "Down Arrow", 126: "Up Arrow",
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }
}

// MARK: - CGEventTap C callback

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
            let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
            if let tap = service.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

    if let refcon = refcon {
        let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
        if keyCode == service.targetKeyCode {
            service.triggerWithDebounce()
            return nil // swallow the key
        }
    }

    return Unmanaged.passRetained(event)
}
