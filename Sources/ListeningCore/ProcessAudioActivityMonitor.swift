import Accelerate
import CoreAudio
import Foundation

/// Detects whether a tapped process is still producing non-silent PCM.
///
/// Core Audio can keep `kAudioProcessPropertyIsRunningOutput` true for several
/// seconds after an app pauses. A process tap exposes the audio itself, so the
/// monitor can stop tracking as soon as the stream becomes silent.
public final class ProcessAudioActivityMonitor: @unchecked Sendable {
    public static let shared = ProcessAudioActivityMonitor()
    public static let silenceGracePeriod: TimeInterval = 0.3

    private struct Entry {
        let sourceBundleID: String
        let runtime: ProcessTapRuntime
    }

    private let registryLock = NSLock()
    private var entries: [AudioObjectID: Entry] = [:]

    public init() {}

    /// Keeps one process tap for every selected source and tears down taps for
    /// processes that have exited or are no longer selected.
    public func update(
        processes: [AudioProcessSnapshot],
        selectedSourceBundleIDs: Set<String>
    ) {
        let desired = processes.reduce(
            into: [AudioObjectID: (String, AudioProcessSnapshot)]()
        ) { result, process in
            let source = AudioSourceResolver.canonicalBundleID(
                for: process.bundleID,
                processName: process.name
            )
            guard selectedSourceBundleIDs.contains(source) else {
                return
            }
            result[AudioObjectID(process.id)] = (source, process)
        }

        registryLock.lock()
        let current = entries
        registryLock.unlock()

        var next: [AudioObjectID: Entry] = [:]
        for (processID, (source, _)) in desired {
            if let existing = current[processID],
               existing.sourceBundleID == source {
                next[processID] = existing
                continue
            }
            guard let runtime = ProcessTapRuntime(
                processObjectID: processID
            ) else {
                continue
            }
            next[processID] = Entry(
                sourceBundleID: source,
                runtime: runtime
            )
        }

        registryLock.lock()
        entries = next
        registryLock.unlock()

        for (processID, entry) in current where next[processID] == nil {
            entry.runtime.invalidate()
        }
    }

    /// Returns a value only after a tap has observed actual audio at least
    /// once. `nil` means Core Audio's own process state remains the fallback.
    public func activityByProcessID() -> [AudioObjectID: Bool] {
        registryLock.lock()
        let snapshot = entries
        registryLock.unlock()

        let now = ProcessTapRuntime.hostTimeSeconds()
        var result: [AudioObjectID: Bool] = [:]
        for (processID, entry) in snapshot {
            guard let isAudible = entry.runtime.isAudible(
                at: now,
                gracePeriod: Self.silenceGracePeriod
            ) else {
                continue
            }
            result[processID] = isAudible
        }
        return result
    }
}

private final class ProcessTapRuntime: @unchecked Sendable {
    private let state = AudioActivityState()
    private var tapID = AudioObjectID(0)
    private var aggregateDeviceID = AudioObjectID(0)
    private var ioProcID: AudioDeviceIOProcID?
    private let invalidateLock = NSLock()
    private var isInvalidated = false

    init?(processObjectID: AudioObjectID) {
        let description = CATapDescription(
            stereoMixdownOfProcesses: [processObjectID]
        )
        description.name = "ListeningTimer"
        description.isPrivate = true
        description.isProcessRestoreEnabled = false
        description.muteBehavior = .unmuted

        var createdTapID = AudioObjectID(0)
        guard AudioHardwareCreateProcessTap(
            description,
            &createdTapID
        ) == noErr else {
            return nil
        }
        tapID = createdTapID

        guard let tapUID = Self.stringProperty(
            objectID: createdTapID,
            selector: kAudioTapPropertyUID
        ), let format = Self.formatProperty(objectID: createdTapID) else {
            AudioHardwareDestroyProcessTap(createdTapID)
            tapID = 0
            return nil
        }

        var createdAggregateID = AudioObjectID(0)
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "ListeningTimer",
            kAudioAggregateDeviceUIDKey as String:
                "com.lazycanary.ListeningTimer.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey as String: true,
            kAudioAggregateDeviceTapAutoStartKey as String: true,
            kAudioAggregateDeviceTapListKey as String: [
                [
                    kAudioSubTapUIDKey as String: tapUID,
                    kAudioSubTapDriftCompensationKey as String: false
                ]
            ]
        ]
        guard AudioHardwareCreateAggregateDevice(
            aggregateDescription as CFDictionary,
            &createdAggregateID
        ) == noErr else {
            AudioHardwareDestroyProcessTap(createdTapID)
            tapID = 0
            return nil
        }
        aggregateDeviceID = createdAggregateID

