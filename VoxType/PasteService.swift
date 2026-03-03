// PasteService.swift
// 将文本粘贴到当前焦点窗口

import AppKit
import Carbon.HIToolbox

enum PasteService {

    /// 将文本粘贴到当前活跃的输入框
    /// 流程：保存剪贴板 → 写入文本 → Cmd+V → 恢复剪贴板
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string) ?? ""

        // 写入文本到剪贴板
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 模拟 Cmd+V
        simulateCmdV()

        // 延迟恢复旧剪贴板内容
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pasteboard.clearContents()
            pasteboard.setString(oldContents, forType: .string)
        }
    }

    // MARK: - 模拟按键

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
