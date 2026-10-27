import Foundation
import Testing
@testable import ListeningCore

@Suite struct TrackingTests {
    private let evaluator = TrackingEvaluator()

    @Test func selectedPlayerOnTrackableDeviceIsActive() {
        let decision = evaluator.evaluate(
            makeInput(
                device: makeDevice(),
                processes: [makeProcess()]
            )
        )
        #expect(decision.status == .listening)
        #expect(decision.activePlayers.first?.bundleID == "com.apple.Music")
    }

    @Test func unselectedPlayerDoesNotCount() {
        let decision = evaluator.evaluate(
            makeInput(
                device: makeDevice(),
                processes: [makeProcess()]
            )
        )
        let unselected = TrackingEvaluator().evaluate(
            TrackingInput(
                snapshot: AudioSnapshot(
                    devices: [makeDevice()],
                    processes: [makeProcess()],
                    defaultOutputDeviceID: 1
                ),
                settings: AppSettings(
                    selectedPlayers: [
                        PlayerIdentity(
                            bundleID: "com.example.Player",
                            displayName: "Other"
                        )
                    ]
                )
            )
        )
        #expect(decision.status == .listening)
        #expect(unselected.status == .waitingForPlayback)
    }

    @Test func selectedPlayerOnBluetoothHeadphonesIsActive() {
        let decision = evaluator.evaluate(
            makeInput(
                device: makeDevice(transport: .bluetooth),
                processes: [makeProcess()]
            )
        )
        #expect(decision.status == .listening)
        #expect(decision.device?.transport == .bluetooth)
    }

    @Test func selectedPlayerOnBluetoothLEHeadphonesIsActive() {
        let decision = evaluator.evaluate(
            makeInput(
                device: makeDevice(transport: .bluetoothLE),
                processes: [makeProcess()]
            )
        )
        #expect(decision.status == .listening)
        #expect(decision.device?.transport == .bluetoothLE)
    }

    @Test func browserAudioHelperIsAttributedToBrowserSource() {
        let decision = evaluator.evaluate(
            TrackingInput(
                snapshot: AudioSnapshot(
                    devices: [makeDevice()],
                    processes: [
                        makeProcess(
                            bundleID: "com.apple.WebKit.GPU",
                            name: "Safari浏览器 Graphics and Media"
                        )
                    ],
                    defaultOutputDeviceID: 1
                ),
                settings: AppSettings(
                    selectedPlayers: [
                        PlayerIdentity(
                            bundleID: "com.apple.Safari",
                            displayName: "Safari"
                        )
                    ]
                )
            )
        )
        #expect(decision.status == .listening)
        #expect(decision.activePlayers.first?.bundleID == "com.apple.Safari")
        #expect(decision.activePlayers.first?.displayName == "Safari")
    }

    @Test func commonSourcesIncludeAudiobooksAndBrowsers() {
        let bundleIDs = Set(AudioSourceResolver.commonPlayers.map(\.bundleID))
        #expect(bundleIDs.contains("com.gemd.iting"))
        #expect(bundleIDs.contains("com.apple.Safari"))
        #expect(bundleIDs.contains("com.google.Chrome"))
        #expect(bundleIDs.contains("org.mozilla.firefox"))
    }

    @Test func runningProcessWithOutputIsTreatedAsActive() {
        let process = AudioProcessSnapshot(
            id: 10,
            pid: 100,
            bundleID: "com.gemd.iting",
            name: "喜马拉雅",
            outputDeviceIDs: [1],
            isRunningOutput: false,
            isRunning: true
        )
        #expect(process.isActiveOutput)
        let decision = evaluator.evaluate(
            TrackingInput(
                snapshot: AudioSnapshot(
                    devices: [makeDevice()],
                    processes: [process],
                    defaultOutputDeviceID: 1
                ),
                settings: AppSettings(
                    selectedPlayers: [
                        PlayerIdentity(
                            bundleID: "com.gemd.iting",
                            displayName: "喜马拉雅"
                        )
                    ]
                )
            )
        )
        #expect(decision.status == .listening)
    }

    @Test func audiobookHelperProcessIsAttributedToMainApp() {
        let process = AudioProcessSnapshot(
            id: 11,
            pid: 101,
            bundleID: "com.gemd.iting.helper",
            name: "com.gemd.iting.helper",
            outputDeviceIDs: [1],
            isRunningOutput: true
        )
        let decision = evaluator.evaluate(
            TrackingInput(
                snapshot: AudioSnapshot(
                    devices: [makeDevice()],
                    processes: [process],
                    defaultOutputDeviceID: 1
                ),
                settings: AppSettings(
                    selectedPlayers: [
                        PlayerIdentity(
                            bundleID: "com.gemd.iting",
                            displayName: "喜马拉雅"
                        )
                    ]
                )
            )
        )
        #expect(decision.status == .listening)
        #expect(decision.activePlayers.first?.bundleID == "com.gemd.iting")
        #expect(decision.activePlayers.first?.displayName == "喜马拉雅")
    }

