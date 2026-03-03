// MicrophoneView.swift
// 麦克风选择界面：设备列表 + 当前选中 + 音量预览

import SwiftUI

struct MicrophoneView: View {

    @Bindable var state: VoxTypeState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题
            HStack {
                Text("麦克风")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Button {
                    state.micManager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("刷新设备列表")
            }

            Text("选择用于语音输入的麦克风，切换后将同时更改系统默认输入设备。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            // 设备列表
            if state.micManager.devices.isEmpty {
                emptyState
            } else {
                deviceList
            }

            // 当前设备信息
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

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("未检测到音频输入设备")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - 设备列表

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
                // 麦克风图标
                Image(systemName: micIcon(for: device))
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 24)

                // 设备名称
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

                // 选中标记
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

    // MARK: - 当前设备信息

    private var currentDeviceInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前设备")
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
                    Text("VoxType 使用系统默认输入设备进行录音")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 录音状态
                if state.recording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text("录音中")
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

    // MARK: - 工具

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