        var createdIOProcID: AudioDeviceIOProcID?
        let activityState = state
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(
            &createdIOProcID,
            createdAggregateID,
            nil
        ) { inNow, inputData, _, _, _ in
            let now = Self.callbackHostTimeSeconds(inNow)
            let peak = Self.peakAmplitude(
                inputData: inputData,
                format: format
            )
            if let peak {
                activityState.observe(peak: peak, at: now)
            }
        }
        guard createStatus == noErr, let createdIOProcID else {
            Self.destroy(
                aggregateDeviceID: createdAggregateID,
                tapID: createdTapID
            )
            tapID = 0
            aggregateDeviceID = 0
            return nil
        }
        ioProcID = createdIOProcID

        guard AudioDeviceStart(
            createdAggregateID,
            createdIOProcID
        ) == noErr else {
            Self.destroy(
                aggregateDeviceID: createdAggregateID,
                ioProcID: createdIOProcID,
                tapID: createdTapID
            )
            tapID = 0
            aggregateDeviceID = 0
            ioProcID = nil
            return nil
        }

    }

    deinit {
        invalidate()
    }

    func isAudible(
        at now: TimeInterval,
        gracePeriod: TimeInterval
    ) -> Bool? {
        state.isAudible(at: now, gracePeriod: gracePeriod)
    }

    func invalidate() {
        invalidateLock.lock()
        guard !isInvalidated else {
            invalidateLock.unlock()
            return
        }
        isInvalidated = true
        let aggregate = aggregateDeviceID
        let ioProc = ioProcID
        let tap = tapID
        aggregateDeviceID = 0
        ioProcID = nil
        tapID = 0
        invalidateLock.unlock()

        if aggregate != 0, let ioProc {
            AudioDeviceStop(aggregate, ioProc)
        }
        Self.destroy(
            aggregateDeviceID: aggregate,
            ioProcID: ioProc,
            tapID: tap
        )
    }

    static func hostTimeSeconds() -> TimeInterval {
        Double(AudioConvertHostTimeToNanos(AudioGetCurrentHostTime()))
            / 1_000_000_000
    }

    private static func callbackHostTimeSeconds(
        _ timestamp: UnsafePointer<AudioTimeStamp>
    ) -> TimeInterval {
        let value = timestamp.pointee
        if value.mHostTime != 0 {
            return Double(AudioConvertHostTimeToNanos(value.mHostTime))
                / 1_000_000_000
        }
        return hostTimeSeconds()
    }

    private static func peakAmplitude(
        inputData: UnsafePointer<AudioBufferList>,
        format: AudioStreamBasicDescription
    ) -> Float? {
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mBitsPerChannel == 32,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              let data = inputData.pointee.mBuffers.mData else {
            return nil
        }
        let sampleCount =
            Int(inputData.pointee.mBuffers.mDataByteSize)
            / MemoryLayout<Float>.size
        guard sampleCount > 0 else {
            return nil
        }
        var peak: Float = 0
        vDSP_maxmgv(
            data.assumingMemoryBound(to: Float.self),
            1,
            &peak,
            vDSP_Length(sampleCount)
        )
        return peak
    }

    private static func stringProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
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

    private static func formatProperty(
        objectID: AudioObjectID
    ) -> AudioStreamBasicDescription? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &size,
            &format
        )
        return status == noErr ? format : nil
    }

    private static func destroy(
        aggregateDeviceID: AudioObjectID,
        ioProcID: AudioDeviceIOProcID? = nil,
        tapID: AudioObjectID
    ) {
        if aggregateDeviceID != 0 {
            if let ioProcID {
                AudioDeviceDestroyIOProcID(
                    aggregateDeviceID,
                    ioProcID
                )
            }
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        }
        if tapID != 0 {
            AudioHardwareDestroyProcessTap(tapID)
        }
    }
}

private final class AudioActivityState: @unchecked Sendable {
    private static let audibleThreshold: Float = 0.0002

    private let lock = NSLock()
    private var hasObservedAudio = false
    private var lastAudibleTime: TimeInterval?

    func observe(peak: Float, at time: TimeInterval) {
        guard peak >= Self.audibleThreshold else {
            return
        }
        lock.lock()
        hasObservedAudio = true
        lastAudibleTime = time
        lock.unlock()
    }

    func isAudible(
        at time: TimeInterval,
        gracePeriod: TimeInterval
    ) -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        guard hasObservedAudio else {
            return nil
        }
        guard let lastAudibleTime else {
            return false
        }
        return time - lastAudibleTime <= gracePeriod
    }
}
