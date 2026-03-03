// VoxTypeApp.swift
// macOS menu bar voice transcription app + main window

import SwiftUI

@main
struct VoxTypeApp: App {

    @State private var state = VoxTypeState()

    init() {
        // Delay startServices() until the run loop is active
        let s = _state
        DispatchQueue.main.async {
            s.wrappedValue.startServices()
        }
    }

    var body: some Scene {
        // Menu bar icon
        MenuBarExtra {
            VoxTypeMenu(state: state)
        } label: {
            Image(systemName: state.menuBarIcon)
        }
        .menuBarExtraStyle(.menu)

        // Main window (opened from menu bar)
        Window("VoxType", id: "main") {
            MainWindowView(state: state)
        }
        .defaultSize(width: 800, height: 540)
        .windowResizability(.contentSize)
    }
}

// MARK: - Menu Content

struct VoxTypeMenu: View {

    @Bindable var state: VoxTypeState
    @Environment(\.openWindow) private var openWindow

    var body: some View {

        // Status indicator
        Text(state.statusText)
            .font(.caption)

        Divider()

        // Record button
        Button(state.recording ? "Stop Recording" : "Start Recording") {
            Task { await state.toggle() }
        }
        .keyboardShortcut("r")
        .disabled(!state.modelReady && !state.recording)

        Divider()

        // Open main window
        Button("Open VoxType") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")

        // Reload model
        Button("Reload Model") {
            Task { await state.reloadModel() }
        }
        .disabled(state.recording || state.transcribing)

        Divider()

        // Quit
        Button("Quit VoxType") {
            state.cleanup()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
