import Foundation

public enum AudioTransportKind: String, Codable, CaseIterable, Sendable {
    case builtIn
    case usb
    case thunderbolt
    case fireWire
    case bluetooth
    case bluetoothLE
    case airPlay
    case hdmi
    case displayPort
    case pci
    case virtual
    case aggregate
    case other

    public var displayName: String {
        switch self {
        case .builtIn: "内置音频"
        case .usb: "USB"
        case .thunderbolt: "雷雳"
        case .fireWire: "FireWire"
        case .bluetooth: "蓝牙"
        case .bluetoothLE: "低功耗蓝牙"
        case .airPlay: "隔空播放"
        case .hdmi: "HDMI"
        case .displayPort: "DisplayPort"
        case .pci: "PCI"
        case .virtual: "虚拟设备"
        case .aggregate: "聚合设备"
        case .other: "其他"
        }
    }

    public var isBluetooth: Bool {
        self == .bluetooth || self == .bluetoothLE
    }
}

public struct AudioDeviceSnapshot: Identifiable, Equatable, Sendable {
    public let id: UInt32
    public let uid: String
    public let name: String
    public let transport: AudioTransportKind
    public let hasOutput: Bool
    public let terminalTypes: Set<UInt32>
    public let jackConnected: Bool?
    public let isRunningSomewhere: Bool
    public let isMuted: Bool?
    public let volume: Float?

    public init(
        id: UInt32,
        uid: String,
        name: String,
        transport: AudioTransportKind,
        hasOutput: Bool,
        terminalTypes: Set<UInt32> = [],
        jackConnected: Bool? = nil,
        isRunningSomewhere: Bool = false,
        isMuted: Bool? = nil,
        volume: Float? = nil
    ) {
        self.id = id
        self.uid = uid
        self.name = name
        self.transport = transport
        self.hasOutput = hasOutput
        self.terminalTypes = terminalTypes
        self.jackConnected = jackConnected
        self.isRunningSomewhere = isRunningSomewhere
        self.isMuted = isMuted
        self.volume = volume
    }

    public var isAudible: Bool {
        if isMuted == true {
            return false
        }
        if let volume, volume <= 0.0001 {
            return false
        }
        return true
    }

    public var muteStateIsKnown: Bool {
        isMuted != nil || volume != nil
    }
}

public struct AudioProcessSnapshot: Identifiable, Equatable, Sendable {
    public let id: UInt32
    public let pid: pid_t
    public let bundleID: String
    public let name: String
    public let outputDeviceIDs: [UInt32]
    public let isRunningOutput: Bool
    public let isRunning: Bool

    public init(
        id: UInt32,
        pid: pid_t,
        bundleID: String,
        name: String,
        outputDeviceIDs: [UInt32],
        isRunningOutput: Bool,
        isRunning: Bool = false
    ) {
        self.id = id
        self.pid = pid
        self.bundleID = bundleID
        self.name = name
        self.outputDeviceIDs = outputDeviceIDs
        self.isRunningOutput = isRunningOutput
        self.isRunning = isRunning
    }

    public var isActiveOutput: Bool {
        isRunningOutput || (isRunning && !outputDeviceIDs.isEmpty)
    }
}

public struct AudioSnapshot: Equatable, Sendable {
    public let devices: [AudioDeviceSnapshot]
    public let processes: [AudioProcessSnapshot]
    public let defaultOutputDeviceID: UInt32?

    public init(
        devices: [AudioDeviceSnapshot],
        processes: [AudioProcessSnapshot],
        defaultOutputDeviceID: UInt32?
    ) {
        self.devices = devices
        self.processes = processes
        self.defaultOutputDeviceID = defaultOutputDeviceID
    }

    public static let empty = AudioSnapshot(
        devices: [],
        processes: [],
        defaultOutputDeviceID: nil
    )
}

public struct PlayerIdentity: Codable, Hashable, Identifiable, Sendable {
    public let bundleID: String
    public var displayName: String