    @Test func nonHeadphoneOutputDoesNotCount() {
        let decision = evaluator.evaluate(
            makeInput(
                device: makeDevice(transport: .airPlay),
                processes: [makeProcess()]
            )
        )
        #expect(decision.status == .waitingForDevice)
    }

    @Test func mutedDeviceRespectsSetting() {
        let muted = makeDevice(isMuted: true, volume: 0)
        let excluded = evaluator.evaluate(
            makeInput(device: muted, processes: [makeProcess()])
        )
        #expect(excluded.status == .muted)

        var settings = AppSettings(
            selectedPlayers: [
                PlayerIdentity(
                    bundleID: "com.apple.Music",
                    displayName: "Apple Music"
                )
            ],
            countWhenMuted: true
        )
        settings.trackingEnabled = true
        let included = evaluator.evaluate(
            TrackingInput(
                snapshot: AudioSnapshot(
                    devices: [muted],
                    processes: [makeProcess()],
                    defaultOutputDeviceID: 1
                ),
                settings: settings
            )
        )
        #expect(included.status == .listening)
    }

    @Test func defaultOutputFallbackIsUsedWhenProcessDevicesAreEmpty() {
        let decision = evaluator.evaluate(
            makeInput(
                device: makeDevice(),
                processes: [makeProcess(outputDeviceIDs: [])]
            )
        )
        #expect(decision.status == .listening)
    }

    @Test func silentTapOverridesLaggingRunningOutputFlag() {
        let process = makeProcess(isRunningOutput: true)
        let decision = evaluator.evaluate(
            TrackingInput(
                snapshot: AudioSnapshot(
                    devices: [makeDevice()],
                    processes: [process],
                    defaultOutputDeviceID: 1
                ),
                settings: AppSettings(
                    selectedPlayers: [
                        PlayerIdentity(
                            bundleID: "com.apple.Music",
                            displayName: "Apple Music"
                        )
                    ]
                ),
                processAudioActivity: [process.id: false]
            )
        )
        #expect(decision.status == .waitingForPlayback)
        #expect(decision.activePlayers.isEmpty)
    }

    @Test func multiplePlayersAreUnionedIntoOneSession() {
        let second = makeProcess(
            bundleID: "com.spotify.client",
            name: "Spotify"
        )
        let input = TrackingInput(
            snapshot: AudioSnapshot(
                devices: [makeDevice()],
                processes: [makeProcess(), second],
                defaultOutputDeviceID: 1
            ),
            settings: AppSettings(
                selectedPlayers: [
                    PlayerIdentity(
                        bundleID: "com.apple.Music",
                        displayName: "Apple Music"
                    ),
                    PlayerIdentity(
                        bundleID: "com.spotify.client",
                        displayName: "Spotify"
                    )
                ]
            )
        )
        let decision = evaluator.evaluate(input)
        #expect(
            Set(decision.activePlayers.map(\.bundleID))
                == [
                    "com.apple.Music",
                    "com.spotify.client"
                ]
        )

