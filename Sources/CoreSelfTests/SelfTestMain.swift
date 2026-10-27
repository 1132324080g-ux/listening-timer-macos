import Foundation
import ListeningCore

@main
struct CoreSelfTests {
    static func main() async {
        var checks = 0

        func check(
            _ condition: @autoclosure () -> Bool,
            _ message: String
        ) {
            checks += 1
            guard condition() else {
                fputs("FAIL: \(message)\n", stderr)
                exit(1)
            }
        }

        let speaker = device(
            uid: "speaker",
            name: "MacBook Speakers",
            transport: .builtIn
        )
        check(
            ListeningDeviceClassifier.classify(
                speaker,
                manuallyTrackedDeviceUIDs: []
            ) == .notSupported,
            "Built-in speaker must not be trackable"
        )

        let jack = device(
            uid: "jack",
            name: "External Headphones",
            transport: .builtIn,
            terminalTypes: [
                ListeningDeviceClassifier.headphoneTerminalType
            ]
        )
        check(
            ListeningDeviceClassifier.classify(
                jack,
                manuallyTrackedDeviceUIDs: []
            ) == .builtInHeadphones,
            "Headphone terminal should be trackable"
        )

        let usb = device(uid: "usb", name: "USB DAC", transport: .usb)
        check(
            ListeningDeviceClassifier.classify(
                usb,
                manuallyTrackedDeviceUIDs: []
            ) == .usbAudio,
            "USB output should be trackable"
        )
        let bluetooth = device(
            uid: "bt",
            name: "AirPods",
            transport: .bluetooth
        )
        check(
            ListeningDeviceClassifier.classify(
                bluetooth,
                manuallyTrackedDeviceUIDs: []
            ) == .bluetoothAudio,
            "Bluetooth headphones should be trackable"
        )
        check(
            ListeningDeviceClassifier.classify(
                device(
                    uid: "bt-le",
                    name: "Bluetooth LE Headphones",
                    transport: .bluetoothLE
                ),
                manuallyTrackedDeviceUIDs: []
            ) == .bluetoothLEAudio,
            "Bluetooth LE headphones should be trackable"
        )
        check(
            ListeningDeviceClassifier.classify(
                device(
                    uid: "airplay",
                    name: "Living Room",
                    transport: .airPlay
                ),
                manuallyTrackedDeviceUIDs: []
            ) == .notSupported,
            "AirPlay output must not be trackable"
        )
        check(
            ListeningDeviceClassifier.classify(
                device(
                    uid: "manual",
                    name: "Display",
                    transport: .displayPort
                ),
                manuallyTrackedDeviceUIDs: ["manual"]
            ) == .manuallyApproved,
            "Manual override should classify a device as trackable"
        )

        let commonSourceIDs = Set(
            AudioSourceResolver.commonPlayers.map(\.bundleID)
        )
        check(
            commonSourceIDs.contains("com.gemd.iting")
                && commonSourceIDs.contains("com.apple.Safari")
                && commonSourceIDs.contains("com.google.Chrome"),
            "Audiobook and browser sources should be available"
        )
        check(
            AudioSourceResolver.canonicalBundleID(
                for: "com.apple.WebKit.GPU",
                processName: "Safari浏览器 Graphics and Media"
            ) == "com.apple.Safari",
            "WebKit audio helpers should resolve to Safari"
        )
        check(
            AudioProcessSnapshot(
                id: 99,
                pid: 999,
                bundleID: "com.gemd.iting",
                name: "喜马拉雅",
                outputDeviceIDs: [1],
                isRunningOutput: false,
                isRunning: true
            ).isActiveOutput,
            "Running output clients should work without the output-only flag"
        )
        check(
            AudioSourceResolver.canonicalBundleID(
                for: "com.gemd.iting.helper"
            ) == "com.gemd.iting",
            "Audiobook helper processes should resolve to the main app"
        )

        let player = PlayerIdentity(
            bundleID: "com.apple.Music",
            displayName: "Apple Music"
        )
        let activeInput = TrackingInput(
            snapshot: AudioSnapshot(
                devices: [usb],
                processes: [process()],
                defaultOutputDeviceID: usb.id
            ),
            settings: AppSettings(selectedPlayers: [player])
        )
        let evaluator = TrackingEvaluator()
        check(
            evaluator.evaluate(activeInput).status == .listening,
            "Selected player on trackable output should be active"
        )

        let bluetoothInput = TrackingInput(
            snapshot: AudioSnapshot(
                devices: [bluetooth],
                processes: [process()],
                defaultOutputDeviceID: bluetooth.id
            ),
            settings: AppSettings(selectedPlayers: [player])
        )
        check(
            evaluator.evaluate(bluetoothInput).status == .listening,
            "Selected player on Bluetooth headphones should be active"
        )

        let unselectedInput = TrackingInput(
            snapshot: activeInput.snapshot,
            settings: AppSettings(
                selectedPlayers: [
                    PlayerIdentity(
                        bundleID: "com.example.Other",
                        displayName: "Other"
                    )
                ]
            )
        )
        check(
            evaluator.evaluate(unselectedInput).status
                == .waitingForPlayback,
            "Unselected player must not count"
        )

        let muted = device(
            uid: "muted",
            name: "Muted DAC",
            transport: .usb,
            isMuted: true,
            volume: 0
        )
        check(
            evaluator.evaluate(
                TrackingInput(
                    snapshot: AudioSnapshot(
                        devices: [muted],
                        processes: [process()],
                        defaultOutputDeviceID: muted.id
                    ),
                    settings: AppSettings(selectedPlayers: [player])
                )
            ).status == .muted,
            "Muted output should not count by default"
        )
        check(
            evaluator.evaluate(
                TrackingInput(
                    snapshot: AudioSnapshot(
                        devices: [muted],
                        processes: [process()],
                        defaultOutputDeviceID: muted.id
                    ),
                    settings: AppSettings(
                        selectedPlayers: [player],
                        countWhenMuted: true
                    )
                )
            ).status == .listening,
            "Muted output should count when configured"
        )

        let tracker = ListeningTracker()
        _ = tracker.tick(
            input: activeInput,
            wallDate: Date(timeIntervalSince1970: 100),
            monotonic: 0
        )
        let oneSecond = tracker.tick(
            input: activeInput,
            wallDate: Date(timeIntervalSince1970: 101),
            monotonic: 1
        )
        check(
            oneSecond.activeSession?.accumulatedDuration == 1,
            "Tracker should accumulate one second"
        )
        let inactive = TrackingInput(
            snapshot: AudioSnapshot(
                devices: [usb],
                processes: [process(running: false)],
                defaultOutputDeviceID: usb.id
            ),
            settings: AppSettings(selectedPlayers: [player])
        )
        let grace = tracker.tick(
            input: inactive,
            wallDate: Date(timeIntervalSince1970: 101.1),
            monotonic: 1.1
        )
        check(
            grace.activeSession != nil,
            "Tracker should preserve a short grace period"
        )
        let finished = tracker.tick(
            input: inactive,
            wallDate: Date(timeIntervalSince1970: 101.2),
            monotonic: 1.2
        )
        check(
            finished.completedSession?.duration == 1,
            "Tracker should finish promptly after playback stops"
        )

        let secondBluetooth = device(
            uid: "bt-2",
            name: "Bluetooth Studio",
            transport: .bluetooth
        )
        let switchInput = TrackingInput(
            snapshot: AudioSnapshot(
                devices: [secondBluetooth],
                processes: [process()],
                defaultOutputDeviceID: secondBluetooth.id
            ),
            settings: AppSettings(selectedPlayers: [player])
        )
        let switchTracker = ListeningTracker()
        _ = switchTracker.tick(
            input: bluetoothInput,
            wallDate: Date(timeIntervalSince1970: 400),
            monotonic: 0
        )
        _ = switchTracker.tick(
            input: bluetoothInput,
            wallDate: Date(timeIntervalSince1970: 401),
            monotonic: 1
        )
        _ = switchTracker.tick(
            input: bluetoothInput,
            wallDate: Date(timeIntervalSince1970: 402),
            monotonic: 2
        )
        let switched = switchTracker.tick(
            input: switchInput,
            wallDate: Date(timeIntervalSince1970: 403),
            monotonic: 3
        )
        check(
            switched.completedSession?.deviceUID == "bt"
                && switched.completedSession?.duration == 2
                && switched.activeSession?.device.uid == "bt-2",
            "Switching Bluetooth headphones should end the old device session"
        )

        let secondProcess = AudioProcessSnapshot(
            id: 11,
            pid: 101,
            bundleID: "com.spotify.client",
            name: "Spotify",
            outputDeviceIDs: [1],
            isRunningOutput: true
        )
        let multiInput = TrackingInput(
            snapshot: AudioSnapshot(
                devices: [usb],
                processes: [process(), secondProcess],
                defaultOutputDeviceID: usb.id
            ),
            settings: AppSettings(
                selectedPlayers: [
                    player,
                    PlayerIdentity(
                        bundleID: "com.spotify.client",
                        displayName: "Spotify"
                    )
                ]
            )
        )
        let multiDecision = evaluator.evaluate(multiInput)
        check(
            Set(multiDecision.activePlayers.map(\.bundleID)) == [
                "com.apple.Music",
                "com.spotify.client"
            ],
            "Multiple players should be attributed to one wall-clock session"
        )

        let checkpointTracker = ListeningTracker()
        _ = checkpointTracker.tick(
            input: activeInput,
            wallDate: Date(timeIntervalSince1970: 200),
            monotonic: 0
        )
        var sawCheckpoint = false
        for second in 1...15 {
            let tick = checkpointTracker.tick(
                input: activeInput,
                wallDate: Date(timeIntervalSince1970: 200 + Double(second)),
                monotonic: Double(second)
            )
            sawCheckpoint = sawCheckpoint || tick.shouldCheckpoint
        }
        check(
            sawCheckpoint,
            "Tracker should request a checkpoint every 15 seconds"
        )

        let restoredTracker = ListeningTracker()
        restoredTracker.restore(
            checkpoint: ActiveSessionCheckpoint(
                session: ActiveListeningSession(
                    startedAt: Date(timeIntervalSince1970: 300),
                    accumulatedDuration: 42,
                    players: [player],
                    device: usb,
                    wasRecovered: true
                )
            ),
            at: Date(timeIntervalSince1970: 342)
        )
        check(
            restoredTracker.currentSession?.accumulatedDuration == 42
                && restoredTracker.currentSession?.wasRecovered == true,
            "Tracker should restore an interrupted session"
        )

        let combinedMenuText =
            MenuBarDurationMode.currentAndAllTime.displayText(
                current: 65,
                today: 3_600,
                allTime: 7_200
            )
        check(
            combinedMenuText?.contains("00:01:05") == true
                && combinedMenuText?.contains("总") == true,
            "Menu bar should show current and all-time values together"
        )

        let legacySettingsData = Data(
            """
            {
              "selectedPlayers": [],
              "manuallyWiredDeviceUIDs": [],
              "countWhenMuted": false,
              "trackingEnabled": true,
              "hasCompletedOnboarding": true,
              "launchAtLoginRequested": false,
              "schemaVersion": 1
            }
            """.utf8
        )
        let legacySettings = try? JSONDecoder().decode(
            AppSettings.self,
            from: legacySettingsData
        )
        check(
            legacySettings?.overviewLayout == .default
                && legacySettings?.menuBarDurationMode
                    == .currentAndAllTime
                && legacySettings?.appIconStyle == .deepSpacePurple,
            "Legacy settings should receive new appearance defaults"
        )

        var allHiddenLayout = OverviewLayoutSettings(
            hiddenWidgets: Set(OverviewWidget.allCases)
        )
        allHiddenLayout.normalize()
        check(
            !allHiddenLayout.visibleWidgets.isEmpty,
            "Overview should always keep at least one widget visible"
        )

        let calendar = utcCalendar()
        let midnightStart = calendar.date(
            from: DateComponents(
                year: 2026,
                month: 10,
                day: 26,
                hour: 23,
                minute: 30
            )
        )!
        let crossing = ListeningSession(
            startedAt: midnightStart,
            endedAt: midnightStart.addingTimeInterval(3_600),
            duration: 3_600,
            players: [player],
            deviceUID: "usb",
            deviceName: "USB DAC",
            transport: .usb
        )
        let split = ListeningStatistics.total(
            sessions: [crossing],
            in: midnightStart..<midnightStart.addingTimeInterval(
                1_800
            )
        )
        check(
            abs(split - 1_800) < 0.01,
            "Cross-midnight session should split proportionally"
        )

        let deviceSessions = [
            ListeningSession(
                startedAt: midnightStart,
                endedAt: midnightStart.addingTimeInterval(60),
                duration: 60,
                players: [player],
                deviceUID: "bt",
                deviceName: "AirPods",
                transport: .bluetooth
            ),
            ListeningSession(
                startedAt: midnightStart.addingTimeInterval(100),
                endedAt: midnightStart.addingTimeInterval(160),
                duration: 60,
                players: [player],
                deviceUID: "bt-2",
                deviceName: "Bluetooth Studio",
                transport: .bluetooth
            ),
            ListeningSession(
                startedAt: midnightStart.addingTimeInterval(200),
                endedAt: midnightStart.addingTimeInterval(230),
                duration: 30,
                players: [player],
                deviceUID: "bt",
                deviceName: "AirPods",
                transport: .bluetooth
            )
        ]
        let activeDeviceSession = ActiveListeningSession(
            startedAt: midnightStart.addingTimeInterval(300),
            accumulatedDuration: 10,
            players: [player],
            device: device(
                uid: "bt",
                name: "AirPods",
                transport: .bluetooth
            )
        )
        let deviceTotals = ListeningStatistics.deviceTotals(
            sessions: deviceSessions,
            activeSession: activeDeviceSession
        )
        let airPodsTotal = deviceTotals.first { $0.deviceUID == "bt" }
        let studioTotal = deviceTotals.first { $0.deviceUID == "bt-2" }
        check(
            deviceTotals.count == 2
                && airPodsTotal?.duration == 100
                && airPodsTotal?.sessionCount == 3
                && studioTotal?.duration == 60
                && studioTotal?.sessionCount == 1,
            "Device totals should aggregate each UID and include active time"
        )

        let csv = CSVExporter.makeCSV(
            sessions: [
                ListeningSession(
                    startedAt: Date(timeIntervalSince1970: 1_000),
                    endedAt: Date(timeIntervalSince1970: 1_060),
                    duration: 60,
                    players: [
                        PlayerIdentity(
                            bundleID: "com.example.Player",
                            displayName: "My, \"Music\""
                        )
                    ],
                    deviceUID: "usb,device",
                    deviceName: "DAC, Pro",
                    transport: .usb
                )
            ]
        )
        check(
            csv.contains("\"DAC, Pro\""),
            "CSV should escape commas"
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ListeningTimerSelfTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONSessionRepository(directory: directory)
        do {
            try await repository.saveSessions([crossing])
            let loaded = await repository.loadSessions()
            check(
                loaded.value == [crossing],
                "Repository should round-trip sessions"
            )
            let settings = AppSettings(
                selectedPlayers: [player],
                manuallyWiredDeviceUIDs: ["usb"],
                countWhenMuted: true,
                hasCompletedOnboarding: true
            )
            try await repository.saveSettings(settings)
            let loadedSettings = await repository.loadSettings()
            check(
                loadedSettings.value == settings,
                "Repository should round-trip settings"
            )
        } catch {
            fputs("FAIL: Repository error: \(error)\n", stderr)
            exit(1)
        }

        print("CoreSelfTests: \(checks) checks passed")
    }

    private static func device(
        uid: String,
        name: String,
        transport: AudioTransportKind,
        terminalTypes: Set<UInt32> = [],
        isMuted: Bool? = false,
        volume: Float? = 0.5
    ) -> AudioDeviceSnapshot {
        AudioDeviceSnapshot(
            id: 1,
            uid: uid,
            name: name,
            transport: transport,
            hasOutput: true,
            terminalTypes: terminalTypes,
            jackConnected: nil,
            isRunningSomewhere: true,
            isMuted: isMuted,
            volume: volume
        )
    }

    private static func process(
        running: Bool = true
    ) -> AudioProcessSnapshot {
        AudioProcessSnapshot(
            id: 10,
            pid: 100,
            bundleID: "com.apple.Music",
            name: "Apple Music",
            outputDeviceIDs: [1],
            isRunningOutput: running
        )
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