    public var id: String { bundleID }

    public init(bundleID: String, displayName: String) {
        self.bundleID = bundleID
        self.displayName = displayName
    }

    public static func displayName(for bundleID: String) -> String {
        AudioSourceResolver.displayName(for: bundleID) ?? bundleID
    }
}

public enum AudioSourceResolver {
    public static let commonPlayers: [PlayerIdentity] = [
        PlayerIdentity(bundleID: "com.apple.Music", displayName: "Apple Music"),
        PlayerIdentity(bundleID: "com.spotify.client", displayName: "Spotify"),
        PlayerIdentity(
            bundleID: "com.tencent.QQMusicMac",
            displayName: "QQ 音乐"
        ),
        PlayerIdentity(
            bundleID: "com.netease.163music",
            displayName: "网易云音乐"
        ),
        PlayerIdentity(bundleID: "com.gemd.iting", displayName: "喜马拉雅"),
        PlayerIdentity(bundleID: "com.audible.mac", displayName: "Audible"),
        PlayerIdentity(bundleID: "com.apple.podcasts", displayName: "播客"),
        PlayerIdentity(bundleID: "com.apple.iBooksX", displayName: "图书"),
        PlayerIdentity(bundleID: "com.apple.Safari", displayName: "Safari"),
        PlayerIdentity(
            bundleID: "com.google.Chrome",
            displayName: "Google Chrome"
        ),
        PlayerIdentity(
            bundleID: "com.microsoft.edgemac",
            displayName: "Microsoft Edge"
        ),
        PlayerIdentity(
            bundleID: "org.mozilla.firefox",
            displayName: "Firefox"
        ),
        PlayerIdentity(
            bundleID: "company.thebrowser.Browser",
            displayName: "Arc"
        ),
        PlayerIdentity(
            bundleID: "com.quark.desktop",
            displayName: "夸克"
        ),
        PlayerIdentity(bundleID: "com.colliderli.iina", displayName: "IINA"),
        PlayerIdentity(
            bundleID: "com.firecore.infuse",
            displayName: "Infuse"
        )
    ]

    private static let displayNames = Dictionary(
        uniqueKeysWithValues: commonPlayers.map {
            ($0.bundleID, $0.displayName)
        }
    )

    public static func canonicalBundleID(
        for bundleID: String,
        processName: String? = nil
    ) -> String {
        if bundleID.hasPrefix("com.apple.WebKit.") {
            if processName?.localizedCaseInsensitiveContains("Safari") == true {
                return "com.apple.Safari"
            }
            return bundleID
        }
        if bundleID.hasPrefix("com.google.Chrome.helper") {
            return "com.google.Chrome"
        }
        if bundleID.hasPrefix("com.microsoft.edgemac.helper") {
            return "com.microsoft.edgemac"
        }
        if bundleID.hasPrefix("company.thebrowser.Browser.helper") {
            return "company.thebrowser.Browser"
        }
        if bundleID.hasSuffix(".helper") {
            let ownerBundleID = String(bundleID.dropLast(".helper".count))
            if displayNames[ownerBundleID] != nil {
                return ownerBundleID
            }
        }
        return bundleID
    }

    public static func displayName(for bundleID: String) -> String? {
        displayNames[canonicalBundleID(for: bundleID)]
    }

    public static func isKnownSource(_ bundleID: String) -> Bool {
        displayNames[canonicalBundleID(for: bundleID)] != nil
    }
}

public struct ListeningSession: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var duration: TimeInterval
    public var players: [PlayerIdentity]
    public var deviceUID: String
    public var deviceName: String
    public var transport: AudioTransportKind
    public var wasRecovered: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval,
        players: [PlayerIdentity],
        deviceUID: String,
        deviceName: String,
        transport: AudioTransportKind,
        wasRecovered: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = max(0, duration)
        self.players = players
        self.deviceUID = deviceUID
        self.deviceName = deviceName
        self.transport = transport
        self.wasRecovered = wasRecovered
    }
}

