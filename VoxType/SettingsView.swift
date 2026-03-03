// SettingsView.swift
// Settings: model, language, hotkey, behavior

import SwiftUI

struct SettingsView: View {

    @Bindable var state: VoxTypeState

    @State private var isRecordingHotkey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))

                // Model
                settingsSection("Model") {
                    settingsRow("Whisper Model", detail: "large-v3-turbo") {
                        Button("Reload") {
                            Task { await state.reloadModel() }
                        }
                        .controlSize(.small)
                        .disabled(state.recording || state.transcribing)
                    }
                }

                // Language
                settingsSection("Language") {
                    settingsRow("Recognition Language", detail: languageLabel(state.currentLanguage)) {
                        Picker("", selection: Binding(
                            get: { state.currentLanguage },
                            set: { state.currentLanguage = $0 }
                        )) {
                            Text("Chinese").tag("zh")
                            Text("English").tag("en")
                            Text("Japanese").tag("ja")
                            Text("Auto-detect").tag("auto")
                        }
                        .frame(width: 120)
                    }
                }

                // Hotkey
                settingsSection("Hotkey") {
                    settingsRow(
                        "Record Hotkey",
                        detail: isRecordingHotkey
                            ? "Press any key…"
                            : state.hotkeyService.hotkeyDisplayName
                    ) {
                        Button(isRecordingHotkey ? "Cancel" : "Change") {
                            if isRecordingHotkey {
                                isRecordingHotkey = false
                            } else {
                                isRecordingHotkey = true
                            }
                        }
                        .controlSize(.small)
                    }
                }

                // Behavior
                settingsSection("Behavior") {
                    settingsRow("Auto Paste", detail: "Paste transcription at cursor after completion") {
                        Toggle("", isOn: Binding(
                            get: { state.autoPaste },
                            set: { state.autoPaste = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    settingsRow("Sound Effects", detail: "Play sounds on record start/stop") {
                        Toggle("", isOn: Binding(
                            get: { state.soundEnabled },
                            set: { state.soundEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    settingsRow("Floating Panel", detail: "Show floating status bar while recording") {
                        Toggle("", isOn: Binding(
                            get: { state.floatingPanelEnabled },
                            set: { state.floatingPanelEnabled = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }

                // Permissions
                settingsSection("Permissions") {
                    settingsRow("Accessibility", detail: "Required for hotkey and paste simulation") {
                        Button("Open Settings") {
                            openAccessibilitySettings()
                        }
                        .controlSize(.small)
                    }
                }

                // About
                settingsSection("About") {
                    settingsRow("Version", detail: "VoxType 1.1.0") {
                        EmptyView()
                    }
                    settingsRow("Data Storage", detail: dataPath) {
                        Button("Open") {
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
        .onChange(of: isRecordingHotkey) { _, newValue in
            if newValue {
                captureNextKey()
            } else {
                removeHotkeyMonitor()
            }
        }
        .onDisappear {
            removeHotkeyMonitor()
        }
    }

    // MARK: - Hotkey recorder

    @State private var hotkeyMonitor: Any?

    private func captureNextKey() {
        removeHotkeyMonitor()
        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.isRecordingHotkey {
                let newKeyCode = event.keyCode
                self.state.hotkeyService.targetKeyCode = newKeyCode
                self.state.hotkeyService.restart()
                self.isRecordingHotkey = false
                self.removeHotkeyMonitor()
                return nil // swallow the key
            }
            return event
        }
    }

    private func removeHotkeyMonitor() {
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyMonitor = nil
        }
    }

    // MARK: - Components

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

    private func languageLabel(_ code: String) -> String {
        switch code {
        case "zh": return "Chinese"
        case "en": return "English"
        case "ja": return "Japanese"
        case "auto": return "Auto-detect"
        default: return code
        }
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

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

}
