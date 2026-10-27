import Foundation

public struct DateRangeTotal: Equatable, Sendable {
    public let range: Range<Date>
    public let duration: TimeInterval

    public init(range: Range<Date>, duration: TimeInterval) {
        self.range = range
        self.duration = duration
    }
}

public struct DailyListeningTotal: Identifiable, Equatable, Sendable {
    public let day: Date
    public let duration: TimeInterval

    public var id: Date { day }

    public init(day: Date, duration: TimeInterval) {
        self.day = day
        self.duration = duration
    }
}

public struct PlayerListeningTotal: Identifiable, Equatable, Sendable {
    public let player: PlayerIdentity
    public let duration: TimeInterval

    public var id: String { player.bundleID }

    public init(player: PlayerIdentity, duration: TimeInterval) {
        self.player = player
        self.duration = duration
    }
}

public struct DeviceListeningTotal: Identifiable, Equatable, Sendable {
    public let deviceUID: String
    public let deviceName: String
    public let transport: AudioTransportKind
    public let duration: TimeInterval
    public let sessionCount: Int

    public var id: String { deviceUID }

    public init(
        deviceUID: String,
        deviceName: String,
        transport: AudioTransportKind,
        duration: TimeInterval,
        sessionCount: Int
    ) {
        self.deviceUID = deviceUID
        self.deviceName = deviceName
        self.transport = transport
        self.duration = duration
        self.sessionCount = sessionCount
    }
}

public enum ListeningStatistics {
    public static func total(
        sessions: [ListeningSession],
        in range: Range<Date>
    ) -> TimeInterval {
        sessions.reduce(0) { result, session in
            result + duration(of: session, intersecting: range)
        }
    }

    public static func todayRange(
        now: Date,
        calendar: Calendar
    ) -> Range<Date> {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        return start..<end
    }

    public static func weekRange(
        now: Date,
        calendar: Calendar
    ) -> Range<Date> {
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(
            of: .weekOfYear,
            for: today
        )?.start ?? today
        let weekEnd =
            calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        return weekStart..<weekEnd
    }

    public static func monthRange(
        now: Date,
        calendar: Calendar
    ) -> Range<Date> {
        let monthStart = calendar.dateInterval(
            of: .month,
            for: now
        )?.start ?? calendar.startOfDay(for: now)
        let monthEnd =
            calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        return monthStart..<monthEnd
    }

    public static func allTimeRange(
        sessions: [ListeningSession],
        now: Date
    ) -> Range<Date> {
        let start =
            sessions.map(\.startedAt).min()
            ?? Calendar.current.startOfDay(for: now)
        let end =
            sessions.map(\.endedAt).max()
            ?? now
        return start..<max(end, start.addingTimeInterval(1))
    }

    public static func dailySeries(
        sessions: [ListeningSession],
        endingAt now: Date,
        days: Int,
        calendar: Calendar
    ) -> [DailyListeningTotal] {
        guard days > 0 else {
            return []
        }
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(
                byAdding: .day,
                value: -(days - offset - 1),
                to: today
            ), let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
            else {
                return nil
            }
            return DailyListeningTotal(
                day: day,
                duration: total(sessions: sessions, in: day..<nextDay)
            )
        }
    }

    public static func playerTotals(
        sessions: [ListeningSession],
        in range: Range<Date>
    ) -> [PlayerListeningTotal] {
        var totals: [String: (PlayerIdentity, TimeInterval)] = [:]
        for session in sessions {
            let listened = duration(of: session, intersecting: range)
            guard listened > 0 else {
                continue
            }
            for player in session.players {
                let previous = totals[player.bundleID]?.1 ?? 0
                totals[player.bundleID] = (player, previous + listened)
            }
        }
        return totals.values
            .map(PlayerListeningTotal.init)
            .sorted { $0.duration > $1.duration }
    }

    public static func deviceTotals(
        sessions: [ListeningSession],
        activeSession: ActiveListeningSession? = nil
    ) -> [DeviceListeningTotal] {
        struct Aggregate {
            var name: String
            var transport: AudioTransportKind
            var duration: TimeInterval
            var sessionCount: Int
        }

        var totals: [String: Aggregate] = [:]
        for session in sessions where session.duration > 0 {
            let previous = totals[session.deviceUID]
            totals[session.deviceUID] = Aggregate(
                name: session.deviceName,
                transport: session.transport,
                duration: (previous?.duration ?? 0) + session.duration,
                sessionCount: (previous?.sessionCount ?? 0) + 1
            )
        }
        if let activeSession {
            let device = activeSession.device
            let previous = totals[device.uid]
            totals[device.uid] = Aggregate(
                name: device.name,
                transport: device.transport,
                duration:
                    (previous?.duration ?? 0)
                    + activeSession.accumulatedDuration,
                sessionCount: (previous?.sessionCount ?? 0) + 1
            )
        }
        return totals.map { uid, total in
            DeviceListeningTotal(
                deviceUID: uid,
                deviceName: total.name,
                transport: total.transport,
                duration: total.duration,
                sessionCount: total.sessionCount
            )
        }
        .sorted {
            if $0.duration == $1.duration {
                return $0.deviceName.localizedStandardCompare(
                    $1.deviceName
                ) == .orderedAscending
            }
            return $0.duration > $1.duration
        }
    }

    public static func duration(
        of session: ListeningSession,
        intersecting range: Range<Date>
    ) -> TimeInterval {
        let wallDuration = session.endedAt.timeIntervalSince(session.startedAt)
        guard wallDuration > 0 else {
            return range.contains(session.startedAt) ? session.duration : 0
        }
        let overlapStart = max(session.startedAt, range.lowerBound)
        let overlapEnd = min(session.endedAt, range.upperBound)
        guard overlapEnd > overlapStart else {
            return 0
        }
        let overlap = overlapEnd.timeIntervalSince(overlapStart)
        return session.duration * min(1, overlap / wallDuration)
    }
}

public enum DurationFormatter {
    public static func compact(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分"
        }
        if minutes > 0 {
            return "\(minutes) 分钟"
        }
        return "\(seconds) 秒"
    }

    public static func clock(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        return String(
            format: "%02d:%02d:%02d",
            seconds / 3_600,
            (seconds % 3_600) / 60,
            seconds % 60
        )
    }

    public static func short(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        if seconds < 60 {
            return "\(seconds) 秒"
        }
        if seconds < 3_600 {
            return "\(seconds / 60) 分"
        }
        let hours = Double(seconds) / 3_600
        return String(format: hours >= 10 ? "%.0f 小时" : "%.1f 小时", hours)
    }
}
