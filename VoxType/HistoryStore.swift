// HistoryStore.swift
// 转录历史持久化（JSON 文件存储）

import Foundation
import Observation

@MainActor
@Observable
final class HistoryStore {

    // MARK: - 数据

    private(set) var records: [TranscriptionRecord] = []

    // MARK: - 统计

    /// 总字数
    var totalWordCount: Int {
        records.reduce(0) { $0 + $1.wordCount }
    }

    /// 今日字数
    var todayWordCount: Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.wordCount }
    }

    /// 平均每分钟字数（WPM）
    var averageWPM: Int {
        let totalAudio = records.reduce(0.0) { $0 + $1.audioDuration }
        guard totalAudio > 10 else { return 0 }
        let totalWords = records.reduce(0) { $0 + $1.wordCount }
        return Int(Double(totalWords) / (totalAudio / 60.0))
    }

    /// 周连续使用天数
    var weekStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        while true {
            let hasRecord = records.contains { record in
                calendar.isDate(record.date, inSameDayAs: checkDate)
            }
            if hasRecord {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    /// 按日期分组（最新在前）
    var groupedByDate: [(String, [TranscriptionRecord])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        let calendar = Calendar.current
        var groups: [(String, [TranscriptionRecord])] = []
        var currentKey = ""
        var currentItems: [TranscriptionRecord] = []

        let sorted = records.sorted { $0.date > $1.date }

        for record in sorted {
            let key: String
            if calendar.isDateInToday(record.date) {
                key = "今天"
            } else if calendar.isDateInYesterday(record.date) {
                key = "昨天"
            } else {
                formatter.dateFormat = "M月d日 EEEE"
                key = formatter.string(from: record.date)
            }

            if key != currentKey {
                if !currentItems.isEmpty {
                    groups.append((currentKey, currentItems))
                }
                currentKey = key
                currentItems = [record]
            } else {
                currentItems.append(record)
            }
        }
        if !currentItems.isEmpty {
            groups.append((currentKey, currentItems))
        }

        return groups
    }

    // MARK: - 持久化路径

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("VoxType", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    // MARK: - 初始化

    init() {
        load()
    }

    // MARK: - CRUD

    func add(_ record: TranscriptionRecord) {
        var updated = records
        updated.insert(record, at: 0)
        records = updated
        save()
    }

    func delete(id: UUID) {
        records = records.filter { $0.id != id }
        save()
    }

    func clearAll() {
        records = []
        save()
    }

    // MARK: - IO

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
        } catch {
            print("[VoxType] 历史加载失败: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[VoxType] 历史保存失败: \(error.localizedDescription)")
        }
    }
}