        let tracker = ListeningTracker()
        _ = tracker.tick(
            input: input,
            wallDate: Date(timeIntervalSince1970: 1_000),
            monotonic: 10
        )
        let tick = tracker.tick(
            input: input,
            wallDate: Date(timeIntervalSince1970: 1_001),
            monotonic: 11
        )
        #expect(tick.activeSession?.players.count == 2)
        #expect(tick.activeSession?.accumulatedDuration == 1)
    }

    @Test func trackerAccumulatesAndEndsAfterGracePeriod() {
        let tracker = ListeningTracker()
        let active = makeInput(
            device: makeDevice(),
            processes: [makeProcess()]
        )
        let inactive = makeInput(
            device: makeDevice(),
            processes: [makeProcess(isRunningOutput: false)]
        )

        _ = tracker.tick(
            input: active,
            wallDate: Date(timeIntervalSince1970: 100),
            monotonic: 0
        )
        let second = tracker.tick(
            input: active,
            wallDate: Date(timeIntervalSince1970: 101),
            monotonic: 1
        )
        #expect(second.activeSession?.accumulatedDuration == 1)

        let firstInactive = tracker.tick(
            input: inactive,
            wallDate: Date(timeIntervalSince1970: 101.1),
            monotonic: 1.1
        )
        #expect(firstInactive.activeSession != nil)
        #expect(firstInactive.completedSession == nil)

        let secondInactive = tracker.tick(
            input: inactive,
            wallDate: Date(timeIntervalSince1970: 101.2),
            monotonic: 1.2
        )
        #expect(secondInactive.activeSession == nil)
        #expect(secondInactive.completedSession?.duration == 1)
    }

    @Test func switchingBluetoothHeadphonesStartsIndependentSessions() {
        let tracker = ListeningTracker()
        let firstHeadphones = makeDevice(
            id: 1,
            uid: "bluetooth-airpods",
            name: "AirPods",
            transport: .bluetooth
        )
        let secondHeadphones = makeDevice(
            id: 2,
            uid: "bluetooth-studio",
            name: "Bluetooth Studio",
            transport: .bluetooth
        )
        let firstInput = makeInput(
            device: firstHeadphones,
            processes: [makeProcess(outputDeviceIDs: [1])]
        )
        let secondInput = TrackingInput(
            snapshot: AudioSnapshot(
                devices: [secondHeadphones],
                processes: [makeProcess(outputDeviceIDs: [2])],
                defaultOutputDeviceID: 2
            ),
            settings: firstInput.settings
        )

        _ = tracker.tick(
            input: firstInput,
            wallDate: Date(timeIntervalSince1970: 100),
            monotonic: 0
        )
        _ = tracker.tick(
            input: firstInput,
            wallDate: Date(timeIntervalSince1970: 101),
            monotonic: 1
        )
        _ = tracker.tick(
            input: firstInput,
            wallDate: Date(timeIntervalSince1970: 102),
            monotonic: 2
        )
        let switched = tracker.tick(
            input: secondInput,
            wallDate: Date(timeIntervalSince1970: 103),
            monotonic: 3
        )

        #expect(switched.completedSession?.deviceUID == "bluetooth-airpods")
        #expect(switched.completedSession?.duration == 2)
        #expect(switched.activeSession?.device.uid == "bluetooth-studio")

        _ = tracker.tick(
            input: secondInput,
            wallDate: Date(timeIntervalSince1970: 104),
            monotonic: 4
        )
        _ = tracker.tick(
            input: secondInput,
            wallDate: Date(timeIntervalSince1970: 105),
            monotonic: 5
        )
        let completedSecond = tracker.flush(
            at: Date(timeIntervalSince1970: 105)
        )
        #expect(completedSecond?.deviceUID == "bluetooth-studio")
        #expect(completedSecond?.duration == 2)
    }

    @Test func checkpointCadence() {
        let tracker = ListeningTracker()
        let input = makeInput(
            device: makeDevice(),
            processes: [makeProcess()]
        )
        _ = tracker.tick(
            input: input,
            wallDate: Date(timeIntervalSince1970: 100),
            monotonic: 0
        )
        for second in 1...14 {
            let tick = tracker.tick(
                input: input,
                wallDate: Date(timeIntervalSince1970: 100 + Double(second)),
                monotonic: Double(second)
            )
            #expect(!tick.shouldCheckpoint)
        }
        let checkpoint = tracker.tick(
            input: input,
            wallDate: Date(timeIntervalSince1970: 115),
            monotonic: 15
        )
        #expect(checkpoint.shouldCheckpoint)
        #expect(checkpoint.activeSession?.accumulatedDuration == 15)
    }

    @Test func flushProducesCompletedSession() {
        let tracker = ListeningTracker()
        let input = makeInput(
            device: makeDevice(),
            processes: [makeProcess()]
        )
        _ = tracker.tick(
            input: input,
            wallDate: Date(timeIntervalSince1970: 100),
            monotonic: 0
        )
        _ = tracker.tick(
            input: input,
            wallDate: Date(timeIntervalSince1970: 102),
            monotonic: 2
        )
        let completed = tracker.flush(
            at: Date(timeIntervalSince1970: 102)
        )
        #expect(completed?.duration == 2)
        #expect(tracker.currentSession == nil)
    }

    private func makeInput(
        device: AudioDeviceSnapshot,
        processes: [AudioProcessSnapshot]
    ) -> TrackingInput {
        TrackingInput(
            snapshot: AudioSnapshot(
                devices: [device],
                processes: processes,
                defaultOutputDeviceID: device.id
            ),
            settings: AppSettings(
                selectedPlayers: [
                    PlayerIdentity(
                        bundleID: "com.apple.Music",
                        displayName: "Apple Music"
                    )
                ]
            )
        )
    }
}
