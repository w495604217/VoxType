// AudioRecorder.swift
// AVAudioEngine 录音 → 写入临时 WAV 文件 + 实时音量采样

import AVFoundation
import Foundation

final class AudioRecorder: @unchecked Sendable {

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var tempURL: URL?
    private var startTime: Date?

    /// 最近一次录音时长（秒），stop 后可读
    private(set) var lastDuration: TimeInterval = 0

    /// 当前音量（0.0~1.0），录音期间实时更新
    private(set) var currentLevel: Float = 0

    /// 开始录音，音频写入临时 WAV 文件
    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxtype_\(UUID().uuidString).wav")

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        audioFile = try AVAudioFile(
            forWriting: url,
            settings: recordingFormat.settings
        )

        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: recordingFormat
        ) { [weak self] buffer, _ in
            try? self?.audioFile?.write(from: buffer)

            // 计算 RMS 音量
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameCount {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(max(frameCount, 1)))
            // 映射到 0~1，clamp
            let level = min(1.0, max(0.0, rms * 5.0))
            self?.currentLevel = level
        }

        engine.prepare()
        try engine.start()

        tempURL = url
        startTime = Date()
        currentLevel = 0
    }

    /// 停止录音，返回 WAV 文件路径
    func stop() -> URL? {
        // 先算时长，再清空 startTime
        if let start = startTime {
            lastDuration = Date().timeIntervalSince(start)
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        currentLevel = 0

        let finalURL = tempURL
        tempURL = nil
        startTime = nil
        return finalURL
    }
}
