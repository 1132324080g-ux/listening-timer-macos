import Foundation

public struct TrackingTickResult: Equatable, Sendable {
    public let decision: TrackingDecision
    public let activeSession: ActiveListeningSession?
    public let completedSession: ListeningSession?
    public let shouldCheckpoint: Bool

    public init(
        decision: TrackingDecision,
        activeSession: ActiveListeningSession?,
        completedSession: ListeningSession?,
        shouldCheckpoint: Bool
    ) {
        self.decision = decision
        self.activeSession = activeSession
        self.completedSession = completedSession
        self.shouldCheckpoint = shouldCheckpoint
    }
}

public final class ListeningTracker {
    public static let stopGracePeriod: TimeInterval = 0.15
    public static let checkpointInterval: TimeInterval = 15
    public static let maximumTickDelta: TimeInterval = 2

    private let evaluator: TrackingEvaluator
    private var activeSession: ActiveListeningSession?
    private var previousMonotonic: TimeInterval?
    private var lastActiveMonotonic: TimeInterval?
    private var lastActiveWallDate: Date?
    private var lastCheckpointMonotonic: TimeInterval?
    private var lastWasActive = false
    private(set) public var latestDecision = TrackingDecision(status: .unavailable)

    public init(evaluator: TrackingEvaluator = TrackingEvaluator()) {
        self.evaluator = evaluator
    }

    public var currentSession: ActiveListeningSession? {
        activeSession
    }

    public func restore(checkpoint: ActiveSessionCheckpoint?, at now: Date) {
        guard let checkpoint, checkpoint.accumulatedDuration >= 1 else {
            return
        }
        let recoveredDevice = AudioDeviceSnapshot(
            id: 0,
            uid: checkpoint.deviceUID,
            name: checkpoint.deviceName,
            transport: checkpoint.transport,
            hasOutput: true
        )
        activeSession = ActiveListeningSession(
            startedAt: checkpoint.startedAt,
            accumulatedDuration: checkpoint.accumulatedDuration,
            players: checkpoint.players,
            device: recoveredDevice,
            wasRecovered: true
        )
        lastActiveWallDate = now
    }

    @discardableResult
    public func tick(
        input: TrackingInput,
        wallDate: Date,
        monotonic: TimeInterval
    ) -> TrackingTickResult {
        let decision = evaluator.evaluate(input)
        latestDecision = decision
        var completed: ListeningSession?
        var startedNewSession = false

        if decision.isActive, let currentDevice = decision.device {
            if let existing = activeSession,
               existing.device.uid != currentDevice.uid {
                completed = finishSession(at: wallDate)
            }

            if activeSession == nil {
                activeSession = ActiveListeningSession(
                    startedAt: wallDate,
                    accumulatedDuration: 0,
                    players: decision.activePlayers,
                    device: currentDevice
                )
                lastCheckpointMonotonic = monotonic
                startedNewSession = true
            } else {
                activeSession?.device = currentDevice
                if var current = activeSession {
                    merge(players: decision.activePlayers, into: &current)
                    activeSession = current
                }
                if lastWasActive,
                   let previousMonotonic,
                   monotonic >= previousMonotonic {
                    let delta = min(
                        monotonic - previousMonotonic,
                        Self.maximumTickDelta
                    )
                    activeSession?.accumulatedDuration += delta
                }
            }
            lastActiveMonotonic = monotonic
            lastActiveWallDate = wallDate
            lastWasActive = true
        } else {
            lastWasActive = false
            if activeSession != nil, let lastActiveMonotonic {
                let inactiveFor = monotonic - lastActiveMonotonic
                if inactiveFor >= Self.stopGracePeriod {
                    completed = finishSession(at: lastActiveWallDate ?? wallDate)
                }
            }
        }

        previousMonotonic = monotonic
        let shouldCheckpoint =
            activeSession != nil
            && !startedNewSession
            && monotonic - (lastCheckpointMonotonic ?? monotonic)
                >= Self.checkpointInterval
        if shouldCheckpoint {
            lastCheckpointMonotonic = monotonic
        }

        return TrackingTickResult(
            decision: decision,
            activeSession: activeSession,
            completedSession: completed,
            shouldCheckpoint: shouldCheckpoint
        )
    }

    @discardableResult
    public func flush(at wallDate: Date) -> ListeningSession? {
        finishSession(at: wallDate)
    }

    public func reset() {
        activeSession = nil
        previousMonotonic = nil
        lastActiveMonotonic = nil
        lastActiveWallDate = nil
        lastCheckpointMonotonic = nil
        lastWasActive = false
    }

    private func merge(
        players: [PlayerIdentity],
        into session: inout ActiveListeningSession
    ) {
        for player in players where !session.players.contains(where: {
            $0.bundleID == player.bundleID
        }) {
            session.players.append(player)
        }
    }

    private func finishSession(at date: Date) -> ListeningSession? {
        guard let session = activeSession else {
            return nil
        }
        defer { reset() }
        guard session.accumulatedDuration >= 1 else {
            return nil
        }
        return ListeningSession(
            startedAt: session.startedAt,
            endedAt: max(date, session.startedAt),
            duration: session.accumulatedDuration,
            players: session.players,
            deviceUID: session.device.uid,
            deviceName: session.device.name,
            transport: session.device.transport,
            wasRecovered: session.wasRecovered
        )
    }
}
