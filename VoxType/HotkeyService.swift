// HotkeyService.swift
// Global hotkey: 3-layer capture
//   Layer 1: CGEventTap (hardware, requires Accessibility)
//   Layer 2: NSEvent global monitor (Synergy/virtual keyboards)
//   Layer 3: IOHIDManager (raw USB HID, no permissions needed)

import Foundation
import CoreGraphics
import AppKit
import IOKit.hid

final class HotkeyService: @unchecked Sendable {

    /// Hotkey trigger callback
    var onToggle: (() -> Void)?

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var nsEventMonitor: Any?
    private var hidManager: IOHIDManager?
    private var hidThread: Thread?

    /// Current target keyCode (macOS virtual key code, can be changed at runtime)
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
        // Layer 1: CGEventTap — hardware keyboard (requires Accessibility)
        if AXIsProcessTrusted() {
            tapThread = Thread { [weak self] in
                self?.setupEventTap()
                RunLoop.current.run()
            }
            tapThread?.name = "VoxType.HotkeyService.EventTap"
            tapThread?.start()
        } else {
            print("[VoxType] Accessibility not granted — CGEventTap skipped")
        }

        // Layer 2: NSEvent global monitor — catches Synergy/virtual keyboard events
        setupNSEventMonitor()

        // Layer 3: IOHIDManager — raw USB/Bluetooth HID keyboard events (no permissions needed)
        hidThread = Thread { [weak self] in
            self?.setupHIDManager()
            RunLoop.current.run()
        }
        hidThread?.name = "VoxType.HotkeyService.HID"
        hidThread?.start()
    }

    func stop() {
        // Tear down Layer 1
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        tapThread?.cancel()
        eventTap = nil

        // Tear down Layer 2
        if let monitor = nsEventMonitor {
            NSEvent.removeMonitor(monitor)
            nsEventMonitor = nil
        }

        // Tear down Layer 3
        if let hid = hidManager {
            IOHIDManagerClose(hid, IOOptionBits(kIOHIDOptionsTypeNone))
            hidManager = nil
        }
        hidThread?.cancel()
    }

    /// Restart listeners (call after changing targetKeyCode)
    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
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
            print("[VoxType] CGEventTap creation failed")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[VoxType] Layer 1 active: CGEventTap -> keyCode \(targetKeyCode) (\(hotkeyDisplayName))")
    }

    // MARK: - Layer 2: NSEvent Global Monitor

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

        print("[VoxType] Layer 2 active: NSEvent global monitor")
    }

    // MARK: - Layer 3: IOHIDManager (Raw HID)

    private func setupHIDManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        // Match keyboard and keypad devices
        let matching: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
            ],
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keypad
            ]
        ]

        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        // Register input value callback
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, hidInputCallback, refcon)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnSuccess {
            hidManager = manager
            print("[VoxType] Layer 3 active: IOHIDManager (raw USB/Bluetooth HID)")
        } else {
            print("[VoxType] IOHIDManager open failed: \(result)")
        }
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

    // MARK: - HID Usage <-> macOS KeyCode Mapping

    /// Convert macOS virtual key code to HID usage code
    fileprivate static func keyCodeToHIDUsage(_ keyCode: UInt16) -> UInt32 {
        let map: [UInt16: UInt32] = [
            // Letters
            0: 0x04, // A
            1: 0x16, // S
            2: 0x07, // D
            3: 0x09, // F
            4: 0x0B, // H
            5: 0x0A, // G
            6: 0x1D, // Z
            7: 0x1B, // X
            8: 0x06, // C
            9: 0x19, // V
            11: 0x05, // B
            12: 0x14, // Q
            13: 0x1A, // W
            14: 0x08, // E
            15: 0x15, // R
            16: 0x1C, // Y
            17: 0x17, // T
            31: 0x12, // O
            32: 0x18, // U
            34: 0x0C, // I
            35: 0x13, // P
            37: 0x0F, // L
            38: 0x0D, // J
            40: 0x0E, // K
            45: 0x11, // N
            46: 0x10, // M
            // Numbers
            18: 0x1E, // 1
            19: 0x1F, // 2
            20: 0x20, // 3
            21: 0x21, // 4
            22: 0x23, // 6
            23: 0x22, // 5
            24: 0x2E, // =
            25: 0x26, // 9
            26: 0x24, // 7
            27: 0x2D, // -
            28: 0x25, // 8
            29: 0x27, // 0
            // Special
            36: 0x28, // Return
            48: 0x2B, // Tab
            49: 0x2C, // Space
            51: 0x2A, // Delete/Backspace
            53: 0x29, // Escape
            // Numpad
            65: 0x63, // Numpad .
            67: 0x55, // Numpad *
            69: 0x57, // Numpad +
            71: 0x53, // Numpad Clear
            75: 0x54, // Numpad /
            76: 0x58, // Numpad Enter
            78: 0x56, // Numpad -
            82: 0x62, // Numpad 0
            83: 0x59, // Numpad 1
            84: 0x5A, // Numpad 2
            85: 0x5B, // Numpad 3
            86: 0x5C, // Numpad 4
            87: 0x5D, // Numpad 5
            88: 0x5E, // Numpad 6
            89: 0x5F, // Numpad 7
            91: 0x60, // Numpad 8
            92: 0x61, // Numpad 9
            // Function keys
            122: 0x3A, // F1
            120: 0x3B, // F2
            99: 0x3C, // F3
            118: 0x3D, // F4
            96: 0x3E, // F5
            97: 0x3F, // F6
            98: 0x40, // F7
            100: 0x41, // F8
            101: 0x42, // F9
            109: 0x43, // F10
            103: 0x44, // F11
            111: 0x45, // F12
            105: 0x68, // F13
            107: 0x69, // F14
            113: 0x6A, // F15
            // Navigation
            115: 0x4A, // Home
            119: 0x4D, // End
            116: 0x4B, // Page Up
            121: 0x4E, // Page Down
            117: 0x4C, // Forward Delete
            123: 0x50, // Left Arrow
            124: 0x4F, // Right Arrow
            125: 0x51, // Down Arrow
            126: 0x52, // Up Arrow
            // Punctuation
            30: 0x30, // ]
            33: 0x2F, // [
            39: 0x34, // '
            41: 0x33, // ;
            42: 0x31, // backslash
            43: 0x36, // ,
            44: 0x38, // /
            47: 0x37, // .
            50: 0x35, // `
        ]
        return map[keyCode] ?? 0
    }

    // MARK: - Key Name Mapping

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

// MARK: - CGEventTap C callback (Layer 1)

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

// MARK: - IOHIDManager C callback (Layer 3)

private func hidInputCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    let element = IOHIDValueGetElement(value)
    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let pressed = IOHIDValueGetIntegerValue(value)

    // Only handle key-down events on the keyboard/keypad page
    guard usagePage == kHIDPage_KeyboardOrKeypad, pressed == 1 else { return }

    guard let context = context else { return }
    let service = Unmanaged<HotkeyService>.fromOpaque(context).takeUnretainedValue()

    // Convert the target macOS keyCode to HID usage for comparison
    let targetHIDUsage = HotkeyService.keyCodeToHIDUsage(service.targetKeyCode)

    if usage == targetHIDUsage {
        service.triggerWithDebounce()
    }
}
