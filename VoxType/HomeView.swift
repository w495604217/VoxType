// HomeView.swift
// 首页：问候语 + 统计卡片 + 模型状态

import SwiftUI

struct HomeView: View {

    @Bindable var state: VoxTypeState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 问候语
                greetingSection

                // 统计卡片
                statsSection

                // 模型状态卡片
                modelSection

                Spacer()
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - 问候语

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.system(size: 24, weight: .semibold))

            Text("按住 * 键开始语音输入")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好 ☀️"
        case 12..<18: return "下午好 👋"
        default: return "晚上好 🌙"
        }
    }

    // MARK: - 统计卡片

    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "连续使用",
                value: "\(state.historyStore.weekStreak) 天",
                emoji: "🔥",
                subtitle: "保持每天使用"
            )
            StatCard(
                title: "平均速度",
                value: "\(state.historyStore.averageWPM) WPM",
                emoji: "⚡",
                subtitle: "比打字快得多"
            )
            StatCard(
                title: "总转录字数",
                value: formattedWordCount,
                emoji: "📝",
                subtitle: "今日 \(state.historyStore.todayWordCount) 字"
            )
        }
    }

    private var formattedWordCount: String {
        let count = state.historyStore.totalWordCount
        if count >= 10000 {
            return String(format: "%.1f万", Double(count) / 10000.0)
        }
        return "\(count)"
    }

    // MARK: - 模型状态

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模型状态")
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
                Text(modelName)
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
                Button("重试") {
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

    private var modelName: String { "Whisper Large V3 Turbo" }

    private var modelDetail: String {
        switch state.modelState {
        case .idle: return "等待加载"
        case .downloading(let p): return "下载中 \(Int(p * 100))%"
        case .loading: return "正在加载模型到内存…"
        case .ready: return "就绪 — 可以开始语音输入"
        case .error(let msg): return msg
        }
    }
}

// MARK: - 统计卡片组件

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
