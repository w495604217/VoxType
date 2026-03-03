// HomeView.swift
// Home page: greeting, stats, model status, manual record button

import SwiftUI

struct HomeView: View {

    @Bindable var state: VoxTypeState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                greetingSection
                recordButton
                statsSection
                modelSection
                Spacer()
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.system(size: 24, weight: .semibold))

            Text("Press \(state.hotkeyService.hotkeyDisplayName) or tap the button below to start")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning ☀️"
        case 12..<18: return "Good afternoon 👋"
        default: return "Good evening 🌙"
        }
    }

    // MARK: - Manual Record Button

    private var recordButton: some View {
        Button {
            Task { await state.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: state.recording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.recording ? "Stop Recording" : "Start Recording")
                        .font(.system(size: 15, weight: .semibold))

                    if state.recording {
                        Text(state.recordingTimeString)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    } else if state.transcribing {
                        Text("Transcribing…")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("Or press \(state.hotkeyService.hotkeyDisplayName)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                if state.recording {
                    // Pulsing dot
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .opacity(state.recording ? 1 : 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(state.recording ? Color.red : Color.accentColor)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!state.modelReady && !state.recording)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Streak",
                value: "\(state.historyStore.weekStreak)d",
                emoji: "🔥",
                subtitle: "Keep it going"
            )
            StatCard(
                title: "Avg Speed",
                value: "\(state.historyStore.averageWPM) WPM",
                emoji: "⚡",
                subtitle: "Faster than typing"
            )
            StatCard(
                title: "Total Words",
                value: formattedWordCount,
                emoji: "📝",
                subtitle: "Today: \(state.historyStore.todayWordCount)"
            )
        }
    }

    private var formattedWordCount: String {
        let count = state.historyStore.totalWordCount
        if count >= 10000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    // MARK: - Model Status

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Status")
                .font(.system(size: 15, weight: .semibold))

            HStack(spacing: 16) {
                modelStatusCard
                Spacer()
            }
        }
    }

    private var modelStatusCard: some View {
        HStack(spacing: 12) {
            modelIcon
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Whisper Large V3 Turbo")
                    .font(.system(size: 13, weight: .medium))

                Text(modelDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .downloading(let progress) = state.modelState {
                ProgressView(value: progress)
                    .frame(width: 100)
            }

            if case .error = state.modelState {
                Button("Retry") {
                    Task { await state.reloadModel() }
                }
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
        .frame(maxWidth: 400)
    }

    @ViewBuilder
    private var modelIcon: some View {
        switch state.modelState {
        case .idle:
            Image(systemName: "circle.dashed")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        case .downloading:
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.red)
        }
    }

    private var modelDetail: String {
        switch state.modelState {
        case .idle: return "Waiting to load"
        case .downloading(let p): return "Downloading \(Int(p * 100))%"
        case .loading: return "Loading model into memory…"
        case .ready: return "Ready — start dictating"
        case .error(let msg): return msg
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let emoji: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                Text(emoji)
                    .font(.system(size: 16))
            }

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}
