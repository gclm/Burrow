//
//  CameraMicSensor.swift
//  Burrow
//
//  Honest, passive camera/microphone in-use detection for the menu-bar
//  popover — the same "is some process using this device" signal the macOS
//  amber dot reflects. Reads CoreMediaIO's kCMIODevicePropertyDeviceIsRunning-
//  Somewhere (camera) and CoreAudio's kAudioDevicePropertyDeviceIsRunning-
//  Somewhere (mic). These are passive property reads — Burrow never opens an
//  AVCaptureSession, so there is no TCC prompt and no NSCamera/Microphone
//  usage description needed, and Burrow itself never lights the dot.
//
//  It reports system-level "in use" (matching Control Center), so it will
//  also light for Siri / dictation / Continuity Camera — labelled neutrally
//  as "in use", never faked into per-app attribution. Opt-in (off by default).
//
//  Virtual/aggregate devices are the catch: their device-global "running
//  somewhere" fires on OUTPUT or host-app activity, not real capture — a
//  BlackHole/loopback/Camo/Teams device would light the mic dot merely because
//  audio is *playing* through it, and a virtual camera (Camo/OBS) stays
//  "running" while its host app is open. We skip virtual/aggregate transports
//  unless the user actually selected one as their default input. #234
//

import Foundation
import CoreMediaIO
import CoreAudio

enum CameraMicSensor {

    // FourCC transport types (shared by CoreAudio and CoreMediaIO). Comparing
    // the raw values avoids per-framework symbol availability differences.
    private static let virtualTransport: UInt32 = 0x76697274   // 'virt'
    private static let aggregateTransport: UInt32 = 0x67727570 // 'grup'

    /// Whether any *real* camera device reports it's running somewhere. Virtual
    /// cameras (Camo/OBS) are skipped — they report running while their host app
    /// is open regardless of actual capture.
    static func cameraInUse() -> Bool {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(0))   // main element
        var dataSize: UInt32 = 0
        let sys = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(sys, &addr, 0, nil, &dataSize) == OSStatus(0),
              dataSize > 0 else { return false }
        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: count)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(sys, &addr, 0, nil, dataSize, &used, &devices) == OSStatus(0)
        else { return false }

        for device in devices where device != 0 {
            if isVirtualCMIO(device) { continue }   // skip virtual cameras
            if cmioIsRunning(device) { return true }
        }
        return false
    }

    /// Whether any input (microphone) device reports it's running somewhere,
    /// excluding virtual/aggregate devices (unless one is the selected default
    /// input) so playback through a loopback/duplex device can't light the dot.
    static func micInUse() -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        let sys = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(sys, &addr, 0, nil, &dataSize) == noErr,
              dataSize > 0 else { return false }
        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var devices = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(sys, &addr, 0, nil, &dataSize, &devices) == noErr
        else { return false }

        let defaultInput = defaultInputDevice()

        for device in devices where device != 0 {
            // Only consider devices that actually have input streams — a
            // playback-only device "running" isn't the microphone.
            guard hasInputStreams(device) else { continue }

            // A virtual/aggregate device's global "running" fires on output/host
            // activity too, so it lights the mic dot when only audio is playing.
            // Trust it only if the user actually picked it as their input device.
            if isVirtualOrAggregateAudio(device), device != defaultInput { continue }

            if audioIsRunning(device) { return true }
        }
        return false
    }

    // MARK: - CoreAudio helpers

    private static func defaultInputDevice() -> AudioObjectID {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dev: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr
        else { return 0 }
        return dev
    }

    private static func hasInputStreams(_ device: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr && size > 0
    }

    private static func isVirtualOrAggregateAudio(_ device: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &transport) == noErr
        else { return false }
        return transport == virtualTransport || transport == aggregateTransport
    }

    private static func audioIsRunning(_ device: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &running) == noErr && running != 0
    }

    // MARK: - CoreMediaIO helpers

    private static func isVirtualCMIO(_ device: CMIOObjectID) -> Bool {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyTransportType),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(0))
        var transport: UInt32 = 0
        var used: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        guard CMIOObjectGetPropertyData(device, &addr, 0, nil, size, &used, &transport) == OSStatus(0)
        else { return false }
        return transport == virtualTransport || transport == aggregateTransport
    }

    private static func cmioIsRunning(_ device: CMIOObjectID) -> Bool {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(0))
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return CMIOObjectGetPropertyData(device, &addr, 0, nil, size, &size, &running) == OSStatus(0) && running != 0
    }
}
