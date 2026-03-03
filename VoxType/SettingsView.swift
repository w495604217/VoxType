// SettingsView.swift
// 设置页面：模型、语言、热键、行为配置

import SwiftUI

struct SettingsView: View {

    @Bindable var state: VoxTypeState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("设置")
                    .font(.system(size: 20, weight: .semibold))

                // 模型设置
                settingsSection("模型") {
                    settingsRow("Whisper 模型", detail: "large-v3-turbo") {
                        Button("重新加载") {
                            Task { await state.reloadModel() }
                        }
                        .controlSize(.small)
                        .disabled(state.recording || state.transcribing)
                    }
                }

                // 语言设置
                settingsSection("语言") {
                    settingsRow("识别语言", detail: state.currentLanguage) {
                        Picker("", selection: Binding(
                            get: { state.currentLanguage },
                            set: { state.currentLanguage = $0 }
                        )) {
                            Text("中文").tag("zh")
                            Text("英文").tag("en")
                            Text("日文").tag("ja")
                            Text("自动检测").tag("auto")
                        }
                        .frame(width: 120)
                    }
                }

                // 热键设置
                settingsSection("快捷键") {
                    settingsRow("录音热键", detail: "小键盘 *") {
                        EmptyView()
                    }
                }

                // 行为设置
                settingsSection("行为") {
                    settingsRow("自动粘贴", detail: "转录完成后自动粘贴到光标位置") {
                        Toggle("", isOn: Binding(
                            get: { state.autoPaste },
                            set: { state.autoPaste = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    settingsRow("提示音", detail: "录音开始/结束时播放提示音") {
                        Toggle("", isOn: Binding(
                            get: { state.soundEnabled },
                            set: { state.soundEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    settingsRow("浮动面板", detail: "录音时显示悬浮状态面板") {
                        Toggle("", isOn: Binding(
                            get: { state.floatingPanelEnabled },
                            set: { state.floatingPanelEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }

                // 关于
                settingsSection("关于") {
                    settingsRow("版本", detail: "VoxType 1.0.0") {
                        EmptyView()
                    }
                    settingsRow("数据存储", detail: dataPath) {
                        Button("打开") {
                            openDataFolder()
                        }
                        .controlSize(.small)
                    }
                }

                Spacer()
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - 组件

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }

    private func settingsRow<Trailing: View>(
        _ title: String,
        detail: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var dataPath: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("VoxType").path
    }

    private func openDataFolder() {
        let url = URL(fileURLWithPath: dataPath)
        NSWorkspace.shared.open(url)
    }
}
