// TranscriptionRecord.swift
// Transcription record data model

import Foundation

struct TranscriptionRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let text: String
    let date: Date
    let audioDuration: TimeInterval   // Recording duration (seconds)
    let transcribeDuration: TimeInterval // Transcription time (seconds)
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
        // CJK languages count by character; others split by whitespace
        self.wordCount = Self.countWords(text, language: language)
    }

    private static func countWords(_ text: String, language: String) -> Int {
        if language.hasPrefix("zh") || language.hasPrefix("ja") || language.hasPrefix("ko") {
            return text.count
        }
        return text.split(separator: " ").count
    }
}
