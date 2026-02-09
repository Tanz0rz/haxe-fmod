#!/usr/bin/swift
// Creates a Multi-Output aggregate device combining the default output with BlackHole.
// The default output provides a stable clock source so BlackHole doesn't stall.
// Usage: swift create-aggregate-device.swift
// Prints the UID of the created aggregate device on success.

import CoreAudio
import Foundation

func getDeviceID(forName name: String) -> AudioDeviceID? {
    var propSize: UInt32 = 0
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &propSize)
    let count = Int(propSize) / MemoryLayout<AudioDeviceID>.size
    var devices = [AudioDeviceID](repeating: 0, count: count)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &propSize, &devices)

    for device in devices {
        var nameSize: UInt32 = 0
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyDataSize(device, &nameAddr, 0, nil, &nameSize)
        var cfName: CFString = "" as CFString
        nameSize = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(device, &nameAddr, 0, nil, &nameSize, &cfName)
        if (cfName as String) == name {
            return device
        }
    }
    return nil
}

func getDefaultOutputDeviceID() -> AudioDeviceID? {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var deviceID: AudioDeviceID = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
    if status == noErr && deviceID != kAudioObjectUnknown {
        return deviceID
    }
    return nil
}

func getDeviceUID(_ deviceID: AudioDeviceID) -> String? {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var uid: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &uid)
    return status == noErr ? (uid as String) : nil
}

// Find BlackHole and default output
guard let blackholeID = getDeviceID(forName: "BlackHole 2ch") else {
    fputs("ERROR: BlackHole 2ch device not found\n", stderr)
    exit(1)
}
guard let defaultOutputID = getDefaultOutputDeviceID() else {
    fputs("ERROR: No default output device found\n", stderr)
    exit(1)
}
guard let blackholeUID = getDeviceUID(blackholeID) else {
    fputs("ERROR: Could not get BlackHole UID\n", stderr)
    exit(1)
}
guard let defaultOutputUID = getDeviceUID(defaultOutputID) else {
    fputs("ERROR: Could not get default output UID\n", stderr)
    exit(1)
}

fputs("BlackHole UID: \(blackholeUID)\n", stderr)
fputs("Default output UID: \(defaultOutputUID)\n", stderr)

// Create aggregate device description
let aggregateUID = "com.haxefmod.aggregate"
let desc: [String: Any] = [
    kAudioAggregateDeviceUIDKey as String: aggregateUID,
    kAudioAggregateDeviceNameKey as String: "FMOD+BlackHole",
    kAudioAggregateDeviceIsStackedKey as String: 0 as UInt32,
    kAudioAggregateDeviceSubDeviceListKey as String: [
        [kAudioSubDeviceUIDKey as String: defaultOutputUID],
        [kAudioSubDeviceUIDKey as String: blackholeUID]
    ],
    kAudioAggregateDeviceMasterSubDeviceKey as String: defaultOutputUID,
]

var aggregateID: AudioDeviceID = 0
let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggregateID)
if status != noErr {
    fputs("ERROR: Failed to create aggregate device (status: \(status))\n", stderr)
    exit(1)
}

fputs("Created aggregate device ID: \(aggregateID)\n", stderr)

// Set aggregate device as default output
var addr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
var mutableAggregateID = aggregateID
var size = UInt32(MemoryLayout<AudioDeviceID>.size)
let setStatus = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &mutableAggregateID)
if setStatus != noErr {
    fputs("WARNING: Could not set aggregate as default output (status: \(setStatus))\n", stderr)
}

// Print the aggregate UID to stdout for scripts to use
print(aggregateUID)
