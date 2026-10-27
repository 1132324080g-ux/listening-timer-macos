import Charts
import ListeningCore
import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layoutSpacing) {
                WindowPageHeader(
                    title: "概览",
                    subtitle: Date.now.formatted(
                        .dateTime
                            .month(.wide)
                            .day()
                            .weekday(.wide)
                    )
                )

                widgets
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var layout: OverviewLayoutSettings {
        model.settings.overviewLayout
    }

    private var layoutSpacing: CGFloat {
        switch layout.overviewStyle {
        case .balanced: 22
        case .focus: 26
        case .compact: 14
        }
    }

    private var horizontalPadding: CGFloat {
        layout.overviewStyle == .compact ? 22 : 28
    }

    private var widgets: some View {
        ForEach(
            Array(model.visibleOverviewWidgets.enumerated()),
            id: \.element
        ) { index, widget in
            if shouldPair(widget: widget, at: index) {
                HStack(alignment: .top, spacing: layoutSpacing * 0.72) {
                    weeklyChart
                        .frame(maxWidth: .infinity)
                    playerBreakdown
                        .frame(
                            width:
                                layout.overviewStyle == .compact
                                ? 230
                                : 255
                        )
                }
                .frame(
                    minHeight:
                        layout.overviewStyle == .compact ? 240 : 270
                )
            } else if isPairedSecondWidget(widget: widget) {
                EmptyView()
            } else {
                widgetView(widget)
            }
        }
    }

    @ViewBuilder
    private func widgetView(_ widget: OverviewWidget) -> some View {
        switch widget {
        case .liveDashboard:
            hero
        case .periodMetrics:
            metrics
        case .deviceBreakdown:
            deviceBreakdown
        case .weeklyChart:
            weeklyChart
        case .sourceBreakdown:
            playerBreakdown
        case .recentSessions:
            recentSessions
        }
    }

    private func shouldPair(widget: OverviewWidget, at index: Int) -> Bool {
        guard layout.overviewStyle != .focus else {
            return false
        }
        let widgets = model.visibleOverviewWidgets
        return widget == .weeklyChart
            && index + 1 < widgets.count
            && widgets[index + 1] == .sourceBreakdown
    }

    private func isPairedSecondWidget(widget: OverviewWidget) -> Bool {
        guard
            layout.overviewStyle != .focus,
            widget == .sourceBreakdown,
            let index = model.visibleOverviewWidgets.firstIndex(of: widget),
            index > 0
        else {
            return false
        }
        return model.visibleOverviewWidgets[index - 1] == .weeklyChart
    }

    private var hero: some View {
        let isCompact = layout.overviewStyle == .compact
        let primarySize: CGFloat =
            layout.overviewStyle == .focus ? 55 : isCompact ? 39 : 46
        let secondarySize: CGFloat = isCompact ? 20 : 24
        let ringSize: CGFloat =
            layout.overviewStyle == .focus ? 146 : isCompact ? 108 : 132

        return GlassPanel(
            padding: isCompact ? 18 : 23,
            tint: model.activeSession == nil
                ? nil
                : AppTheme.accent.opacity(0.08)
        ) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 9) {
                        StatusPill(
                            status: model.decision.status,
                            active: model.activeSession != nil
                        )
                        if let player =
                            model.activeSession?.players.first
                            ?? model.decision.activePlayers.first {
                            Text(player.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(
                                    AppTheme.secondaryText(colorScheme)
                                )
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(
                            alignment: .firstTextBaseline,
                            spacing: isCompact ? 18 : 27
                        ) {
                            heroDuration(
                                label: "本次实时",
                                value: DurationFormatter.clock(
                                    model.currentDuration
                                ),
                                size: primarySize,
                                prominent: true
                            )
                            if layout.heroTotals.showsToday {
                                heroDuration(
                                    label: "今日累计",
                                    value: DurationFormatter.clock(
                                        model.todayTotal
                                    ),
                                    size: secondarySize
                                )
                            }
                            if layout.heroTotals.showsAllTime {
                                heroDuration(
                                    label: "全部累计",
                                    value: DurationFormatter.clock(
                                        model.allTimeTotal
                                    ),
                                    size: secondarySize
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            heroDuration(
                                label: "本次实时",
                                value: DurationFormatter.clock(
                                    model.currentDuration
                                ),
                                size: primarySize,
                                prominent: true
                            )
                            HStack(spacing: 18) {
                                if layout.heroTotals.showsToday {
                                    heroDuration(
                                        label: "今日",
                                        value: DurationFormatter.clock(
                                            model.todayTotal
                                        ),
                                        size: secondarySize
                                    )
                                }
                                if layout.heroTotals.showsAllTime {
                                    heroDuration(
                                        label: "全部",
                                        value: DurationFormatter.clock(
                                            model.allTimeTotal
                                        ),
                                        size: secondarySize
                                    )
                                }
                            }
                        }
                    }

                    HStack(spacing: 7) {
                        Circle()
                            .fill(
                                model.activeSession == nil
                                    ? Color.secondary.opacity(0.35)
                                    : AppTheme.accent
                            )
                            .frame(width: 6, height: 6)
                        Text(
                            model.activeSession == nil
                                ? "当前未在计时"
                                : "每秒实时更新"
                        )
                        Rectangle()
                            .fill(AppTheme.hairline(colorScheme))
                            .frame(width: 1, height: 11)
                        Image(systemName: heroDeviceSymbol)
                        Text(heroDetail)
                            .lineLimit(1)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.10), lineWidth: 16)
                        .frame(width: ringSize, height: ringSize)
                    Circle()
                        .trim(from: 0, to: model.activeSession == nil ? 0.16 : 0.68)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    AppTheme.accent,
                                    AppTheme.accentSoft,
                                    AppTheme.warm,
                                    AppTheme.accent
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(
                                lineWidth: 16,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringSize, height: ringSize)
                    Image(
                        systemName:
                            model.activeSession == nil
                            ? "headphones"
                            : "waveform"
                    )
                    .font(
                        .system(
                            size: ringSize * 0.27,
                            weight: .light
                        )
                    )
                    .foregroundStyle(AppTheme.accent)
                    .symbolEffect(
                        .variableColor.iterative,
                        isActive: model.activeSession != nil
                    )
                }
                .accessibilityHidden(true)
            }
        }
    }

    private func heroDuration(
        label: String,
        value: String,
        size: CGFloat,
        prominent: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
            Text(value)
                .font(
                    .system(
                        size: size,
                        weight: prominent ? .medium : .semibold,
                        design: .rounded
                    )
                )
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
    }

    private var metrics: some View {
        GlassEffectContainer(spacing: 12) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 12),
                    count: layout.overviewStyle == .focus ? 2 : 4
                ),
                spacing: 12
            ) {
                MetricCard(
                    label: "今日",
                    value: DurationFormatter.compact(model.todayTotal),
                    detail: "自然日累计",
                    symbol: "sun.max"
                )
                MetricCard(
                    label: "本周",
                    value: DurationFormatter.compact(model.weekTotal),
                    detail: "按系统周起始日",
                    symbol: "calendar",
                    tint: AppTheme.accentSoft
                )
                MetricCard(
                    label: "本月",
                    value: DurationFormatter.compact(model.monthTotal),
                    detail: "每月自动归零",
                    symbol: "calendar.circle",
                    tint: AppTheme.warm
                )
                MetricCard(
                    label: "全部",
                    value: DurationFormatter.compact(model.allTimeTotal),
                    detail:
                        "\(model.sessions.count + (model.activeSession == nil ? 0 : 1)) 次会话",
                    symbol: "infinity",
                    tint: .secondary
                )
            }
        }
    }

    private var weeklyChart: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionLabel(
                        title: "最近 7 天",
                        detail: "有线与蓝牙耳机上的有效播放时长"
                    )
                    Spacer()
                    Text("分钟")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                }

                if model.sevenDaySeries.allSatisfy({ $0.duration < 1 }) {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(AppTheme.accent.opacity(0.65))
                        Text("完成一次聆听后，这里会出现趋势")
                            .font(.system(size: 11))
                            .foregroundStyle(
                                AppTheme.secondaryText(colorScheme)
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 166)
                } else {
                    Chart(model.sevenDaySeries) { item in
                        BarMark(
                            x: .value("日期", item.day),
                            y: .value("分钟", item.duration / 60)
                        )
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 7,
                                bottomLeadingRadius: 2,
                                bottomTrailingRadius: 2,
                                topTrailingRadius: 7
                            )
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    AppTheme.accentSoft,
                                    AppTheme.accent
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .chartYScale(
                        domain:
                            0...max(
                                1,
                                (model.sevenDaySeries.map(\.duration).max() ?? 0)
                                    / 60 * 1.16
                            )
                    )
                    .chartXAxis {
                        AxisMarks(
                            values: model.sevenDaySeries.map(\.day)
                        ) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(
                                        date.formatted(
                                            .dateTime.weekday(.narrow)
                                        )
                                    )
                                    .font(.system(size: 10))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                                .foregroundStyle(
                                    AppTheme.hairline(colorScheme)
                                )
                            AxisValueLabel()
                                .font(.system(size: 9))
                        }
                    }
                    .frame(height: 166)
                }
            }
        }
    }

    private var playerBreakdown: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(title: "来源分布", detail: "本月，多来源时长可重叠")

                if model.playerTotals.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 23, weight: .light))
                            .foregroundStyle(AppTheme.accent.opacity(0.65))
                        Text("暂无播放器统计")
                            .font(.system(size: 11))
                            .foregroundStyle(
                                AppTheme.secondaryText(colorScheme)
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    let maximum =
                        max(1, model.playerTotals.map(\.duration).max() ?? 1)
                    ForEach(model.playerTotals.prefix(4)) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 9) {
                                PlayerGlyph(
                                    bundleID: item.player.bundleID,
                                    size: 26
                                )
                                Text(item.player.displayName)
                                    .font(
                                        .system(
                                            size: 12,
                                            weight: .medium
                                        )
                                    )
                                    .lineLimit(1)
                                Spacer()
                                Text(DurationFormatter.short(item.duration))
                                    .font(
                                        .system(
                                            size: 10,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(
                                        AppTheme.secondaryText(colorScheme)
                                    )
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(
                                            AppTheme.hairline(colorScheme)
                                        )
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    AppTheme.accentSoft,
                                                    AppTheme.accent
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(
                                            width:
                                                proxy.size.width
                                                * item.duration / maximum
                                        )
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var deviceBreakdown: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    SectionLabel(
                        title: "耳机累计",
                        detail: "全部时间，按设备分别记录"
                    )
                    Spacer()
                    Text("\(model.deviceTotals.count) 个设备")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                }

                if model.deviceTotals.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "headphones")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(AppTheme.accent.opacity(0.65))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("还没有设备累计")
                                .font(.system(size: 12, weight: .medium))
                            Text(
                                "连接蓝牙或有线耳机，播放已选音乐后会自动建立独立记录。"
                            )
                            .font(.system(size: 10))
                            .foregroundStyle(
                                AppTheme.secondaryText(colorScheme)
                            )
                        }
                    }
                    .padding(.vertical, 12)
                } else {
                    let maximum =
                        max(1, model.deviceTotals.map(\.duration).max() ?? 1)
                    VStack(spacing: 0) {
                        ForEach(
                            Array(model.deviceTotals.prefix(8).enumerated()),
                            id: \.element.deviceUID
                        ) { index, device in
                            deviceTotalRow(
                                device,
                                maximum: maximum
                            )
                            if index < min(7, model.deviceTotals.count - 1) {
                                Divider()
                                    .overlay(
                                        AppTheme.hairline(colorScheme)
                                    )
                            }
                        }
                    }
                }
            }
        }
    }

    private func deviceTotalRow(
        _ device: DeviceListeningTotal,
        maximum: TimeInterval
    ) -> some View {
        let isActive =
            model.activeSession?.device.uid == device.deviceUID
        return HStack(spacing: 12) {
            Image(
                systemName:
                    device.transport.isBluetooth
                    ? "wave.3.right"
                    : "headphones"
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .frame(width: 34, height: 34)
            .background(
                AppTheme.accent.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(
                        model.deviceDisplayName(
                            uid: device.deviceUID,
                            fallback: device.deviceName
                        )
                    )
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if isActive {
                        Text("正在计时")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(
                                AppTheme.accent.opacity(0.10),
                                in: Capsule()
                            )
                    }
                }
                HStack(spacing: 6) {
                    Text(device.transport.displayName)
                    Text("·")
                    Text("\(device.sessionCount) 次会话")
                }
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
            }

            Spacer(minLength: 14)

            VStack(alignment: .trailing, spacing: 5) {
                Text(DurationFormatter.clock(device.duration))
                    .font(
                        .system(
                            size: 12,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                GeometryReader { proxy in
                    ZStack(alignment: .trailing) {
                        Capsule()
                            .fill(AppTheme.hairline(colorScheme))
                        Capsule()
                            .fill(
                                device.transport.isBluetooth
                                    ? AppTheme.accentSoft
                                    : AppTheme.warm.opacity(0.72)
                            )
                            .frame(
                                width:
                                    proxy.size.width
                                    * device.duration / maximum
                            )
                    }
                }
                .frame(width: 94, height: 4)
            }
        }
        .padding(.vertical, 9)
    }

    private var recentSessions: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(title: "最近会话")
                    Spacer()
                    Button("查看全部") {
                        model.selectedSection = .history
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                }

                if model.recentSessions.isEmpty {
                    EmptyListeningView()
                } else {
                    ForEach(
                        Array(model.recentSessions.prefix(5).enumerated()),
                        id: \.element.id
                    ) { index, session in
                        SessionRow(
                            session: session,
                            deviceName: model.deviceDisplayName(
                                uid: session.deviceUID,
                                fallback: session.deviceName
                            )
                        )
                        if index < min(4, model.recentSessions.count - 1) {
                            Divider()
                                .overlay(
                                    AppTheme.hairline(colorScheme)
                                )
                        }
                    }
                }
            }
        }
    }

    private var heroDeviceSymbol: String {
        if model.activeSession != nil {
            return "waveform"
        }
        if model.currentDevice != nil {
            return "headphones"
        }
        return "headphones"
    }

    private var heroDetail: String {
        if let device = model.currentDevice {
            return
                "\(model.deviceDisplayName(for: device)) · \(device.transport.displayName)"
        }
        return model.audioError ?? "连接蓝牙或有线耳机后将自动开始记录"
    }
}

struct SessionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: ListeningSession
    let deviceName: String

    var body: some View {
        HStack(spacing: 12) {
            PlayerGlyph(
                bundleID: session.players.first?.bundleID ?? "",
                size: 30
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(
                    session.players.map(\.displayName)
                        .joined(separator: "、")
                )
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                Text(
                    "\(session.startedAt.formatted(date: .omitted, time: .shortened)) · \(deviceName)"
                )
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
                .lineLimit(1)
            }

            Spacer()

            if session.wasRecovered {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.warm)
                    .help("从检查点恢复的会话")
            }

            Text(DurationFormatter.clock(session.duration))
                .font(
                    .system(
                        size: 12,
                        weight: .medium,
                        design: .rounded
                    )
                )
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
