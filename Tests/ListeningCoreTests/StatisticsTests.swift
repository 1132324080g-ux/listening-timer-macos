import Foundation
import Testing
@testable import ListeningCore

@Suite struct StatisticsTests {
    @Test func sessionCrossingMidnightIsSplit() throws {
        let calendar = utcCalendar()
        let day = try #require(
            calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 10,
                    day: 26,
                    hour: 23,
                    minute: 30
                )
            )
        )
        let end = day.addingTimeInterval(3_600)
        let session = ListeningSession(
            startedAt: day,
            endedAt: end,
            duration: 3_600,
            players: [player],
            deviceUID: "usb",
            deviceName: "USB DAC",
            transport: .usb
        )
        let firstDay = day..<day.addingTimeInterval(1_800)
        let secondDay =
            day.addingTimeInterval(1_800)..<day.addingTimeInterval(3_600)
        #expect(
            ListeningStatistics.total(
                sessions: [session],
                in: firstDay
            ) == 1_800
        )
        #expect(
            ListeningStatistics.total(
                sessions: [session],
                in: secondDay
            ) == 1_800
        )
    }

    @Test func dailySeriesIncludesZerosAndCorrectOrder() throws {
        let calendar = utcCalendar()
        let now = try #require(
            calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 10,
                    day: 27,
                    hour: 12
                )
            )
        )
        let yesterday = now.addingTimeInterval(-86_400)
        let session = ListeningSession(
            startedAt: yesterday,
            endedAt: yesterday.addingTimeInterval(60),
            duration: 60,
            players: [player],
            deviceUID: "jack",
            deviceName: "Earphones",
            transport: .builtIn
        )
        let series = ListeningStatistics.dailySeries(
            sessions: [session],
            endingAt: now,
            days: 7,
            calendar: calendar
        )
        #expect(series.count == 7)
        #expect(series[5].duration == 60)
        #expect(series[6].duration == 0)
    }

    @Test func multiPlayerSourceDurationsCanOverlap() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = ListeningSession(
            startedAt: start,
            endedAt: start.addingTimeInterval(120),
            duration: 120,
            players: [
                player,
                PlayerIdentity(
                    bundleID: "com.spotify.client",
                    displayName: "Spotify"
                )
            ],
            deviceUID: "usb",
            deviceName: "DAC",
            transport: .usb
        )
        let totals = ListeningStatistics.playerTotals(
            sessions: [session],
            in: start..<start.addingTimeInterval(200)
        )
        #expect(totals.count == 2)
        #expect(totals.allSatisfy { $0.duration == 120 })
    }

    @Test func rangeTotalsUseOnlyOverlappingTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = ListeningSession(
            startedAt: start,
            endedAt: start.addingTimeInterval(100),
            duration: 100,
            players: [player],
            deviceUID: "usb",
            deviceName: "DAC",
            transport: .usb
        )
        let total = ListeningStatistics.total(
            sessions: [session],
            in: start.addingTimeInterval(25)..<start.addingTimeInterval(
                75
            )
        )
        #expect(abs(total - 50) < 0.01)
    }

    @Test func deviceTotalsGroupByDeviceUID() {
        let start = Date(timeIntervalSince1970: 2_000)
        let sessions = [
            ListeningSession(
                startedAt: start,
                endedAt: start.addingTimeInterval(60),
                duration: 60,
                players: [player],
                deviceUID: "airpods-pro",
                deviceName: "AirPods Pro",
                transport: .bluetooth
            ),
            ListeningSession(
                startedAt: start.addingTimeInterval(100),
                endedAt: start.addingTimeInterval(160),
                duration: 60,
                players: [player],
                deviceUID: "studio",
                deviceName: "Bluetooth Studio",
                transport: .bluetooth
            ),
            ListeningSession(
                startedAt: start.addingTimeInterval(200),
                endedAt: start.addingTimeInterval(230),
                duration: 30,
                players: [player],
                deviceUID: "airpods-pro",
                deviceName: "AirPods Pro",
                transport: .bluetooth
            )
        ]

        let totals = ListeningStatistics.deviceTotals(sessions: sessions)
        let airPods = totals.first { $0.deviceUID == "airpods-pro" }
        let studio = totals.first { $0.deviceUID == "studio" }
        #expect(totals.count == 2)
        #expect(airPods?.duration == 90)
        #expect(airPods?.sessionCount == 2)
        #expect(studio?.duration == 60)
        #expect(studio?.sessionCount == 1)
    }

    @Test func deviceTotalsIncludeTheActiveSession() {
        let start = Date(timeIntervalSince1970: 3_000)
        let completed = ListeningSession(
            startedAt: start,
            endedAt: start.addingTimeInterval(30),
            duration: 30,
            players: [player],
            deviceUID: "airpods-pro",
            deviceName: "AirPods Pro",
            transport: .bluetooth
        )
        let active = ActiveListeningSession(
            startedAt: start.addingTimeInterval(60),
            accumulatedDuration: 12,
            players: [player],
            device: makeDevice(
                id: 2,
                uid: "airpods-pro",
                name: "AirPods Pro",
                transport: .bluetooth
            )
        )

        let totals = ListeningStatistics.deviceTotals(
            sessions: [completed],
            activeSession: active
        )
        #expect(totals.count == 1)
        #expect(totals.first?.duration == 42)
        #expect(totals.first?.sessionCount == 2)
    }

    var player: PlayerIdentity {
        PlayerIdentity(
            bundleID: "com.apple.Music",
            displayName: "Apple Music"
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
