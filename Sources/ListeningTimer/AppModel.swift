import AppKit
import Combine
import Foundation
import ListeningCore
import SwiftUI
import UniformTypeIdentifiers

enum MainSection: String, CaseIterable, Identifiable {
    case overview
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "概览"
        case .history: "历史"
        case .settings: "设置"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "gauge.with.dots.needle.50percent"
        case .history: "calendar"
        case .settings: "slider.horizontal.3"
        }
    }
}

private struct AudioRefreshWork: Sendable {
    let result: AudioMonitorResult
    let processAudioActivity: [UInt32: Bool]
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var settings = AppSettings.default
    @Published private(set) var sessions: [ListeningSession] = []
    @Published private(set) var snapshot: AudioSnapshot = .empty
    @Published private(set) var decision = TrackingDecision(status: .unavailable)
    @Published private(set) var activeSession: ActiveListeningSession?
    @Published private(set) var loginItemState: LoginItemState = .notRegistered
    @Published private(set) var isLoaded = false
    @Published private(set) var discoveredPlayers: [PlayerIdentity] = []
    @Published private(set) var playingAudioBundleIDs: Set<String> = []
    @Published private(set) var installedSourceBundleIDs: Set<String> = []
    @Published private(set) var isTrackingPaused = false
    @Published var selectedSection: MainSection = .overview
    @Published var warnings: [String] = []
    @Published var toastMessage: String?
    @Published var shouldPresentInitialWindow = false
    @Published var audioError: String?

    var openDashboardAction: (() -> Void)?

    private let repository: SessionRepository
    private let audioProvider: CoreAudioProviding
    private let launchService: LaunchAtLoginServing
    private let tracker = ListeningTracker()
    private let audioActivityMonitor = ProcessAudioActivityMonitor.shared
    private var pollingTask: Task<Void, Never>?
    private var observerTokens: [NSObjectProtocol] = []
    private var hasStarted = false
    private var isTerminating = false
    private var lastActiveSessionUIPublish: TimeInterval = 0
    private var lastInstalledSourceRefresh: TimeInterval = 0

    init(
        repository: SessionRepository = JSONSessionRepository(),
        audioProvider: CoreAudioProviding = CoreAudioMonitor(),
        launchService: LaunchAtLoginServing = SystemLaunchAtLoginService()
    ) {
        self.repository = repository
        self.audioProvider = audioProvider
        self.launchService = launchService
    }

