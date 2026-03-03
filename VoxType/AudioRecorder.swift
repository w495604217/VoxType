// AudioRecorder.swift
// AVAudioEngine recording -> writes to temporary WAV file + real-time level sampling

import AVFoundation
import Foundation
import CoreAudio

enum AudioRecorderError: LocalizedError {
    case noInputDevice
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "No audio input device found. Please connect a microphone."
        case .invalidFormat(let detail):
            return "Audio format not supported: \(detail)"
        }
    }
}

final class AudioRecorder: @unchecked Sendable {

    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempURL: URL?
    private var startTime: Date?

    /// Duration of the last recording (seconds), readable after stop()
    private(set) var lastDuration: TimeInterval = 0

    /// Current audio level (0.0~1.0), updated in real-time during recording
    private(set) var currentLevel: Float = 0

    /// Start recording, audio is written to a temporary WAV file
    func start() throws {
        // Pre-check: is there a valid default input device?
        guard Self.hasDefaultInputDevice() else {
            throw AudioRecorderError.noInputDevice
        }

        // Create a fresh engine each time to avoid stale device references
        let eng = AVAudioEngine()
        let inputNode = eng.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Validate format before installing tap
        guard recordingFormat.sampleRate > 0,
              recordingFormat.channelCount > 0 else {
            throw AudioRecorderError.invalidFormat(
                "\(recordingFormat.channelCount) ch, \(recordingFormat.sampleRate) Hz"
            )
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxtype_\(UUID().uuidString).wav")

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

        eng.prepare()
        try eng.start()

        engine = eng
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

        if let eng = engine {
            eng.inputNode.removeTap(onBus: 0)
            eng.stop()
        }
        engine = nil
        audioFile = nil
        currentLevel = 0

        let finalURL = tempURL
        tempURL = nil
        startTime = nil
        return finalURL
    }

    // MARK: - Device Check

    /// Check if macOS has a valid default input device (CoreAudio level)
    private static func hasDefaultInputDevice() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        // deviceID 0 means no device found
        return status == noErr && deviceID != 0
    }
}
