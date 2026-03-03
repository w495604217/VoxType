// VoxTypeApp.swift
// macOS 菜单栏语音转录 App + 主窗口

import SwiftUI

@main
struct VoxTypeApp: App {

    @State private var state = VoxTypeState()

    init() {
        // State 的 startServices 需要在 MainActor 上调用
        // 用 DispatchQueue.main.async 延迟到 run loop 启动后
        let s = _state
        DispatchQueue.main.async {
            s.wrappedValue.startServices()
        }
    }

    var body: some Scene {
        // 菜单栏图标
        MenuBarExtra {
            VoxTypeMenu(state: state)
        } label: {
            Image(systemName: state.menuBarIcon)
        }
        .menuBarExtraStyle(.menu)

        // 主窗口（从菜单栏打开）
        Window("VoxType", id: "main") {
            MainWindowView(state: state)
        }
        .defaultSize(width: 800, height: 540)
        .windowResizability(.contentSize)
    }
}

// MARK: - 菜单内容

struct VoxTypeMenu: View {

    @Bindable var state: VoxTypeState
    @Environment(\.openWindow) private var openWindow

    var body: some View {

        // 状态指示
        Text(state.statusText)
            .font(.caption)

        Divider()

        // 录音按钮
        Button(state.recording ? "停止录音" : "开始录音") {
            Task { await state.toggle() }
        }
        .keyboardShortcut("r")
        .disabled(!state.modelReady && !state.recording)

        Divider()

        // 打开主窗口
        Button("打开 VoxType") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")

        // 重新加载模型
        Button("重新加载模型") {
            Task { await state.reloadModel() }
        }
        .disabled(state.recording || state.transcribing)

        Divider()

        // 退出
        Button("退出 VoxType") {
            state.cleanup()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