    deinit {
        pollingTask?.cancel()
        for token in observerTokens {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    func start() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        let loadedSessions = await repository.loadSessions()
        let loadedSettings = await repository.loadSettings()
        let checkpoint = await repository.loadCheckpoint()
        sessions = loadedSessions.value.sorted { $0.startedAt < $1.startedAt }
        settings = loadedSettings.value
        warnings.append(contentsOf: loadedSessions.warnings)
        warnings.append(contentsOf: loadedSettings.warnings)
        isTrackingPaused = !settings.trackingEnabled
        loginItemState = launchService.currentState()

        tracker.restore(checkpoint: checkpoint, at: Date())
        activeSession = tracker.currentSession
        lastActiveSessionUIPublish = ProcessInfo.processInfo.systemUptime
        refreshAudio()
        installWorkspaceObservers()
        isLoaded = true
        shouldPresentInitialWindow = !settings.hasCompletedOnboarding
        startPolling()
    }

    func refreshAudio() {
        refreshInstalledSourceBundleIDs(force: true)
        let selectedSourceBundleIDs = selectedAudioSourceBundleIDs
        let result = audioProvider.readSnapshot()
        audioActivityMonitor.update(
            processes: result.snapshot.processes,
            selectedSourceBundleIDs: selectedSourceBundleIDs
        )
        let processAudioActivity =
            audioActivityMonitor.activityByProcessID()
        applyAudioRefresh(
            AudioRefreshWork(
                result: result,
                processAudioActivity: processAudioActivity
            )
        )
    }

    private var selectedAudioSourceBundleIDs: Set<String> {
        Set(
            settings.selectedPlayers
                .filter(isPlayerInstalled)
                .map {
                    AudioSourceResolver.canonicalBundleID(
                        for: $0.bundleID,
                        processName: $0.displayName
                    )
                }
        )
    }

    private func readAudioSnapshotInBackground(
        selectedSourceBundleIDs: Set<String>
    ) async -> AudioRefreshWork {
        let provider = audioProvider
        let activityMonitor = audioActivityMonitor
        return await Task.detached(priority: .utility) {
            let result = provider.readSnapshot()
            activityMonitor.update(
                processes: result.snapshot.processes,
                selectedSourceBundleIDs: selectedSourceBundleIDs
            )
            return AudioRefreshWork(
                result: result,
                processAudioActivity:
                    activityMonitor.activityByProcessID()
            )
        }.value
    }

    private func applyAudioRefresh(_ work: AudioRefreshWork) {
        let result = work.result
        let processAudioActivity = work.processAudioActivity
        if snapshot != result.snapshot {
            snapshot = result.snapshot
        }
        if audioError != result.errorMessage {
            audioError = result.errorMessage
        }
        var byBundleID: [String: PlayerIdentity] = [:]
        var playingBundleIDs: Set<String> = []
        for process in result.snapshot.processes
        where process.bundleID != Bundle.main.bundleIdentifier {
            let sourceBundleID = AudioSourceResolver.canonicalBundleID(
                for: process.bundleID,
                processName: process.name
            )
            let isProducingAudio =
                processAudioActivity[process.id]
                ?? process.isActiveOutput
            guard isProducingAudio else {
                continue
            }
            let owningApplication =
                NSRunningApplication.runningApplications(
                    withBundleIdentifier: sourceBundleID
                ).first
                ?? NSRunningApplication(processIdentifier: process.pid)
            guard let owningApplication,
                  shouldOfferAsPlayer(
                    owningApplication,
                    sourceBundleID: sourceBundleID
                  ) else {
                continue
            }
            let knownName = PlayerIdentity.displayName(for: sourceBundleID)
            let player = PlayerIdentity(
                bundleID: sourceBundleID,
                displayName:
                    knownName == sourceBundleID
                    ? owningApplication.localizedName ?? process.name
                    : knownName
            )
            byBundleID[sourceBundleID] = player
            playingBundleIDs.insert(sourceBundleID)
        }
        for player in installedSelectedPlayers {
            byBundleID[player.bundleID] = player
        }
        if playingAudioBundleIDs != playingBundleIDs {
            playingAudioBundleIDs = playingBundleIDs
        }
        let sortedPlayers = byBundleID.values.sorted {
            let firstIsPlaying = playingBundleIDs.contains($0.bundleID)
            let secondIsPlaying = playingBundleIDs.contains($1.bundleID)
            if firstIsPlaying != secondIsPlaying {
                return firstIsPlaying
            }
            return $0.displayName.localizedCaseInsensitiveCompare(
                $1.displayName
            ) == .orderedAscending
        }
        if discoveredPlayers != sortedPlayers {
            discoveredPlayers = sortedPlayers
        }
        if !playingBundleIDs.isSubset(
            of: installedSourceBundleIDs
        ) {
            installedSourceBundleIDs.formUnion(playingBundleIDs)
        }

        if isLoaded {
            tick(processAudioActivity: processAudioActivity)
        }
    }

    private func shouldOfferAsPlayer(
        _ application: NSRunningApplication,
        sourceBundleID: String
    ) -> Bool {
        if AudioSourceResolver.isKnownSource(sourceBundleID) {
            return true
        }
        switch application.activationPolicy {
        case .regular:
            return true
        case .accessory:
            guard let bundleID = application.bundleIdentifier else {
                return false
            }
            return !bundleID.hasPrefix("com.apple.")
                && !bundleID.hasPrefix("com.openai.")
        case .prohibited:
            return false
        @unknown default:
            return false
        }
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    // Process taps detect silence directly; a short fallback
                    // poll keeps newly launched sources responsive as well.
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return
                }
                guard let self, !self.isTerminating else {
                    return
                }
                self.refreshInstalledSourceBundleIDs(force: false)
                let work = await self.readAudioSnapshotInBackground(
                    selectedSourceBundleIDs:
                        self.selectedAudioSourceBundleIDs
                )
                guard !Task.isCancelled, !self.isTerminating else {
                    return
                }
                self.applyAudioRefresh(work)
            }
        }
    }

    func selectPlayer(_ player: PlayerIdentity) {
        updateSettings { settings in
            if !settings.selectedPlayers.contains(where: {
                $0.bundleID == player.bundleID
            }) {
                settings.selectedPlayers.append(player)
                settings.selectedPlayers.sort {
                    $0.displayName.localizedStandardCompare($1.displayName)
                        == .orderedAscending
                }
            }
        }
    }

    func deselectPlayer(_ player: PlayerIdentity) {
        updateSettings { settings in
            settings.selectedPlayers.removeAll {
                $0.bundleID == player.bundleID
            }
        }
    }

    func isPlayerSelected(_ player: PlayerIdentity) -> Bool {
        settings.selectedPlayers.contains { $0.bundleID == player.bundleID }
    }

    var installedSelectedPlayers: [PlayerIdentity] {
        settings.selectedPlayers.filter(isPlayerInstalled)
    }

    func isPlayerInstalled(_ player: PlayerIdentity) -> Bool {
        let canonicalBundleID = AudioSourceResolver.canonicalBundleID(
            for: player.bundleID,
            processName: player.displayName
        )
        return installedSourceBundleIDs.contains(canonicalBundleID)
    }

    func isAudioPlaying(_ player: PlayerIdentity) -> Bool {
        playingAudioBundleIDs.contains(player.bundleID)
    }

    func setCountWhenMuted(_ enabled: Bool) {
        updateSettings { $0.countWhenMuted = enabled }
    }

    func setNavigationLayout(_ style: NavigationLayoutStyle) {
        updateOverviewLayout { $0.navigationStyle = style }
    }

    func setOverviewLayoutStyle(_ style: OverviewLayoutStyle) {
        updateOverviewLayout { $0.overviewStyle = style }
    }

    func setHeroTotalsDisplay(_ display: HeroTotalsDisplay) {
        updateOverviewLayout { $0.heroTotals = display }
    }

    func setMenuBarDurationMode(_ mode: MenuBarDurationMode) {
        updateSettings { $0.menuBarDurationMode = mode }
    }

    func setOverviewWidget(
        _ widget: OverviewWidget,
        visible: Bool
    ) {
        let currentlyVisible = settings.overviewLayout.visibleWidgets
        if !visible, currentlyVisible.count == 1,
           currentlyVisible.contains(widget) {
            warnings.append("至少保留一个概览组件。")
            return
        }
        updateOverviewLayout { layout in
            if visible {
                layout.hiddenWidgets.remove(widget)
            } else {
                layout.hiddenWidgets.insert(widget)
            }
        }
    }

    func moveOverviewWidgets(from source: IndexSet, to destination: Int) {
        updateOverviewLayout { layout in
            layout.widgetOrder.move(fromOffsets: source, toOffset: destination)
            layout.normalize()
        }
    }

    func moveOverviewWidget(_ source: OverviewWidget, before destination: OverviewWidget) {
        guard source != destination else {
            return
        }
        updateOverviewLayout { layout in
            guard
                let sourceIndex = layout.widgetOrder.firstIndex(of: source),
                let destinationIndex = layout.widgetOrder.firstIndex(
                    of: destination
                )
            else {
                return
            }
            let item = layout.widgetOrder.remove(at: sourceIndex)
            let insertionIndex =
                sourceIndex < destinationIndex
                ? max(0, destinationIndex - 1)
                : destinationIndex
            layout.widgetOrder.insert(
                item,
                at: min(insertionIndex, layout.widgetOrder.count)
            )
            layout.normalize()
        }
    }

    func moveOverviewWidgetUp(_ widget: OverviewWidget) {
        guard
            let index = settings.overviewLayout.widgetOrder.firstIndex(
                of: widget
            ), index > 0
        else {
            return
        }
        moveOverviewWidgets(
            from: IndexSet(integer: index),
            to: index - 1
        )
    }

    func moveOverviewWidgetDown(_ widget: OverviewWidget) {
        guard
            let index = settings.overviewLayout.widgetOrder.firstIndex(
                of: widget
            ), index < settings.overviewLayout.widgetOrder.count - 1
        else {
            return
        }
        moveOverviewWidgets(
            from: IndexSet(integer: index),
            to: index + 2
        )
    }

    func resetOverviewLayout() {
        updateSettings { $0.overviewLayout = .default }
    }

    func setTrackingEnabled(_ enabled: Bool) {
        isTrackingPaused = !enabled
        updateSettings { $0.trackingEnabled = enabled }
        if !enabled {
            finishActiveSessionForPause()
        }
    }

    func toggleManualTrackedDevice(_ device: AudioDeviceSnapshot) {
        updateSettings { settings in
            if settings.manuallyWiredDeviceUIDs.contains(device.uid) {
                settings.manuallyWiredDeviceUIDs.remove(device.uid)
            } else {
                settings.manuallyWiredDeviceUIDs.insert(device.uid)
            }
        }
    }

    func classification(
        for device: AudioDeviceSnapshot
    ) -> ListeningDeviceClassification {
        ListeningDeviceClassifier.classify(
            device,
            manuallyTrackedDeviceUIDs: settings.manuallyWiredDeviceUIDs
        )
    }

    func deviceDisplayName(
        uid: String,
        fallback: String
    ) -> String {
        settings.deviceDisplayName(uid: uid, fallback: fallback)
    }

    func deviceDisplayName(for device: AudioDeviceSnapshot) -> String {
        deviceDisplayName(uid: device.uid, fallback: device.name)
    }

    func setDeviceAlias(
        _ alias: String,
        for device: AudioDeviceSnapshot
    ) {
        guard classification(for: device).isTrackable else {
            return
        }
        updateSettings {
            $0.setDeviceAlias(alias, forDeviceUID: device.uid)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchService.setEnabled(enabled)
            settings.launchAtLoginRequested = enabled
            saveSettings()
        } catch {
            warnings.append(
                "无法更新登录项：\(error.localizedDescription)"
            )
        }
        loginItemState = launchService.currentState()
    }

    func openLoginItemSettings() {
        launchService.openSystemSettings()
    }

    func completeOnboarding(enableLaunchAtLogin: Bool) {
        if enableLaunchAtLogin {
            setLaunchAtLogin(true)
        }
        updateSettings { $0.hasCompletedOnboarding = true }
        shouldPresentInitialWindow = false
        selectedSection = .overview
    }

    func requestDashboard(section: MainSection? = nil) {
        if let section {
            selectedSection = section
        }
        openDashboardAction?()
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismissWarning(_ warning: String) {
        warnings.removeAll { $0 == warning }
    }

    func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue =
            "听鉴-\(Self.fileDateFormatter.string(from: Date())).csv"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do {
            let exportSessions = sessions.map { session in
                var result = session
                result.deviceName = deviceDisplayName(
                    uid: session.deviceUID,
                    fallback: session.deviceName
                )
                return result
            }
            let csv = CSVExporter.makeCSV(sessions: exportSessions)
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(Data(csv.utf8))
            try data.write(to: url, options: .atomic)
            toastMessage = "CSV 已导出"
        } catch {
            warnings.append("导出失败：\(error.localizedDescription)")
        }
    }

    func clearAllHistory() async {
        _ = tracker.flush(at: Date())
        activeSession = nil
        sessions = []
        do {
            try await repository.clearSessions()
            toastMessage = "历史记录已清空"
        } catch {
            warnings.append("清空失败：\(error.localizedDescription)")
        }
    }

    func prepareForTermination() async {
        guard !isTerminating else {
            return
        }
        isTerminating = true
        pollingTask?.cancel()
        if let completed = tracker.flush(at: Date()) {
            sessions.append(completed)
        }
        try? await repository.saveSessions(sessions)
        try? await repository.saveCheckpoint(nil)
    }

    var todayTotal: TimeInterval {
        let range = ListeningStatistics.todayRange(
            now: Date(),
            calendar: .current
        )
        return ListeningStatistics.total(sessions: sessions, in: range)
            + activeDuration(in: range)
    }

    var weekTotal: TimeInterval {
        ListeningStatistics.total(
            sessions: sessions,
            in: ListeningStatistics.weekRange(now: Date(), calendar: .current)
        )
    }

    var monthTotal: TimeInterval {
        ListeningStatistics.total(
            sessions: sessions,
            in: ListeningStatistics.monthRange(now: Date(), calendar: .current)
        )
    }

    var allTimeTotal: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
            + (activeSession?.accumulatedDuration ?? 0)
    }

    var sevenDaySeries: [DailyListeningTotal] {
        ListeningStatistics.dailySeries(
            sessions: sessions,
            endingAt: Date(),
            days: 7,
            calendar: .current
        )
    }

    var playerTotals: [PlayerListeningTotal] {
        let now = Date()
        return ListeningStatistics.playerTotals(
            sessions: sessions,
            in: ListeningStatistics.monthRange(now: now, calendar: .current)
        )
    }

    var deviceTotals: [DeviceListeningTotal] {
        ListeningStatistics.deviceTotals(
            sessions: sessions,
            activeSession: activeSession
        )
    }

    var recentSessions: [ListeningSession] {
        Array(
            sessions
                .sorted { $0.startedAt > $1.startedAt }
                .prefix(8)
        )
    }

    var groupedSessions: [(
        day: Date, sessions: [ListeningSession], total: TimeInterval
    )] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.startedAt)
        }
        return groups
            .map { day, values in
                (
                    day,
                    values.sorted { $0.startedAt > $1.startedAt },
                    values.reduce(0) { $0 + $1.duration }
                )
            }
            .sorted { $0.day > $1.day }
    }

    var trackableDevices: [AudioDeviceSnapshot] {
        snapshot.devices
            .filter { classification(for: $0).isTrackable }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var outputDevices: [AudioDeviceSnapshot] {
        snapshot.devices
            .filter(\.hasOutput)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var currentDevice: AudioDeviceSnapshot? {
        activeSession?.device ?? decision.device
    }

    var currentDuration: TimeInterval {
        activeSession?.accumulatedDuration ?? 0
    }

    var visibleOverviewWidgets: [OverviewWidget] {
        settings.overviewLayout.visibleWidgets
    }

    private func tick(
        processAudioActivity: [UInt32: Bool]
    ) {
        guard isLoaded || hasStarted else {
            return
        }
        let wallDate = Date()
        let monotonic = ProcessInfo.processInfo.systemUptime
        var effectiveSettings = settings
        effectiveSettings.selectedPlayers =
            settings.selectedPlayers.filter(isPlayerInstalled)
        let result = tracker.tick(
            input: TrackingInput(
                snapshot: snapshot,
                settings: effectiveSettings,
                processAudioActivity: processAudioActivity
            ),
            wallDate: wallDate,
            monotonic: monotonic
        )
        if decision != result.decision {
            decision = result.decision
        }
        publishActiveSession(result.activeSession, at: monotonic)

        if let completed = result.completedSession {
            sessions.append(completed)
            sessions.sort { $0.startedAt < $1.startedAt }
            persistCompletedSession()
        } else if result.shouldCheckpoint,
                  let session = result.activeSession {
            persistCheckpoint(session)
        }
    }

    private func refreshInstalledSourceBundleIDs(force: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastInstalledSourceRefresh >= 5 else {
            return
        }
        lastInstalledSourceRefresh = now
        let candidates = Set(
            (
                AudioSourceResolver.commonPlayers
                    + discoveredPlayers
                    + settings.selectedPlayers
            ).map {
                AudioSourceResolver.canonicalBundleID(
                    for: $0.bundleID,
                    processName: $0.displayName
                )
            }
        )
        let runningBundleIDs = Set(
            NSWorkspace.shared.runningApplications.compactMap {
                $0.bundleIdentifier.map {
                    AudioSourceResolver.canonicalBundleID(for: $0)
                }
            }
        )
        let installed = Set(
            candidates.filter { bundleID in
                runningBundleIDs.contains(bundleID)
                    || NSWorkspace.shared.urlForApplication(
                        withBundleIdentifier: bundleID
                    ) != nil
            }
        )
        if installedSourceBundleIDs != installed {
            installedSourceBundleIDs = installed
        }
    }

    private func publishActiveSession(
        _ session: ActiveListeningSession?,
        at monotonic: TimeInterval
    ) {
        guard let session else {
            if activeSession != nil {
                activeSession = nil
            }
            lastActiveSessionUIPublish = monotonic
            return
        }

        let identityChanged: Bool
        if let current = activeSession {
            identityChanged =
                current.startedAt != session.startedAt
                || current.players != session.players
                || current.device.uid != session.device.uid
                || current.device.transport != session.device.transport
                || current.wasRecovered != session.wasRecovered
        } else {
            identityChanged = true
        }

        if identityChanged
            || monotonic - lastActiveSessionUIPublish >= 0.95 {
            activeSession = session
            lastActiveSessionUIPublish = monotonic
        }
    }

    private func activeDuration(in range: Range<Date>) -> TimeInterval {
        guard let activeSession else {
            return 0
        }
        let end = max(activeSession.startedAt, Date())
        let wall = end.timeIntervalSince(activeSession.startedAt)
        guard wall > 0 else {
            return 0
        }
        let overlapStart = max(activeSession.startedAt, range.lowerBound)
        let overlapEnd = min(end, range.upperBound)
        guard overlapEnd > overlapStart else {
            return 0
        }
        return activeSession.accumulatedDuration
            * min(
                1,
                overlapEnd.timeIntervalSince(overlapStart) / wall
            )
    }

    private func finishActiveSessionForPause() {
        if let completed = tracker.flush(at: Date()) {
            sessions.append(completed)
            sessions.sort { $0.startedAt < $1.startedAt }
            persistCompletedSession()
        }
        activeSession = nil
    }

    private func persistCompletedSession() {
        let sessionsToSave = sessions
        Task {
            try? await repository.saveSessions(sessionsToSave)
            try? await repository.saveCheckpoint(nil)
        }
    }

    private func persistCheckpoint(_ session: ActiveListeningSession) {
        let checkpoint = ActiveSessionCheckpoint(session: session)
        Task {
            try? await repository.saveCheckpoint(checkpoint)
        }
    }

    private func updateSettings(
        _ mutation: (inout AppSettings) -> Void
    ) {
        var updated = settings
        mutation(&updated)
        settings = updated
        saveSettings()
    }

    private func updateOverviewLayout(
        _ mutation: (inout OverviewLayoutSettings) -> Void
    ) {
        updateSettings { settings in
            var layout = settings.overviewLayout
            mutation(&layout)
            layout.normalize()
            settings.overviewLayout = layout
        }
    }

    private func saveSettings() {
        let settingsToSave = settings
        Task {
            try? await repository.saveSettings(settingsToSave)
        }
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        observerTokens.append(
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleWillSleep()
                }
            }
        )
        observerTokens.append(
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAudio()
                }
            }
        )
    }

    private func handleWillSleep() {
        if let completed = tracker.flush(at: Date()) {
            sessions.append(completed)
            sessions.sort { $0.startedAt < $1.startedAt }
        }
        activeSession = nil
        let sessionsToSave = sessions
        Task {
            try? await repository.saveSessions(sessionsToSave)
            try? await repository.saveCheckpoint(nil)
        }
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
