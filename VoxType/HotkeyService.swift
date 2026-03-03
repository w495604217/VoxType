// HotkeyService.swift
// 全局热键：小键盘 * 触发录音
// 双重捕获：CGEventTap（原生键盘）+ NSEvent 全局监听（Synergy/KVM 映射键）

import Foundation
import CoreGraphics
import AppKit

final class HotkeyService: @unchecked Sendable {

    /// 热键触发回调
    var onToggle: (() -> Void)?

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var thread: Thread?
    private var nsEventMonitor: Any?

    // macOS keycode: 小键盘 * = 0x43 (67)
    // 某些外接键盘/KVM 可能发送不同 keycode，同时匹配
    private let targetKeyCodes: Set<CGKeyCode> = [
        67,   // 小键盘 * (标准 Apple 键盘)
        0x43, // 同 67，显式十六进制
    ]

    func start() {
        // 层 1: CGEventTap — 捕获原生键盘事件
        thread = Thread { [weak self] in
            self?.setupEventTap()
            RunLoop.current.run()
        }
        thread?.name = "VoxType.HotkeyService"
        thread?.start()

        // 层 2: NSEvent 全局监听 — 捕获 Synergy/KVM/远程桌面 转发的事件
        setupNSEventMonitor()
    }

    func stop() {
        // 清理 CGEventTap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        thread?.cancel()

        // 清理 NSEvent 监听
        if let monitor = nsEventMonitor {
            NSEvent.removeMonitor(monitor)
            nsEventMonitor = nil
        }
    }

    // MARK: - 层 1: CGEventTap（原生硬件键盘）

    private func setupEventTap() {
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        // 监听 keyDown + systemDefined（某些键盘将小键盘键作为 system event 发送）
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)  // 保留扩展性

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: refcon
        ) else {
            print("[VoxType] ❌ 无法创建 CGEventTap，请检查辅助功能权限")
            print("[VoxType] 系统设置 → 隐私与安全 → 辅助功能 → 勾选 VoxType")
            // CGEventTap 失败时，NSEvent 层仍然可以工作
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[VoxType] ✅ CGEventTap 热键已绑定：小键盘 *")
    }

    // MARK: - 层 2: NSEvent 全局监听（Synergy/KVM 兼容）

    private func setupNSEventMonitor() {
        // addGlobalMonitorForEvents 不需要辅助功能权限
        // 可以捕获 Synergy/Barrier/KVM 等软件转发的按键事件
        nsEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            guard let self else { return }

            let keyCode = event.keyCode

            // 调试日志：记录所有按键码，方便排查映射问题
            if event.modifierFlags.contains(.numericPad) || self.targetKeyCodes.contains(CGKeyCode(keyCode)) {
                print("[VoxType] NSEvent 捕获按键: keyCode=\(keyCode) chars='\(event.characters ?? "")' numpad=\(event.modifierFlags.contains(.numericPad))")
            }

            // 匹配条件：
            // 1. keyCode 在目标集合中
            // 2. 或者: 字符是 "*" 且来自小键盘（numericPad flag）
            let isTarget = self.targetKeyCodes.contains(CGKeyCode(keyCode))
                || (event.characters == "*" && event.modifierFlags.contains(.numericPad))

            if isTarget {
                print("[VoxType] ✅ NSEvent 成功匹配小键盘 * (keyCode=\(keyCode))")
                self.triggerWithDebounce()
            }
        }

        print("[VoxType] ✅ NSEvent 全局监听已启动（Synergy/KVM 兼容层）")
    }

    // MARK: - 去重（防止两层同时触发）

    /// 上次触发时间戳，用于去重
    fileprivate var lastTriggerTime: UInt64 = 0
    private let debounceNanos: UInt64 = 300_000_000 // 300ms

    /// 带去重的触发，两层都调用此方法
    fileprivate func triggerWithDebounce() {
        let now = DispatchTime.now().uptimeNanoseconds
        if now - lastTriggerTime < debounceNanos {
            print("[VoxType] ⏭️ 去重：跳过重复触发 (间隔 \((now - lastTriggerTime) / 1_000_000)ms)")
            return
        }
        lastTriggerTime = now
        onToggle?()
    }
}

// MARK: - CGEventTap C 回调

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // 重新启用 tap（系统可能因超时禁用）
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
            let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
            if let tap = service.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                print("[VoxType] ⚠️ CGEventTap 被系统禁用，已重新启用")
            }
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

    // 调试日志
    let flags = event.flags
    let isNumpad = flags.contains(.maskNumericPad)
    print("[VoxType] CGEventTap 捕获按键: keyCode=\(keyCode) numpad=\(isNumpad)")

    // 匹配小键盘 *：keyCode == 67 或 (字符 * + numpad flag)
    let isTarget = keyCode == 67
        || (isNumpad && keyCode == 67)

    if isTarget {
        if let refcon = refcon {
            let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
            print("[VoxType] ✅ CGEventTap 成功匹配小键盘 * (keyCode=\(keyCode))")
            service.triggerWithDebounce()
        }
        // 拦截按键，不让 * 字符输出
        return nil
    }

    return Unmanaged.passRetained(event)
}