public enum NavigationLayoutStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case sidebar
    case topBar

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sidebar: "左侧边栏"
        case .topBar: "顶部标签"
        }
    }

    public var symbol: String {
        switch self {
        case .sidebar: "sidebar.left"
        case .topBar: "menubar.rectangle"
        }
    }
}

public enum OverviewLayoutStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case balanced
    case focus
    case compact

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .balanced: "平衡"
        case .focus: "聚焦"
        case .compact: "紧凑"
        }
    }

    public var detail: String {
        switch self {
        case .balanced: "信息完整，卡片间距舒展"
        case .focus: "突出实时计时与累计时长"
        case .compact: "缩小间距，同屏显示更多组件"
        }
    }
}

public enum HeroTotalsDisplay: String, Codable, CaseIterable, Identifiable, Sendable {
    case todayAndAllTime
    case allTime
    case today
    case none

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .todayAndAllTime: "今日 + 全部"
        case .allTime: "仅全部"
        case .today: "仅今日"
        case .none: "仅本次"
        }
    }

    public var showsToday: Bool {
        self == .todayAndAllTime || self == .today
    }

    public var showsAllTime: Bool {
        self == .todayAndAllTime || self == .allTime
    }
}

public enum OverviewWidget: String, Codable, CaseIterable, Identifiable, Sendable {
    case liveDashboard
    case periodMetrics
    case deviceBreakdown
    case weeklyChart
    case sourceBreakdown
    case recentSessions

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .liveDashboard: "实时聆听"
        case .periodMetrics: "周期统计"
        case .deviceBreakdown: "耳机累计"
        case .weeklyChart: "七日趋势"
        case .sourceBreakdown: "来源分布"
        case .recentSessions: "最近会话"
        }
    }

    public var detail: String {
        switch self {
        case .liveDashboard: "本次、今日与全部实时时长"
        case .periodMetrics: "今日、本周、本月与全部"
        case .deviceBreakdown: "按蓝牙或有线耳机分别累计"
        case .weeklyChart: "最近七天的聆听柱状图"
        case .sourceBreakdown: "本月播放器来源占比"
        case .recentSessions: "最近完成的聆听会话"
        }
    }

    public var symbol: String {
        switch self {
        case .liveDashboard: "waveform"
        case .periodMetrics: "square.grid.2x2"
        case .deviceBreakdown: "headphones"
        case .weeklyChart: "chart.bar.xaxis"
        case .sourceBreakdown: "chart.pie"
        case .recentSessions: "clock.arrow.circlepath"
        }
    }
}

public struct OverviewLayoutSettings: Codable, Equatable, Sendable {
    public var navigationStyle: NavigationLayoutStyle
    public var overviewStyle: OverviewLayoutStyle
    public var heroTotals: HeroTotalsDisplay
    public var widgetOrder: [OverviewWidget]
    public var hiddenWidgets: Set<OverviewWidget>

    public init(
        navigationStyle: NavigationLayoutStyle = .sidebar,
        overviewStyle: OverviewLayoutStyle = .balanced,
        heroTotals: HeroTotalsDisplay = .todayAndAllTime,
        widgetOrder: [OverviewWidget] = OverviewWidget.allCases,
        hiddenWidgets: Set<OverviewWidget> = []
    ) {
        self.navigationStyle = navigationStyle
        self.overviewStyle = overviewStyle
        self.heroTotals = heroTotals
        self.widgetOrder = widgetOrder
        self.hiddenWidgets = hiddenWidgets
        normalize()
    }

    public static let `default` = OverviewLayoutSettings()

    public var visibleWidgets: [OverviewWidget] {
        widgetOrder.filter { !hiddenWidgets.contains($0) }
    }

