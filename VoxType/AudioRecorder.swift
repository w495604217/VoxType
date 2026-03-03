// AudioRecorder.swift
// AVAudioEngine recording -> writes to temporary WAV file + real-time level sampling

import AVFoundation
import Foundation

final class AudioRecorder: @unchecked Sendable {

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var tempURL: URL?
    private var startTime: Date?

    /// Duration of the last recording (seconds), readable after stop()
    private(set) var lastDuration: TimeInterval = 0

    /// Current audio level (0.0~1.0), updated in real-time during recording
    private(set) var currentLevel: Float = 0

    /// Start recording, audio is written to a temporary WAV file
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

            // Calculate RMS level
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameCount {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(max(frameCount, 1)))
            // Map to 0~1, clamp
            let level = min(1.0, max(0.0, rms * 5.0))
            self?.currentLevel = level
        }

        engine.prepare()
        try engine.start()

        tempURL = url
        startTime = Date()
        currentLevel = 0
    }

    /// Stop recording, returns the WAV file URL
    func stop() -> URL? {
        // Calculate duration before clearing startTime
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
