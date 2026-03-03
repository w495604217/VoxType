// VoxTypeState.swift
// 中央状态管理：录音 → 转录 → 粘贴

import Foundation
import Observation
import AppKit
import UserNotifications

// MARK: - 模型状态枚举

enum ModelState: Equatable {
    case idle
    case downloading(Double)   // 0.0~1.0
    case loading
    case ready
    case error(String)

    static func == (lhs: ModelState, rhs: ModelState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.ready, .ready): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

@MainActor
@Observable
final class VoxTypeState {

    // MARK: - 状态

    var recording = false
    var transcribing = false
    var modelReady = false
    var statusText = "加载模型中…"
    var modelState: ModelState = .idle

    // MARK: - 设置项

    var currentLanguage = "zh"
    var autoPaste = true
    var soundEnabled = true
    var floatingPanelEnabled = true

    // MARK: - 浮动面板状态

    /// 波形音量数据（0.0~1.0），面板用来绘制波形
    var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)

    /// 录音计时字符串 "0:03"
    var recordingTimeString = "0:00"

    /// 转录完成后的预览文本（短暂显示后清除）
    var resultPreview: String?

    /// 浮动面板窗口
    let floatingPanel = FloatingPanelWindow()

    /// 历史记录存储
    let historyStore = HistoryStore()

    /// 麦克风管理器
    let micManager = MicrophoneManager()

    var menuBarIcon: String {
        if recording { return "waveform" }
        if transcribing { return "ellipsis.circle" }
        if modelReady { return "mic.fill" }
        return "mic.badge.xmark"
    }

    // MARK: - 服务

    private let recorder = AudioRecorder()
    private let transcriber = TranscriptionService()
    private let hotkeyService = HotkeyService()
    private let socketService = SocketService()

    // MARK: - 计时器

    private var recordingTimer: Timer?
    private var recordingStart: Date?
    private var levelTimer: Timer?
    private var dismissTimer: Timer?

    // MARK: - 配置

    private let model = "openai_whisper-large-v3-v20240930_turbo"
    private let initialPrompt = """
        以下是常见技术术语，转录时保持英文原文：\
        SwiftUI, React, Next.js, TypeScript, JavaScript, Python, Swift, \
        API, SDK, iOS, macOS, Xcode, Git, GitHub, Docker, Kubernetes, \
        PostgreSQL, Supabase, Vercel, Claude, GPT, Whisper, MLX, \
        CPU, GPU, REST, GraphQL, JSON, YAML, CI/CD, AWS, Redis, \
        MongoDB, SQLite, SwiftData, CoreData, CloudKit, StoreKit, \
        async, await, Observable, ViewModel, MVVM, npm, pip, brew, \
        terminal, debug, deploy, commit, push, merge, branch, Tailwind
        """
    private let soundStart = "/System/Library/Sounds/Tink.aiff"
    private let soundEnd = "/System/Library/Sounds/Pop.aiff"
    private let minDuration: TimeInterval = 0.5

    // MARK: - 初始化

    init() {
        // init 里不做任何重活，等 startServices() 被调用
    }

    /// 由 App 启动后调用，延迟启动
    func startServices() {
        // 注册热键和 socket 回调
        hotkeyService.onToggle = { [weak self] in
            Task { @MainActor in
                await self?.toggle()
            }
        }
        socketService.onCommand = { [weak self] cmd in
            return await self?.handleSocketCommand(cmd) ?? "error"
        }

        // 启动后台服务
        hotkeyService.start()
        socketService.start()

        // 预加载模型
        Task { await warmup() }
    }

    // MARK: - Toggle

