// TranscriptionService.swift
// WhisperKit 封装：模型加载 + 音频转录

import Foundation
import WhisperKit

final class TranscriptionService: @unchecked Sendable {

    // WhisperKit 实例
    private let pipe: Mutex<WhisperKit?> = Mutex(nil)

    /// 预加载模型（首次运行会从 HuggingFace 下载 CoreML 模型）
    func warmup(model: String) async throws {
        let config = WhisperKitConfig(model: model)
        let whisperKit = try await WhisperKit(config)
        pipe.withLock { $0 = whisperKit }
    }

    /// 转录音频文件，返回识别文本
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

        // 合并所有片段的文本
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
        case .modelNotLoaded: return "模型尚未加载"
        }
    }
}

/// 简单互斥锁包装
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
