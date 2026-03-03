// MicrophoneView.swift
// Microphone selection: device list + current selection

import SwiftUI

struct MicrophoneView: View {

    @Bindable var state: VoxTypeState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title
            HStack {
                Text("Microphone")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Button {
                    state.micManager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Refresh device list")
            }

            Text("Select the microphone for voice input. Switching will also change the system default input device.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            // Device list
            if state.micManager.devices.isEmpty {
                emptyState
            } else {
                deviceList
            }

            // Current device info
            currentDeviceInfo

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            state.micManager.refresh()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No audio input devices detected")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Device List

    private var deviceList: some View {
        VStack(spacing: 0) {
            ForEach(state.micManager.devices) { device in
                deviceRow(device)

                if device.id != state.micManager.devices.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private func deviceRow(_ device: AudioInputDevice) -> some View {
        let isSelected = device.id == state.micManager.selectedDeviceID

        return Button {
            state.micManager.selectDevice(device.id)
        } label: {
            HStack(spacing: 12) {
                // Microphone icon
                Image(systemName: micIcon(for: device))
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 24)

                // Device name
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)

                    Text(device.uid)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                }

                Spacer()

                // Selection mark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current Device Info

    private var currentDeviceInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Device")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.green.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.micManager.selectedDeviceName)
                        .font(.system(size: 14, weight: .medium))
                    Text("VoxType uses the system default input device for recording")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Recording status
                if state.recording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text("Recording")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }

    // MARK: - Utilities

    private func micIcon(for device: AudioInputDevice) -> String {
        let name = device.name.lowercased()
        if name.contains("bluetooth") || name.contains("airpods") {
            return "headphones"
        } else if name.contains("usb") || name.contains("external") {
            return "mic.badge.plus"
        } else if name.contains("aggregate") {
            return "rectangle.stack"
        }
        return "mic"
    }
}
