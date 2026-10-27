import Foundation
import Testing
@testable import ListeningCore

@Suite struct PersistenceTests {
    @Test func repositoryRoundTrip() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONSessionRepository(
            directory: directory
        )
        let session = sampleSession
        let settings = AppSettings(
            selectedPlayers: session.players,
            manuallyWiredDeviceUIDs: ["dac"],
            deviceAliases: ["device": "书房耳机"],
            countWhenMuted: true,
            hasCompletedOnboarding: true,
            launchAtLoginRequested: true
        )
        try await repository.saveSessions([session])
        try await repository.saveSettings(settings)
        let loadedSessions = await repository.loadSessions()
        let loadedSettings = await repository.loadSettings()
        #expect(loadedSessions.value == [session])
        #expect(loadedSettings.value == settings)
    }

    @Test func checkpointRoundTripAndRemoval() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONSessionRepository(directory: directory)
        let checkpoint = ActiveSessionCheckpoint(
            session: ActiveListeningSession(
                startedAt: Date(timeIntervalSince1970: 100),
                accumulatedDuration: 42,
                players: [sampleSession.players[0]],
                device: makeDevice(),
                wasRecovered: true
            )
        )
        try await repository.saveCheckpoint(checkpoint)
        let loaded = await repository.loadCheckpoint()
        #expect(loaded == checkpoint)
        try await repository.saveCheckpoint(nil)
        let removed = await repository.loadCheckpoint()
        #expect(removed == nil)
    }

    @Test func corruptHistoryIsPreservedWithoutSilentDelete() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONSessionRepository(directory: directory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let sessionsURL = directory.appendingPathComponent("sessions.json")
        try Data("not-json".utf8).write(to: sessionsURL)

        let result = await repository.loadSessions()

        #expect(result.value.isEmpty)
        #expect(result.warnings.count == 1)
        #expect(FileManager.default.fileExists(atPath: sessionsURL.path))
        let files = try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        )
        #expect(files.contains { $0.contains("corrupt") })
    }

    @Test func clearRemovesHistoryAndCheckpoint() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONSessionRepository(directory: directory)
        try await repository.saveSessions([sampleSession])
        try await repository.saveCheckpoint(
            ActiveSessionCheckpoint(
                session: ActiveListeningSession(
                    startedAt: Date(),
                    accumulatedDuration: 5,
                    players: sampleSession.players,
                    device: makeDevice()
                )
            )
        )

        try await repository.clearSessions()

        let loaded = await repository.loadSessions()
        let checkpoint = await repository.loadCheckpoint()
        #expect(loaded.value.isEmpty)
        #expect(checkpoint == nil)
    }

    @Test func deviceAliasesNormalizeAndCanBeCleared() {
        var settings = AppSettings.default

        settings.setDeviceAlias(
            "  书房蓝牙耳机 \n",
            forDeviceUID: "bluetooth-studio"
        )
        #expect(
            settings.deviceDisplayName(
                uid: "bluetooth-studio",
                fallback: "Studio Headphones"
            ) == "书房蓝牙耳机"
        )

        settings.setDeviceAlias("   ", forDeviceUID: "bluetooth-studio")
        #expect(
            settings.deviceDisplayName(
                uid: "bluetooth-studio",
                fallback: "Studio Headphones"
            ) == "Studio Headphones"
        )
        #expect(settings.deviceAliases.isEmpty)
    }

    @Test func settingsWithoutDeviceAliasesRemainCompatible() throws {
        let data = Data(
            #"{"selectedPlayers":[],"schemaVersion":2}"#.utf8
        )

        let decoded = try JSONDecoder().decode(
            AppSettings.self,
            from: data
        )

        #expect(decoded.deviceAliases.isEmpty)
        #expect(decoded.schemaVersion == 2)
    }

    private var sampleSession: ListeningSession {
        ListeningSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_120),
            duration: 120,
            players: [
                PlayerIdentity(
                    bundleID: "com.apple.Music",
                    displayName: "Apple Music"
                )
            ],
            deviceUID: "device",
            deviceName: "Headphones",
            transport: .usb
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ListeningTimerTests-\(UUID())")
    }
}
