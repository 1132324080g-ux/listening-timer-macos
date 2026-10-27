import Foundation

public enum ListeningDeviceClassification: Equatable, Sendable {
    case builtInHeadphones
    case usbAudio
    case thunderboltAudio
    case fireWireAudio
    case bluetoothAudio
    case bluetoothLEAudio
    case manuallyApproved
    case notSupported

    public var isTrackable: Bool {
        self != .notSupported
    }

    public var isBluetooth: Bool {
        self == .bluetoothAudio || self == .bluetoothLEAudio
    }

    public var title: String {
        switch self {
        case .builtInHeadphones: "3.5 mm 耳机"
        case .usbAudio: "USB 音频"
        case .thunderboltAudio: "雷雳音频"
        case .fireWireAudio: "FireWire 音频"
        case .bluetoothAudio: "蓝牙耳机"
        case .bluetoothLEAudio: "低功耗蓝牙耳机"
        case .manuallyApproved: "手动指定"
        case .notSupported: "不参与计时"
        }
    }
}

public enum ListeningDeviceClassifier {
    public static let headphoneTerminalType: UInt32 = 0x6864_7068 // 'hdph'

    public static func classify(
        _ device: AudioDeviceSnapshot,
        manuallyTrackedDeviceUIDs: Set<String>
    ) -> ListeningDeviceClassification {
        guard device.hasOutput else {
            return .notSupported
        }

        if manuallyTrackedDeviceUIDs.contains(device.uid) {
            return .manuallyApproved
        }

        switch device.transport {
        case .usb:
            return .usbAudio
        case .thunderbolt:
            return .thunderboltAudio
        case .fireWire:
            return .fireWireAudio
        case .bluetooth:
            return .bluetoothAudio
        case .bluetoothLE:
            return .bluetoothLEAudio
        case .builtIn:
            let lowerName = device.name.lowercased()
            let looksLikeHeadphones =
                device.terminalTypes.contains(headphoneTerminalType)
                || lowerName.contains("headphone")
                || lowerName.contains("earphone")
                || device.name.contains("耳机")
                || device.name.contains("耳機")
            let jackReportsConnected = device.jackConnected == true
            return looksLikeHeadphones || jackReportsConnected
                ? .builtInHeadphones
                : .notSupported
        case .airPlay, .hdmi,
             .displayPort, .pci, .virtual, .aggregate, .other:
            return .notSupported
        }
    }
}

public struct TrackingEvaluator: Sendable {
    public init() {}

    public func evaluate(_ input: TrackingInput) -> TrackingDecision {
        let settings = input.settings
        guard settings.trackingEnabled else {
            return TrackingDecision(status: .paused)
        }
        guard !settings.selectedPlayers.isEmpty else {
            return TrackingDecision(status: .noPlayers)
        }

        let selectedPlayersByBundleID = Dictionary(
            settings.selectedPlayers.map {
                (
                    AudioSourceResolver.canonicalBundleID(
                        for: $0.bundleID,
                        processName: $0.displayName
                    ),
                    $0
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
        let selectedBundleIDs = Set(selectedPlayersByBundleID.keys)
        let trackableDevices = input.snapshot.devices.filter { device in
            let classification = ListeningDeviceClassifier.classify(
                device,
                manuallyTrackedDeviceUIDs: settings.manuallyWiredDeviceUIDs
            )
            guard classification.isTrackable else {
                return false
            }
            return device.isRunningSomewhere
                && (settings.countWhenMuted || device.isAudible)
        }

        guard !trackableDevices.isEmpty else {
            let trackableDevices = input.snapshot.devices.filter { device in
                let classification = ListeningDeviceClassifier.classify(
                    device,
                    manuallyTrackedDeviceUIDs: settings.manuallyWiredDeviceUIDs
                )
                return classification.isTrackable
            }
            let hasTrackableButMuted = trackableDevices.contains {
                !$0.isAudible && !settings.countWhenMuted
            }
            return TrackingDecision(
                status: hasTrackableButMuted ? .muted : .waitingForDevice
            )
        }

        let deviceByID = Dictionary(
            uniqueKeysWithValues: trackableDevices.map { ($0.id, $0) }
        )
        let activeProcesses = input.snapshot.processes.filter { process in
            let sourceBundleID = AudioSourceResolver.canonicalBundleID(
                for: process.bundleID,
                processName: process.name
            )
            guard selectedBundleIDs.contains(sourceBundleID) else {
                return false
            }
            return input.processAudioActivity[process.id]
                ?? process.isActiveOutput
        }

        var activePlayers: [PlayerIdentity] = []
        var activeDevice: AudioDeviceSnapshot?
        for process in activeProcesses {
            let matchingDeviceIDs: [UInt32]
            if process.outputDeviceIDs.isEmpty,
               let defaultID = input.snapshot.defaultOutputDeviceID,
               deviceByID[defaultID] != nil {
                matchingDeviceIDs = [defaultID]
            } else {
                matchingDeviceIDs = process.outputDeviceIDs
            }

            if let matchingID = matchingDeviceIDs.first(where: {
                deviceByID[$0] != nil
            }), let device = deviceByID[matchingID] {
                let sourceBundleID =
                    AudioSourceResolver.canonicalBundleID(
                        for: process.bundleID,
                        processName: process.name
                    )
                let activePlayer = PlayerIdentity(
                    bundleID: sourceBundleID,
                    displayName:
                        selectedPlayersByBundleID[sourceBundleID]?.displayName
                        ?? AudioSourceResolver.displayName(
                            for: sourceBundleID
                        )
                        ?? process.name
                )
                if !activePlayers.contains(where: {
                    $0.bundleID == activePlayer.bundleID
                }) {
                    activePlayers.append(activePlayer)
                }
                if activeDevice == nil {
                    activeDevice = device
                }
            }
        }

        if !activePlayers.isEmpty, let activeDevice {
            return TrackingDecision(
                status: .listening,
                activePlayers: activePlayers,
                device: activeDevice
            )
        }

        return TrackingDecision(
            status: .waitingForPlayback,
            device: trackableDevices.first
        )
    }
}