    func toggle() async {
        if !modelReady {
            statusText = "模型尚未加载"
            return
        }
        if transcribing { return }

        if recording {
            await stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    // MARK: - 录音

    private func startRecording() {
        do {
            try recorder.start()
            recording = true
            statusText = "录音中…"
            recordingTimeString = "0:00"
            resultPreview = nil
            if soundEnabled { playSound(soundStart) }

            // 显示浮动面板
            if floatingPanelEnabled {
                floatingPanel.show(state: self)
            }

            // 启动计时器
            recordingStart = Date()
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateTimer()
                }
            }

            // 启动音量采样
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateLevels()
                }
            }
        } catch {
            statusText = "麦克风错误: \(error.localizedDescription)"
        }
    }

    private func stopAndTranscribe() async {
        recording = false
        if soundEnabled { playSound(soundEnd) }

        // 停止计时器
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil

        let audioDuration = recordingStart.map { Date().timeIntervalSince($0) } ?? 0
        recordingStart = nil

        // 重置波形
        audioLevels = Array(repeating: 0, count: 30)

        guard let url = recorder.stop() else {
            statusText = "录音为空"
            floatingPanel.hide()
            return
        }

        // 检查录音时长
        let duration = recorder.lastDuration
        if duration < minDuration {
            statusText = "录音过短，已忽略"
            floatingPanel.hide()
            try? FileManager.default.removeItem(at: url)
            return
        }

        // 开始转录（面板保持显示）
        transcribing = true
        statusText = "转录中…"

        do {
            let t0 = ContinuousClock.now
            let text = try await transcriber.transcribe(
                audioPath: url.path,
                language: currentLanguage,
                prompt: initialPrompt
            )
            let elapsed = ContinuousClock.now - t0
            let seconds = elapsed.components.seconds

            try? FileManager.default.removeItem(at: url)

            guard !text.isEmpty else {
                statusText = "未识别到内容"
                transcribing = false
                floatingPanel.hide()
                return
            }

            // 粘贴到当前焦点窗口
            if autoPaste {
                PasteService.paste(text)
            }

            let preview = text.count > 30
                ? "\(text.prefix(30))…"
                : text
            statusText = "✅ \(String(format: "%.0f", duration))s→\(seconds)s | \(preview)"

            // 保存到历史
            let record = TranscriptionRecord(
                text: text,
                audioDuration: audioDuration,
                transcribeDuration: Double(seconds),
                language: currentLanguage
            )
            historyStore.add(record)

            // 面板显示结果预览，2秒后自动消失
            resultPreview = preview
            dismissTimer?.invalidate()
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.resultPreview = nil
                    self?.floatingPanel.hide()
                }
            }
        } catch {
            statusText = "转录失败: \(error.localizedDescription)"
            try? FileManager.default.removeItem(at: url)
            floatingPanel.hide()
        }

        transcribing = false
    }

    // MARK: - 计时器更新

    private func updateTimer() {
        guard let start = recordingStart else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        recordingTimeString = "\(minutes):\(String(format: "%02d", seconds))"
    }

    private func updateLevels() {
        let level = CGFloat(recorder.currentLevel)
        // 左移一位，追加新值
        var newLevels = Array(audioLevels.dropFirst())
        newLevels.append(level)
        audioLevels = newLevels
    }

    // MARK: - 模型

    private func warmup() async {
        modelState = .loading
        statusText = "加载模型中…"
        do {
            try await transcriber.warmup(model: model)
            modelReady = true
            modelState = .ready
            statusText = "就绪 — 按 * 或点击图标"
            sendNotification(title: "VoxType 就绪", body: "按小键盘 * 或点击菜单栏图标开始语音输入")
        } catch {
            modelState = .error(error.localizedDescription)
            statusText = "模型加载失败: \(error.localizedDescription)"
            sendNotification(title: "VoxType 错误", body: "模型加载失败: \(error.localizedDescription)")
        }
    }

    func reloadModel() async {
        modelReady = false
        await warmup()
    }

    // MARK: - Socket 命令

    private func handleSocketCommand(_ cmd: String) async -> String {
        switch cmd {
        case "toggle":
            await toggle()
            if recording { return "recording" }
            if transcribing { return "stopped" }
            return "idle"
        case "status":
            if recording { return "recording" }
            if transcribing { return "transcribing" }
            if !modelReady { return "loading" }
            return "idle"
        default:
            return "unknown"
        }
    }

    // MARK: - 清理

    func cleanup() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        dismissTimer?.invalidate()
        floatingPanel.hide()
        socketService.stop()
    }

    // MARK: - 工具

    private func playSound(_ path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        NSSound(contentsOfFile: path, byReference: true)?.play()
    }

    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
