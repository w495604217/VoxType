// FloatingPanelWindow.swift
// NSPanel management: creates a floating transparent panel above all windows

import AppKit
import SwiftUI

@MainActor
final class FloatingPanelWindow {

    private var panel: NSPanel?

    /// Show the floating panel
    func show(state: VoxTypeState) {
        guard panel == nil else { return }

        let hostingView = NSHostingView(
            rootView: FloatingPanelView(state: state)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 52)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.contentView = hostingView
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false

        // Position: centered at bottom of screen, 80pt above
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 150
            let y = screenFrame.minY + 80
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        p.orderFrontRegardless()
        panel = p
    }

    /// Hide the floating panel
    func hide() {
        panel?.close()
        panel = nil
    }

    /// Whether the panel is visible
    var isVisible: Bool { panel != nil }
}