    public mutating func normalize() {
        var seen = Set<OverviewWidget>()
        var normalized = widgetOrder.filter { seen.insert($0).inserted }
        for widget in OverviewWidget.allCases where !seen.contains(widget) {
            normalized.append(widget)
            seen.insert(widget)
        }
        widgetOrder = normalized
        hiddenWidgets = hiddenWidgets.intersection(Set(OverviewWidget.allCases))
        if let first = widgetOrder.first,
           hiddenWidgets.count >= widgetOrder.count {
            hiddenWidgets.remove(first)
        }
    }
}

public enum MenuBarDurationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case currentAndAllTime
    case current
    case today
    case allTime
    case iconOnly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .currentAndAllTime: "本次 + 全部"
        case .current: "本次时长"
        case .today: "今日累计"
        case .allTime: "全部累计"
        case .iconOnly: "仅图标"
        }
    }

    public func displayText(
        current: TimeInterval,
        today: TimeInterval,
        allTime: TimeInterval
    ) -> String? {
        switch self {
        case .currentAndAllTime:
            if current >= 1 {
                return "\(DurationFormatter.clock(current)) · 总 \(DurationFormatter.compact(allTime))"
            }
            return "总 \(DurationFormatter.compact(allTime))"
        case .current:
            return current >= 1 ? DurationFormatter.clock(current) : nil
        case .today:
            return "今 \(DurationFormatter.compact(today))"
        case .allTime:
            return "总 \(DurationFormatter.compact(allTime))"
        case .iconOnly:
            return nil
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var selectedPlayers: [PlayerIdentity]
    public var manuallyWiredDeviceUIDs: Set<String>
    public var deviceAliases: [String: String]
    public var countWhenMuted: Bool
    public var trackingEnabled: Bool
    public var hasCompletedOnboarding: Bool
    public var launchAtLoginRequested: Bool
    public var overviewLayout: OverviewLayoutSettings
    public var menuBarDurationMode: MenuBarDurationMode
    public var schemaVersion: Int

    public init(
        selectedPlayers: [PlayerIdentity] = [],
        manuallyWiredDeviceUIDs: Set<String> = [],
        deviceAliases: [String: String] = [:],
        countWhenMuted: Bool = false,
        trackingEnabled: Bool = true,
        hasCompletedOnboarding: Bool = false,
        launchAtLoginRequested: Bool = false,
        overviewLayout: OverviewLayoutSettings = .default,
        menuBarDurationMode: MenuBarDurationMode = .currentAndAllTime,
        schemaVersion: Int = 3
    ) {
        self.selectedPlayers = selectedPlayers
        self.manuallyWiredDeviceUIDs = manuallyWiredDeviceUIDs
        self.deviceAliases = deviceAliases
        self.countWhenMuted = countWhenMuted
        self.trackingEnabled = trackingEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.launchAtLoginRequested = launchAtLoginRequested
        self.overviewLayout = overviewLayout
        self.menuBarDurationMode = menuBarDurationMode
        self.schemaVersion = schemaVersion
    }

    public static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case selectedPlayers
        case manuallyWiredDeviceUIDs
        case deviceAliases
        case countWhenMuted
        case trackingEnabled
        case hasCompletedOnboarding
        case launchAtLoginRequested
        case overviewLayout
        case menuBarDurationMode
        case schemaVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedPlayers =
            try container.decodeIfPresent(
                [PlayerIdentity].self,
                forKey: .selectedPlayers
            ) ?? []
        manuallyWiredDeviceUIDs =
            try container.decodeIfPresent(
                Set<String>.self,
                forKey: .manuallyWiredDeviceUIDs
            ) ?? []
        deviceAliases =
            try container.decodeIfPresent(
                [String: String].self,
                forKey: .deviceAliases
            ) ?? [:]
        countWhenMuted =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .countWhenMuted
            ) ?? false
        trackingEnabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .trackingEnabled
            ) ?? true
        hasCompletedOnboarding =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .hasCompletedOnboarding
            ) ?? false
        launchAtLoginRequested =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .launchAtLoginRequested
            ) ?? false
        var layout =
            try container.decodeIfPresent(
                OverviewLayoutSettings.self,
                forKey: .overviewLayout
            ) ?? .default
        layout.normalize()
        overviewLayout = layout
        menuBarDurationMode =
            try container.decodeIfPresent(
                MenuBarDurationMode.self,
                forKey: .menuBarDurationMode
            ) ?? .currentAndAllTime
        schemaVersion =
            try container.decodeIfPresent(
                Int.self,
                forKey: .schemaVersion
            ) ?? 3
    }

    public func deviceDisplayName(
        uid: String,
        fallback: String
    ) -> String {
        let alias = deviceAliases[uid]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let alias, !alias.isEmpty else {
            return fallback
        }
        return alias
    }

    public mutating func setDeviceAlias(
        _ value: String,
        forDeviceUID uid: String
    ) {
        let alias = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if alias.isEmpty {
            deviceAliases.removeValue(forKey: uid)
        } else {
            deviceAliases[uid] = alias
        }
    }
}

