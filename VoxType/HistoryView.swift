// HistoryView.swift
// 转录历史列表：按日期分组，支持复制和删除

import SwiftUI

struct HistoryView: View {

    @Bindable var store: HistoryStore

    @State private var searchText = ""
    @State private var copiedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            header

            Divider()

            if store.records.isEmpty {
                emptyState
            } else {
                recordList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - 标题

    private var header: some View {
        HStack {
            Text("历史记录")
                .font(.system(size: 20, weight: .semibold))

            Spacer()

            // 搜索框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("搜索…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
            )
            .frame(width: 200)

            if !store.records.isEmpty {
                Button(role: .destructive) {
                    store.clearAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("清空全部历史")
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("暂无转录记录")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Text("按 * 键开始语音输入，记录会自动保存在这里")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 记录列表

    private var recordList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let groups = filteredGroups
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    // 日期分组标题
                    Text(group.0)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    ForEach(group.1) { record in
                        RecordRow(
                            record: record,
                            isCopied: copiedID == record.id,
                            onCopy: { copyRecord(record) },
                            onDelete: { store.delete(id: record.id) }
                        )
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    private var filteredGroups: [(String, [TranscriptionRecord])] {
        if searchText.isEmpty {
            return store.groupedByDate
        }
        let query = searchText.lowercased()
        // 过滤每组中匹配的记录
        return store.groupedByDate.compactMap { group in
            let filtered = group.1.filter { $0.text.lowercased().contains(query) }
            return filtered.isEmpty ? nil : (group.0, filtered)
        }
    }

    private func copyRecord(_ record: TranscriptionRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
        copiedID = record.id
        // 2秒后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedID == record.id {
                copiedID = nil
            }
        }
    }
}

// MARK: - 单条记录行

struct RecordRow: View {

    let record: TranscriptionRecord
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间
            Text(timeString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 50, alignment: .trailing)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(record.text)
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Label("\(record.wordCount)字", systemImage: "character.cursor.ibeam")
                    Label(String(format: "%.0fs", record.audioDuration), systemImage: "waveform")
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // 操作按钮（hover 时显示）
            if isHovered {
                HStack(spacing: 4) {
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(isCopied ? .green : .secondary)
                    .help("复制")

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .help("删除")
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(.controlBackgroundColor) : .clear)
                .padding(.horizontal, 24)
        )
        .onHover { isHovered = $0 }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: record.date)
    }
}
