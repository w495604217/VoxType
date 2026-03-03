// FloatingPanelView.swift
// Wispr Flow-style floating recording panel

import SwiftUI

struct FloatingPanelView: View {

    @Bindable var state: VoxTypeState

    var body: some View {
        HStack(spacing: 12) {
            // Left: status indicator
            statusIndicator

            // Center: content
            centerContent
                .frame(maxWidth: .infinity)

            // Right: timer
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

    // MARK: - Left

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

    // MARK: - Center

    @ViewBuilder
    private var centerContent: some View {
        if state.recording {
            WaveformView(levels: state.audioLevels)
        } else if state.transcribing {
            Text("Transcribing...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        } else if let preview = state.resultPreview {
            Text(preview)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
    }

    // MARK: - Right

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

// MARK: - Waveform Visualization

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

// MARK: - Pulsing Dot

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