public enum TrackingStatus: String, Codable, Sendable {
    case paused
    case noPlayers
    case waitingForDevice
    case muted
    case waitingForPlayback
    case listening
    case unavailable

    public var title: String {
        switch self {
        case .paused: "记录已暂停"
        case .noPlayers: "尚未选择播放器"
        case .waitingForDevice: "等待耳机设备"
        case .muted: "耳机设备已静音"
        case .waitingForPlayback: "等待音乐播放"
        case .listening: "正在聆听"
        case .unavailable: "音频服务不可用"
        }
    }
}

public struct TrackingInput: Sendable {
    public let snapshot: AudioSnapshot
    public let settings: AppSettings
    public let processAudioActivity: [UInt32: Bool]

    public init(
        snapshot: AudioSnapshot,
        settings: AppSettings,
        processAudioActivity: [UInt32: Bool] = [:]
    ) {
        self.snapshot = snapshot
        self.settings = settings
        self.processAudioActivity = processAudioActivity
    }
}

public struct TrackingDecision: Equatable, Sendable {
    public let status: TrackingStatus
    public let activePlayers: [PlayerIdentity]
    public let device: AudioDeviceSnapshot?

    public var isActive: Bool {
        status == .listening && device != nil && !activePlayers.isEmpty
    }

    public init(
        status: TrackingStatus,
        activePlayers: [PlayerIdentity] = [],
        device: AudioDeviceSnapshot? = nil
    ) {
        self.status = status
        self.activePlayers = activePlayers
        self.device = device
    }
}

public struct ActiveListeningSession: Equatable, Sendable {
    public var startedAt: Date
    public var accumulatedDuration: TimeInterval
    public var players: [PlayerIdentity]
    public var device: AudioDeviceSnapshot
    public var wasRecovered: Bool

    public init(
        startedAt: Date,
        accumulatedDuration: TimeInterval,
        players: [PlayerIdentity],
        device: AudioDeviceSnapshot,
        wasRecovered: Bool = false
    ) {
        self.startedAt = startedAt
        self.accumulatedDuration = max(0, accumulatedDuration)
        self.players = players
        self.device = device
        self.wasRecovered = wasRecovered
    }
}

public struct ActiveSessionCheckpoint: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var accumulatedDuration: TimeInterval
    public var players: [PlayerIdentity]
    public var deviceUID: String
    public var deviceName: String
    public var transport: AudioTransportKind
    public var wasRecovered: Bool

    public init(session: ActiveListeningSession) {
        startedAt = session.startedAt
        accumulatedDuration = session.accumulatedDuration
        players = session.players
        deviceUID = session.device.uid
        deviceName = session.device.name
        transport = session.device.transport
        wasRecovered = session.wasRecovered
    }
}
