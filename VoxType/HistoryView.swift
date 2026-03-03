// HistoryView.swift
// Transcription history list: grouped by date, supports copy and delete

import SwiftUI

struct HistoryView: View {

    @Bindable var store: HistoryStore

    @State private var searchText = ""
    @State private var copiedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("History")
                .font(.system(size: 20, weight: .semibold))

            Spacer()

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("Search...", text: $searchText)
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
                .help("Clear all history")
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No transcriptions yet")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Text("Press the hotkey to start voice input — records are saved here automatically")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Record List

    private var recordList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let groups = filteredGroups
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    // Date group header
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
        // Filter matching records within each group
        return store.groupedByDate.compactMap { group in
            let filtered = group.1.filter { $0.text.lowercased().contains(query) }
            return filtered.isEmpty ? nil : (group.0, filtered)
        }
    }

    private func copyRecord(_ record: TranscriptionRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
        copiedID = record.id
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedID == record.id {
                copiedID = nil
            }
        }
    }
}

// MARK: - Record Row

struct RecordRow: View {

    let record: TranscriptionRecord
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            Text(timeString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 50, alignment: .trailing)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(record.text)
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Label("\(record.wordCount) words", systemImage: "character.cursor.ibeam")
                    Label(String(format: "%.0fs", record.audioDuration), systemImage: "waveform")
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Action buttons (shown on hover)
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
                    .help("Copy")

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
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
