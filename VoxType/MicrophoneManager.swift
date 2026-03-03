// MicrophoneManager.swift
// CoreAudio input device management: list, select, monitor changes

import Foundation
import CoreAudio
import Observation

// MARK: - Data Model

struct AudioInputDevice: Identifiable, Hashable, Sendable {
    let id: AudioDeviceID   // UInt32
    let name: String
    let uid: String
}

// MARK: - Manager

@MainActor
@Observable
final class MicrophoneManager {

    var devices: [AudioInputDevice] = []
    var selectedDeviceID: AudioDeviceID = 0

    /// Name of the currently selected device
    var selectedDeviceName: String {
        devices.first { $0.id == selectedDeviceID }?.name ?? "Unknown Device"
    }

    init() {
        refresh()
    }

    /// Refresh device list and read the current default input
    func refresh() {
        devices = Self.listInputDevices()
        selectedDeviceID = Self.getDefaultInputDeviceID()
    }

    /// Select a device as the system default input
    func selectDevice(_ deviceID: AudioDeviceID) {
        guard deviceID != selectedDeviceID else { return }
        Self.setDefaultInputDevice(deviceID)
        selectedDeviceID = deviceID
        print("[VoxType] Switched microphone: \(selectedDeviceName) (ID: \(deviceID))")
    }

    // MARK: - CoreAudio: List Input Devices

    private static func listInputDevices() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &deviceIDs
        ) == noErr else { return [] }

        return deviceIDs.compactMap { deviceID in
            guard hasInputChannels(deviceID) else { return nil }
            return AudioInputDevice(
                id: deviceID,
                name: getDeviceName(deviceID),
                uid: getDeviceUID(deviceID)
            )
        }
    }

    // MARK: - CoreAudio: Check for Input Channels

    private static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            deviceID, &address, 0, nil, &size
        ) == noErr, size > 0 else { return false }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }

        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, raw
        ) == noErr else { return false }

        let bufferList = UnsafeMutableAudioBufferListPointer(
            raw.assumingMemoryBound(to: AudioBufferList.self)
        )
        let channels = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
        return channels > 0
    }

    // MARK: - CoreAudio: Device Properties

    private static func getDeviceName(_ deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &name
        ) == noErr, let cfName = name?.takeUnretainedValue() else { return "Unknown" }
        return cfName as String
    }

    private static func getDeviceUID(_ deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &uid
        ) == noErr, let cfUID = uid?.takeUnretainedValue() else { return "" }
        return cfUID as String
    }

    // MARK: - CoreAudio: Default Input Device

    static func getDefaultInputDeviceID() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }

    private static func setDefaultInputDevice(_ deviceID: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &id
        )
        if status != noErr {
            print("[VoxType] Failed to set default input device: \(status)")
        }
    }
}
