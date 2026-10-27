import AppKit
import AudioToolbox
import CoreAudio
import Foundation

public struct AudioMonitorResult: Sendable {
    public let snapshot: AudioSnapshot
    public let errorMessage: String?

    public init(snapshot: AudioSnapshot, errorMessage: String? = nil) {
        self.snapshot = snapshot
        self.errorMessage = errorMessage
    }
}

public protocol CoreAudioProviding: Sendable {
    func readSnapshot() -> AudioMonitorResult
}

public final class CoreAudioMonitor: CoreAudioProviding, @unchecked Sendable {
    public init() {}

    public func readSnapshot() -> AudioMonitorResult {
        let deviceIDs = objectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices
        )
        guard !deviceIDs.isEmpty else {
            let statusMessage =
                deviceIDs.isEmpty
                ? "当前没有可用的音频设备，请连接蓝牙或有线耳机。"
                : nil
            return AudioMonitorResult(
                snapshot: AudioSnapshot(
                    devices: [],
                    processes: readProcesses(),
                    defaultOutputDeviceID: defaultOutputDeviceID()
                ),
                errorMessage: statusMessage
            )
        }

        let devices = deviceIDs.compactMap(readDevice)
        let processes = readProcesses()
        return AudioMonitorResult(
            snapshot: AudioSnapshot(
                devices: devices,
                processes: processes,
                defaultOutputDeviceID: defaultOutputDeviceID()
            )
        )
    }

    private func readDevice(_ deviceID: AudioDeviceID) -> AudioDeviceSnapshot? {
        let outputStreams = objectIDArray(
            objectID: deviceID,
            selector: kAudioDevicePropertyStreams,
            scope: kAudioObjectPropertyScopeOutput
        )
        guard !outputStreams.isEmpty else {
            return nil
        }

        let terminalTypes = Set(outputStreams.compactMap { streamID in
            optionalUInt32(
                objectID: streamID,
                selector: kAudioStreamPropertyTerminalType
            )
        })
        let transport = transportKind(
            optionalUInt32(
                objectID: deviceID,
                selector: kAudioDevicePropertyTransportType
            ) ?? 0
        )
        let uid =
            string(
                objectID: deviceID,
                selector: kAudioDevicePropertyDeviceUID
            ) ?? String(deviceID)
        let name =
            string(
                objectID: deviceID,
                selector: kAudioObjectPropertyName
            ) ?? "未命名音频设备"
        let jackConnected = optionalUInt32(
            objectID: deviceID,
            selector: kAudioDevicePropertyJackIsConnected,
            scope: kAudioObjectPropertyScopeOutput
        ).map { $0 != 0 }

        return AudioDeviceSnapshot(
            id: deviceID,
            uid: uid,
            name: name,
            transport: transport,
            hasOutput: true,
            terminalTypes: terminalTypes,
            jackConnected: jackConnected,
            isRunningSomewhere:
                optionalUInt32(
                    objectID: deviceID,
                    selector: kAudioDevicePropertyDeviceIsRunningSomewhere
                ) == 1,
            isMuted: outputMuteState(for: deviceID),
            volume: outputVolume(for: deviceID)
        )
    }

    private func readProcesses() -> [AudioProcessSnapshot] {
        objectIDArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyProcessObjectList
        ).compactMap { processID in
            guard
                let bundleID = string(
                    objectID: processID,
                    selector: kAudioProcessPropertyBundleID
                ),
                let pidValue = optionalInt32(
                    objectID: processID,
                    selector: kAudioProcessPropertyPID
                ),
                !bundleID.isEmpty
            else {
                return nil
            }
            let pid = pid_t(pidValue)
            let runningApplication = NSRunningApplication(
                processIdentifier: pid
            )
            let name =
                runningApplication?.localizedName
                ?? PlayerIdentity.displayName(for: bundleID)
            let outputDeviceIDs = objectIDArray(
                objectID: processID,
                selector: kAudioProcessPropertyDevices,
                scope: kAudioObjectPropertyScopeOutput
            )
            return AudioProcessSnapshot(
                id: processID,
                pid: pid,
                bundleID: bundleID,
                name: name,
                outputDeviceIDs: outputDeviceIDs,
                isRunningOutput:
                    optionalUInt32(
                        objectID: processID,
                        selector: kAudioProcessPropertyIsRunningOutput
                    ) == 1,
                isRunning:
                    optionalUInt32(
                        objectID: processID,
                        selector: kAudioProcessPropertyIsRunning
                    ) == 1
            )
        }
    }

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        guard let value = optionalUInt32(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice
        ), value != kAudioObjectUnknown else {
            return nil
        }
        return value
    }

    private func outputMuteState(for deviceID: AudioDeviceID) -> Bool? {
        for (scope, element) in outputPropertyTargets {
            if let value = optionalUInt32(
                objectID: deviceID,
                selector: kAudioDevicePropertyMute,
                scope: scope,
                element: element
            ) {
                return value != 0
            }
        }
        return nil
    }

    private func outputVolume(for deviceID: AudioDeviceID) -> Float? {
        for (scope, element) in outputPropertyTargets {
            if let value = optionalFloat32(
                objectID: deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: scope,
                element: element
            ) {
                return value
            }
        }
        return nil
    }

    private var outputPropertyTargets: [(AudioObjectPropertyScope, UInt32)] {
        [
            (kAudioObjectPropertyScopeOutput, kAudioObjectPropertyElementMain),
            (kAudioObjectPropertyScopeOutput, 1),
            (kAudioObjectPropertyScopeOutput, 2)
        ]
    }

    private func transportKind(_ value: UInt32) -> AudioTransportKind {
        switch value {
        case kAudioDeviceTransportTypeBuiltIn:
            .builtIn
        case kAudioDeviceTransportTypeUSB:
            .usb
        case kAudioDeviceTransportTypeThunderbolt:
            .thunderbolt
        case kAudioDeviceTransportTypeFireWire:
            .fireWire
        case kAudioDeviceTransportTypeBluetooth:
            .bluetooth
        case kAudioDeviceTransportTypeBluetoothLE:
            .bluetoothLE
        case kAudioDeviceTransportTypeAirPlay:
            .airPlay
        case kAudioDeviceTransportTypeHDMI:
            .hdmi
        case kAudioDeviceTransportTypeDisplayPort:
            .displayPort
        case kAudioDeviceTransportTypePCI:
            .pci
        case kAudioDeviceTransportTypeVirtual:
            .virtual
        case kAudioDeviceTransportTypeAggregate,
             kAudioDeviceTransportTypeAutoAggregate:
            .aggregate
        default:
            .other
        }
    }

    private func string(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(objectID, &address) else {
            return nil
        }
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &size,
                pointer
            )
        }
        guard status == noErr, let value else {
            return nil
        }
        return value.takeRetainedValue() as String
    }

    private func optionalUInt32(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        guard AudioObjectHasProperty(objectID, &address) else {
            return nil
        }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &size,
            &value
        )
        return status == noErr ? value : nil
    }

    private func optionalInt32(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> Int32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(objectID, &address) else {
            return nil
        }
        var value: Int32 = 0
        var size = UInt32(MemoryLayout<Int32>.size)
        let status = AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &size,
            &value
        )
        return status == noErr ? value : nil
    }

    private func optionalFloat32(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Float32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        guard AudioObjectHasProperty(objectID, &address) else {
            return nil
        }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &size,
            &value
        )
        return status == noErr ? value : nil
    }

    private func objectIDArray(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> [UInt32] {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(objectID, &address) else {
            return []
        }
        var size: UInt32 = 0
        guard
            AudioObjectGetPropertyDataSize(
                objectID,
                &address,
                0,
                nil,
                &size
            ) == noErr,
            size >= UInt32(MemoryLayout<UInt32>.size)
        else {
            return []
        }
        let count = Int(size) / MemoryLayout<UInt32>.size
        guard count > 0 else {
            return []
        }
        var values = [UInt32](repeating: 0, count: count)
        let status = values.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &size,
                buffer.baseAddress!
            )
        }
        return status == noErr ? values : []
    }
}
