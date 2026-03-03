// FloatingPanelWindow.swift
// NSPanel 窗口管理：创建悬浮在所有窗口之上的透明面板

import AppKit
import SwiftUI

@MainActor
final class FloatingPanelWindow {

    private var panel: NSPanel?

    /// 显示浮动面板
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

        // 定位：屏幕底部居中，上浮 80pt
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 150
            let y = screenFrame.minY + 80
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        p.orderFrontRegardless()
        panel = p
    }

    /// 隐藏浮动面板
    func hide() {
        panel?.close()
        panel = nil
    }

    /// 面板是否可见
    var isVisible: Bool { panel != nil }
}
