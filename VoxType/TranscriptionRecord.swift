// TranscriptionRecord.swift
// 转录记录数据模型

import Foundation

struct TranscriptionRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let text: String
    let date: Date
    let audioDuration: TimeInterval   // 录音时长（秒）
    let transcribeDuration: TimeInterval // 转录耗时（秒）
    let language: String
    let wordCount: Int

    init(
        text: String,
        date: Date = Date(),
        audioDuration: TimeInterval,
        transcribeDuration: TimeInterval,
        language: String = "zh"
    ) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.audioDuration = audioDuration
        self.transcribeDuration = transcribeDuration
        self.language = language
        // 中文按字数算，英文按空格分词
        self.wordCount = Self.countWords(text, language: language)
    }

    private static func countWords(_ text: String, language: String) -> Int {
        if language.hasPrefix("zh") || language.hasPrefix("ja") || language.hasPrefix("ko") {
            return text.count
        }
        return text.split(separator: " ").count
    }
}
