// PasteService.swift
// Paste text into the currently focused window

import AppKit
import Carbon.HIToolbox

enum PasteService {

    /// Paste text into the active input field
    /// Flow: save clipboard -> write text -> Cmd+V -> restore clipboard
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string) ?? ""

        // Write text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        simulateCmdV()

        // Restore old clipboard contents after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pasteboard.clearContents()
            pasteboard.setString(oldContents, forType: .string)
        }
    }

    // MARK: - Key Simulation

    private static func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: V with Cmd
        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        )
        keyDown?.flags = .maskCommand

        // Key up
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        )
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
