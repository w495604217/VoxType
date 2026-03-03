// VoxTypeState.swift
// Central state management: record -> transcribe -> paste

import Foundation
import Observation
import AppKit
import UserNotifications

// MARK: - Model State

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

    // MARK: - State

    var recording = false
    var transcribing = false
    var modelReady = false
    var statusText = "Loading model..."
    var modelState: ModelState = .idle

    // MARK: - Settings

    var currentLanguage = "zh"
    var autoPaste = true
    var soundEnabled = true
    var floatingPanelEnabled = true

    // MARK: - Floating Panel State

    /// Waveform audio levels (0.0~1.0), used by the floating panel
    var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)

    /// Recording timer string "0:03"
    var recordingTimeString = "0:00"

    /// Preview text after transcription (briefly displayed then cleared)
    var resultPreview: String?

    /// Floating panel window
    let floatingPanel = FloatingPanelWindow()

    /// History store
    let historyStore = HistoryStore()

    /// Microphone manager
    let micManager = MicrophoneManager()

    var menuBarIcon: String {
        if recording { return "waveform" }
        if transcribing { return "ellipsis.circle" }
        if modelReady { return "mic.fill" }
        return "mic.badge.xmark"
    }

    // MARK: - Services

    private let recorder = AudioRecorder()
    private let transcriber = TranscriptionService()
    let hotkeyService = HotkeyService()
    private let socketService = SocketService()

    // MARK: - Timers

    private var recordingTimer: Timer?
    private var recordingStart: Date?
    private var levelTimer: Timer?
    private var dismissTimer: Timer?

    // MARK: - Config

    private let model = "openai_whisper-large-v3-v20240930_turbo"
    private let initialPrompt = """
        Keep the following common technical terms in their original English form:\
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

    // MARK: - Init

    init() {
        // No heavy work in init; wait for startServices() to be called
    }

    /// Called by the App after launch
    func startServices() {
        // Register hotkey and socket callbacks
        hotkeyService.onToggle = { [weak self] in
            Task { @MainActor in
                await self?.toggle()
            }
        }
        socketService.onCommand = { [weak self] cmd in
            return await self?.handleSocketCommand(cmd) ?? "error"
        }

        // Start background services
        hotkeyService.start()
        socketService.start()

        // Preload model
        Task { await warmup() }
    }

    // MARK: - Toggle

    func toggle() async {
        if !modelReady {
            statusText = "Model not loaded"
            return
        }
        if transcribing { return }

        if recording {
            await stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    // MARK: - Recording

    private func startRecording() {
        do {
            try recorder.start()
        } catch {
            statusText = "Mic error: \(error.localizedDescription)"
            sendNotification(title: "VoxType", body: error.localizedDescription)
            return
        }

        recording = true
        statusText = "Recording..."
        recordingTimeString = "0:00"
        resultPreview = nil
        if soundEnabled { playSound(soundStart) }

        // Show floating panel
        if floatingPanelEnabled {
            floatingPanel.show(state: self)
        }

        // Start timer
        recordingStart = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateTimer()
            }
        }

        // Start audio level sampling
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLevels()
            }
        }
    }

    private func stopAndTranscribe() async {
        recording = false
        if soundEnabled { playSound(soundEnd) }

        // Stop timers
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil

        let audioDuration = recordingStart.map { Date().timeIntervalSince($0) } ?? 0
        recordingStart = nil

        // Reset waveform
        audioLevels = Array(repeating: 0, count: 30)

        guard let url = recorder.stop() else {
            statusText = "Recording is empty"
            floatingPanel.hide()
            return
        }

        // Check recording duration
        let duration = recorder.lastDuration
        if duration < minDuration {
            statusText = "Recording too short, ignored"
            floatingPanel.hide()
            try? FileManager.default.removeItem(at: url)
            return
        }

        // Start transcription (panel stays visible)
        transcribing = true
        statusText = "Transcribing..."

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
                statusText = "No content recognized"
                transcribing = false
                floatingPanel.hide()
                return
            }

            // Paste to the focused window
            if autoPaste {
                PasteService.paste(text)
            }

            let preview = text.count > 30
                ? "\(text.prefix(30))..."
                : text
            statusText = "\(String(format: "%.0f", duration))s -> \(seconds)s | \(preview)"

            // Save to history
            let record = TranscriptionRecord(
                text: text,
                audioDuration: audioDuration,
                transcribeDuration: Double(seconds),
                language: currentLanguage
            )
            historyStore.add(record)

            // Show result preview on panel, auto-dismiss after 2s
            resultPreview = preview
            dismissTimer?.invalidate()
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.resultPreview = nil
                    self?.floatingPanel.hide()
                }
            }
        } catch {
            statusText = "Transcription failed: \(error.localizedDescription)"
            try? FileManager.default.removeItem(at: url)
            floatingPanel.hide()
        }

        transcribing = false
    }

    // MARK: - Timer Updates

    private func updateTimer() {
        guard let start = recordingStart else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        recordingTimeString = "\(minutes):\(String(format: "%02d", seconds))"
    }

    private func updateLevels() {
        let level = CGFloat(recorder.currentLevel)
        // Shift left by one, append new value
        var newLevels = Array(audioLevels.dropFirst())
        newLevels.append(level)
        audioLevels = newLevels
    }

    // MARK: - Model

    private func warmup() async {
        modelState = .loading
        statusText = "Loading model..."
        do {
            try await transcriber.warmup(model: model)
            modelReady = true
            modelState = .ready
            let hotkeyName = hotkeyService.hotkeyDisplayName
            if hotkeyService.accessibilityGranted {
                statusText = "Ready — press \(hotkeyName) or click the icon"
            } else {
                statusText = "Ready — click icon to record (grant Accessibility for hotkey)"
            }
            sendNotification(title: "VoxType Ready", body: "Press \(hotkeyName) or click the menu bar icon to start voice input")
        } catch {
            modelState = .error(error.localizedDescription)
            statusText = "Model loading failed: \(error.localizedDescription)"
            sendNotification(title: "VoxType Error", body: "Model loading failed: \(error.localizedDescription)")
        }
    }

    func reloadModel() async {
        modelReady = false
        await warmup()
    }

    // MARK: - Socket Commands

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

    // MARK: - Cleanup

    func cleanup() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        dismissTimer?.invalidate()
        floatingPanel.hide()
        socketService.stop()
    }

    // MARK: - Utilities

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
