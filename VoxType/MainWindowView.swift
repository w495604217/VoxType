// MainWindowView.swift
// Wispr Flow 风格主窗口：手动侧边栏 + 内容区（避免 NavigationSplitView 焦点问题）

import SwiftUI

enum SidebarTab: String, CaseIterable {
    case home = "首页"
    case history = "历史"
    case microphone = "麦克风"
    case settings = "设置"

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock"
        case .microphone: return "mic"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {

    @Bindable var state: VoxTypeState

    @State private var selectedTab: SidebarTab = .home

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            // 确保窗口获得焦点
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.windows
                    .first { $0.title == "VoxType" }?
                    .makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: - 侧边栏

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
                Text("VoxType")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)

            // 导航项
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                sidebarButton(tab)
            }

            Spacer()

            // 底部模型状态
            modelStatusBadge
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: 180)
        .background(Color(.windowBackgroundColor).opacity(0.5))
    }

    private func sidebarButton(_ tab: SidebarTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .contentShape(Rectangle()) // 确保整个区域可点击
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedTab == tab ? Color.accentColor.opacity(0.1) : .clear)
        )
        .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
        .padding(.horizontal, 8)
    }

    // MARK: - 模型状态指示

    private var modelStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(modelStatusColor)
                .frame(width: 8, height: 8)
            Text(modelStatusLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(modelStatusColor.opacity(0.1))
        )
    }

    private var modelStatusColor: Color {
        switch state.modelState {
        case .idle: return .gray
        case .downloading: return .orange
        case .loading: return .yellow
        case .ready: return .green
        case .error: return .red
        }
    }

    private var modelStatusLabel: String {
        switch state.modelState {
        case .idle: return "未加载"
        case .downloading(let progress):
            return "下载中 \(Int(progress * 100))%"
        case .loading: return "加载中…"
        case .ready: return "模型就绪"
        case .error(let msg): return "错误: \(msg)"
        }
    }

    // MARK: - 详情内容

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .home:
            HomeView(state: state)
        case .history:
            HistoryView(store: state.historyStore)
        case .microphone:
            MicrophoneView(state: state)
        case .settings:
            SettingsView(state: state)
        }
    }
}
