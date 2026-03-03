// HistoryStore.swift
// Transcription history persistence (JSON file storage)

import Foundation
import Observation

@MainActor
@Observable
final class HistoryStore {

    // MARK: - Data

    private(set) var records: [TranscriptionRecord] = []

    // MARK: - Stats

    /// Total word count
    var totalWordCount: Int {
        records.reduce(0) { $0 + $1.wordCount }
    }

    /// Today's word count
    var todayWordCount: Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.wordCount }
    }

    /// Average words per minute (WPM)
    var averageWPM: Int {
        let totalAudio = records.reduce(0.0) { $0 + $1.audioDuration }
        guard totalAudio > 10 else { return 0 }
        let totalWords = records.reduce(0) { $0 + $1.wordCount }
        return Int(Double(totalWords) / (totalAudio / 60.0))
    }

    /// Consecutive days streak
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

    /// Grouped by date (newest first)
    var groupedByDate: [(String, [TranscriptionRecord])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")

        let calendar = Calendar.current
        var groups: [(String, [TranscriptionRecord])] = []
        var currentKey = ""
        var currentItems: [TranscriptionRecord] = []

        let sorted = records.sorted { $0.date > $1.date }

        for record in sorted {
            let key: String
            if calendar.isDateInToday(record.date) {
                key = "Today"
            } else if calendar.isDateInYesterday(record.date) {
                key = "Yesterday"
            } else {
                formatter.dateFormat = "MMM d, EEEE"
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

    // MARK: - Persistence Path

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("VoxType", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    // MARK: - Init

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
            print("[VoxType] Failed to load history: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[VoxType] Failed to save history: \(error.localizedDescription)")
        }
    }
}
