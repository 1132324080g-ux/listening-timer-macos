import Foundation
import Testing
@testable import ListeningCore

@Suite struct AudioDetectionTests {
    @Test func builtInSpeakerIsNotTrackable() {
        let device = makeDevice(
            uid: "speaker",
            name: "MacBook Pro 扬声器",
            transport: .builtIn,
            terminalTypes: []
        )
        #expect(
            ListeningDeviceClassifier.classify(
                device,
                manuallyTrackedDeviceUIDs: []
            ) == .notSupported
        )
    }

    @Test func builtInHeadphoneTerminalIsTrackable() {
        let device = makeDevice(
            uid: "jack",
            name: "外置耳机",
            transport: .builtIn,
            terminalTypes: [
                ListeningDeviceClassifier.headphoneTerminalType
            ]
        )
        #expect(
            ListeningDeviceClassifier.classify(
                device,
                manuallyTrackedDeviceUIDs: []
            ) == .builtInHeadphones
        )
    }

    @Test func connectedJackIsTrackable() {
        let device = makeDevice(
            uid: "jack",
            name: "内置输出",
            transport: .builtIn,
            jackConnected: true
        )
        #expect(
            ListeningDeviceClassifier.classify(
                device,
                manuallyTrackedDeviceUIDs: []
            ) == .builtInHeadphones
        )
    }

    @Test func usbAndThunderboltAreTrackable() {
        #expect(
            ListeningDeviceClassifier.classify(
                makeDevice(uid: "usb", name: "DAC", transport: .usb),
                manuallyTrackedDeviceUIDs: []
            ) == .usbAudio
        )
        #expect(
            ListeningDeviceClassifier.classify(
                makeDevice(
                    uid: "tb",
                    name: "Audio Interface",
                    transport: .thunderbolt
                ),
                manuallyTrackedDeviceUIDs: []
            ) == .thunderboltAudio
        )
    }

    @Test func bluetoothDevicesAreTrackable() {
        #expect(
            ListeningDeviceClassifier.classify(
                makeDevice(
                    uid: "bt",
                    name: "AirPods",
                    transport: .bluetooth
                ),
                manuallyTrackedDeviceUIDs: []
            ) == .bluetoothAudio
        )
        #expect(
            ListeningDeviceClassifier.classify(
                makeDevice(
                    uid: "bt-le",
                    name: "Bluetooth LE Headphones",
                    transport: .bluetoothLE
                ),
                manuallyTrackedDeviceUIDs: []
            ) == .bluetoothLEAudio
        )
    }

    @Test func nonHeadphoneAndVirtualDevicesAreExcluded() {
        for transport in [
            AudioTransportKind.airPlay,
            .hdmi,
            .displayPort,
            .virtual,
            .aggregate
        ] {
            let classification = ListeningDeviceClassifier.classify(
                makeDevice(
                    uid: transport.rawValue,
                    name: transport.rawValue,
                    transport: transport
                ),
                manuallyTrackedDeviceUIDs: []
            )
            #expect(classification == .notSupported)
        }
    }

    @Test func manualApprovalOverridesAutomaticClassification() {
        let device = makeDevice(
            uid: "studio-display",
            name: "Studio Display",
            transport: .displayPort
        )
        #expect(
            ListeningDeviceClassifier.classify(
                device,
                manuallyTrackedDeviceUIDs: ["studio-display"]
            ) == .manuallyApproved
        )
    }

    @Test func inputOnlyDeviceIsNotTrackable() {
        #expect(
            ListeningDeviceClassifier.classify(
                makeDevice(
                    uid: "mic",
                    name: "USB Microphone",
                    transport: .usb,
                    hasOutput: false
                ),
                manuallyTrackedDeviceUIDs: []
            ) == .notSupported
        )
    }
}

func makeDevice(
    id: UInt32 = 1,
    uid: String = "device",
    name: String = "Headphones",
    transport: AudioTransportKind = .usb,
    hasOutput: Bool = true,
    terminalTypes: Set<UInt32> = [],
    jackConnected: Bool? = nil,
    isRunningSomewhere: Bool = true,
    isMuted: Bool? = false,
    volume: Float? = 0.5
) -> AudioDeviceSnapshot {
    AudioDeviceSnapshot(
        id: id,
        uid: uid,
        name: name,
        transport: transport,
        hasOutput: hasOutput,
        terminalTypes: terminalTypes,
        jackConnected: jackConnected,
        isRunningSomewhere: isRunningSomewhere,
        isMuted: isMuted,
        volume: volume
    )
}

func makeProcess(
    bundleID: String = "com.apple.Music",
    name: String = "Apple Music",
    outputDeviceIDs: [UInt32] = [1],
    isRunningOutput: Bool = true
) -> AudioProcessSnapshot {
    AudioProcessSnapshot(
        id: 10,
        pid: 100,
        bundleID: bundleID,
        name: name,
        outputDeviceIDs: outputDeviceIDs,
        isRunningOutput: isRunningOutput
    )
}
