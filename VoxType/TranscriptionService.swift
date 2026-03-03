// TranscriptionService.swift
// WhisperKit wrapper: model loading + audio transcription

import Foundation
import WhisperKit

final class TranscriptionService: @unchecked Sendable {

    // WhisperKit instance
    private let pipe: Mutex<WhisperKit?> = Mutex(nil)

    /// Preload model (first run downloads the CoreML model from HuggingFace)
    func warmup(model: String) async throws {
        let config = WhisperKitConfig(model: model)
        let whisperKit = try await WhisperKit(config)
        pipe.withLock { $0 = whisperKit }
    }

    /// Transcribe an audio file, returns recognized text
    func transcribe(
        audioPath: String,
        language: String,
        prompt: String?
    ) async throws -> String {
        guard let whisperKit = pipe.withLock({ $0 }) else {
            throw TranscriptionError.modelNotLoaded
        }

        let options = DecodingOptions(
            language: language
        )

        let results: [TranscriptionResult] = try await whisperKit.transcribe(
            audioPath: audioPath,
            decodeOptions: options
        )

        // Merge text from all segments
        let text = results
            .map { $0.text }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Model not loaded"
        }
    }
}

/// Simple mutex wrapper
final class Mutex<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withLock<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
