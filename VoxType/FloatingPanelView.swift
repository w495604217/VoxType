// FloatingPanelView.swift
// Wispr Flow 风格浮动录音面板

import SwiftUI

struct FloatingPanelView: View {

    @Bindable var state: VoxTypeState

    var body: some View {
        HStack(spacing: 12) {
            // 左侧状态指示
            statusIndicator

            // 中间内容
            centerContent
                .frame(maxWidth: .infinity)

            // 右侧计时器
            trailingContent
        }
        .padding(.horizontal, 20)
        .frame(width: 300, height: 52)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 4)
        )
        .environment(\.colorScheme, .dark)
    }

    // MARK: - 左侧

    @ViewBuilder
    private var statusIndicator: some View {
        if state.recording {
            PulsingDot()
        } else if state.transcribing {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        } else if state.resultPreview != nil {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 14))
        }
    }

    // MARK: - 中间

    @ViewBuilder
    private var centerContent: some View {
        if state.recording {
            WaveformView(levels: state.audioLevels)
        } else if state.transcribing {
            Text("转录中…")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        } else if let preview = state.resultPreview {
            Text(preview)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
    }

    // MARK: - 右侧

    @ViewBuilder
    private var trailingContent: some View {
        if state.recording {
            Text(state.recordingTimeString)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
    }
}

// MARK: - 波形可视化

struct WaveformView: View {

    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(0.4 + level * 0.6))
                    .frame(width: 2.5, height: max(3, level * 24))
                    .animation(
                        .interpolatingSpring(stiffness: 300, damping: 15),
                        value: level
                    )
            }
        }
        .frame(height: 24)
    }
}

// MARK: - 脉冲红点

struct PulsingDot: View {

    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(.red.opacity(0.4), lineWidth: 2)
                    .scaleEffect(pulsing ? 2.2 : 1.0)
                    .opacity(pulsing ? 0 : 1)
            )
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.0)
                    .repeatForever(autoreverses: false)
                ) {
                    pulsing = true
                }
            }
    }
}
