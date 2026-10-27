import ListeningCore
import SwiftUI

@MainActor
private final class SettingsViewState: ObservableObject {
    @Published var showClearConfirmation = false
    @Published var sourcesExpanded = false
    @Published var deviceBeingRenamed: AudioDeviceSnapshot?
    @Published var deviceAliasDraft = ""
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var state = SettingsViewState()
    private let sourcePreviewLimit = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WindowPageHeader(
                    title: "设置",
                    subtitle: "定制界面、音频来源、设备与启动行为"
                )

                appearanceAndLayout
                playerSources
                audioDevices
                behavior
                dataAndPrivacy
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .alert(
            "清空全部历史？",
            isPresented: $state.showClearConfirmation
        ) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                Task {
                    await model.clearAllHistory()
                }
            }
        } message: {
            Text("此操作会永久删除所有聆听记录，且无法撤销。")
        }
    }

    private var appearanceAndLayout: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    SectionLabel(
                        title: "外观与布局",
                        detail: "排版、实时累计和菜单栏信息都可单独调整"
                    )
                    Spacer()
                    Button("恢复默认") {
                        model.resetOverviewLayout()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    alignment: .leading,
                    spacing: 14
                ) {
                    layoutPicker
                    overviewStylePicker
                    heroTotalsPicker
                    menuBarPicker
                }

                Divider()
                    .overlay(AppTheme.hairline(colorScheme))

                HStack {
                    SectionLabel(
                        title: "概览组件",
                        detail: "拖动左侧把手或使用箭头调整顺序"
                    )
                    Spacer()
                    Text(
                        "\(model.visibleOverviewWidgets.count) / \(OverviewWidget.allCases.count) 已显示"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme)
                    )
                }

                VStack(spacing: 0) {
                    ForEach(
                        Array(
                            model.settings.overviewLayout.widgetOrder
                                .enumerated()
                        ),
                        id: \.element
                    ) { index, widget in
                        widgetLayoutRow(
                            widget,
                            index: index
                        )
                        if index
                            < model.settings.overviewLayout.widgetOrder.count
                                - 1 {
                            Divider()
                                .overlay(
                                    AppTheme.hairline(colorScheme)
                                )
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Color.primary.opacity(colorScheme == .dark ? 0.025 : 0.018),
                    in: RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )
            }
        }
    }

    private var layoutPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("主窗口导航")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
            Picker(
                "",
                selection: Binding(
                    get: {
                        model.settings.overviewLayout.navigationStyle
                    },
                    set: { model.setNavigationLayout($0) }
                )
            ) {
                ForEach(NavigationLayoutStyle.allCases) { style in
                    Label(style.title, systemImage: style.symbol)
                        .tag(style)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var overviewStylePicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("概览信息密度")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
            Picker(
                "",
                selection: Binding(
                    get: {
                        model.settings.overviewLayout.overviewStyle
                    },
                    set: { model.setOverviewLayoutStyle($0) }
                )
            ) {
                ForEach(OverviewLayoutStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            Text(
                model.settings.overviewLayout.overviewStyle.detail
            )
            .font(.system(size: 9))
            .foregroundStyle(AppTheme.secondaryText(colorScheme))
        }
    }

    private var heroTotalsPicker: some View {
        HStack {
            Text("实时卡片累计")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
            Spacer()
            Picker(
                "",
                selection: Binding(
                    get: {
                        model.settings.overviewLayout.heroTotals
                    },
                    set: { model.setHeroTotalsDisplay($0) }
                )
            ) {
                ForEach(HeroTotalsDisplay.allCases) { display in
                    Text(display.title).tag(display)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 128)
        }
    }

    private var menuBarPicker: some View {
        HStack {
            Text("菜单栏实时显示")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
            Spacer()
            Picker(
                "",
                selection: Binding(
                    get: { model.settings.menuBarDurationMode },
                    set: { model.setMenuBarDurationMode($0) }
                )
            ) {
                ForEach(MenuBarDurationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 128)
        }
    }

    private func widgetLayoutRow(
        _ widget: OverviewWidget,
        index: Int
    ) -> some View {
        let isVisible =
            !model.settings.overviewLayout.hiddenWidgets.contains(widget)
        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
                .contentShape(Rectangle())
                .draggable(widget.rawValue)
                .help("拖动调整顺序")

            Image(systemName: widget.symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    isVisible ? AppTheme.accent : Color.secondary
                )
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(widget.title)
                    .font(.system(size: 11, weight: .medium))
                Text(widget.detail)
                    .font(.system(size: 9))
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme)
                    )
                    .lineLimit(1)
            }

            Spacer()

            Button {
                model.moveOverviewWidgetUp(widget)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            .help("上移")

            Button {
                model.moveOverviewWidgetDown(widget)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(
                index
                    == model.settings.overviewLayout.widgetOrder.count - 1
            )
            .help("下移")

            Toggle(
                "",
                isOn: Binding(
                    get: { isVisible },
                    set: {
                        model.setOverviewWidget(
                            widget,
                            visible: $0
                        )
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.vertical, 7)
        .opacity(isVisible ? 1 : 0.62)
        .dropDestination(for: String.self) { items, _ in
            guard
                let rawValue = items.first,
                let source = OverviewWidget(rawValue: rawValue),
                source != widget
            else {
                return false
            }
            model.moveOverviewWidget(source, before: widget)
            return true
        }
    }

    private var playerSources: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    SectionLabel(
                        title: "音频来源",
                        detail: "默认显示五项，可展开查看全部；只有开启的来源参与计时"
                    )
                    Spacer()
                    Button {
                        model.refreshAudio()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }

                let sources = availableSources
                let visibleSources =
                    state.sourcesExpanded
                    ? sources
                    : Array(sources.prefix(sourcePreviewLimit))
                if sources.isEmpty {
                    Text("播放音频后点击刷新，即可从音频进程中添加应用。")
                        .font(.system(size: 11))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                        .padding(.vertical, 8)
                } else {
                    HStack(spacing: 7) {
                        Image(
                            systemName:
                                model.playingAudioBundleIDs.isEmpty
                                ? "waveform.slash"
                                : "waveform"
                        )
                        .symbolEffect(
                            .variableColor.iterative,
                            isActive: !model.playingAudioBundleIDs.isEmpty
                        )
                        Text(
                            model.playingAudioBundleIDs.isEmpty
                                ? "当前未检测到正在播放音频的软件"
                                : "正在播放音频：\(playingAudioNames)"
                        )
                        .lineLimit(1)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        model.playingAudioBundleIDs.isEmpty
                            ? AppTheme.secondaryText(colorScheme)
                            : Color.green
                    )
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        (
                            model.playingAudioBundleIDs.isEmpty
                                ? Color.primary.opacity(0.035)
                                : Color.green.opacity(0.08)
                        ),
                        in: Capsule()
                    )

                    VStack(spacing: 0) {
                        ForEach(
                            Array(visibleSources.enumerated()),
                            id: \.element.id
                        ) {
                            index,
                            player in
                            HStack(spacing: 11) {
                                PlayerGlyph(bundleID: player.bundleID)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.displayName)
                                        .font(
                                            .system(
                                                size: 12,
                                                weight: .medium
                                            )
                                        )
                                    Text(player.bundleID)
                                        .font(.system(size: 9))
                                        .foregroundStyle(
                                            AppTheme.secondaryText(
                                                colorScheme
                                            )
                                        )
                                        .lineLimit(1)
                                }
                                Spacer()
                                if isDetected(player) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "waveform")
                                        Text("正在播放")
                                    }
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.green)
                                }
                                Toggle(
                                    model.isPlayerSelected(player)
                                        ? "计入"
                                        : "不计入",
                                    isOn: Binding(
                                        get: {
                                            model.isPlayerSelected(player)
                                        },
                                        set: { selected in
                                            if selected {
                                                model.selectPlayer(player)
                                            } else {
                                                model.deselectPlayer(player)
                                            }
                                        }
                                    )
                                )
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .font(
                                    .system(size: 9, weight: .medium)
                                )
                                .foregroundStyle(
                                    model.isPlayerSelected(player)
                                        ? AppTheme.accent
                                        : AppTheme.secondaryText(colorScheme)
                                )
                                .accessibilityLabel(
                                    "\(player.displayName) 是否计入聆听时间"
                                )
                            }
                            .padding(.vertical, 8)

                            if index < visibleSources.count - 1 {
                                Divider()
                                    .overlay(
                                        AppTheme.hairline(colorScheme)
                                    )
                            }
                        }

                        if sources.count > sourcePreviewLimit {
                            Divider()
                                .overlay(
                                    AppTheme.hairline(colorScheme)
                                )
                            Button {
                                if reduceMotion {
                                    state.sourcesExpanded.toggle()
                                } else {
                                    withAnimation(.smooth(duration: 0.22)) {
                                        state.sourcesExpanded.toggle()
                                    }
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(
                                        systemName:
                                            state.sourcesExpanded
                                            ? "chevron.up"
                                            : "chevron.down"
                                    )
                                    .font(
                                        .system(
                                            size: 10,
                                            weight: .semibold
                                        )
                                    )
                                    Text(
                                        state.sourcesExpanded
                                            ? "折叠至前 5 个音频来源"
                                            : "展开其余 \(sources.count - sourcePreviewLimit) 个音频来源"
                                    )
                                    .font(
                                        .system(
                                            size: 10,
                                            weight: .medium
                                        )
                                    )
                                    Spacer()
                                }
                                .foregroundStyle(AppTheme.accent)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                state.sourcesExpanded
                                    ? "折叠音频来源列表"
                                    : "展开全部音频来源"
                            )
                        }
                    }
                }
            }
        }
    }

    private var audioDevices: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    SectionLabel(
                        title: "音频设备",
                        detail: "自动识别有线与蓝牙耳机，并按设备分别累计"
                    )
                    Spacer()
                    Button {
                        model.refreshAudio()
                    } label: {
                        Label("重新检测", systemImage: "cable.connector")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }

                if model.outputDevices.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "headphones")
                            .foregroundStyle(AppTheme.accent)
                        Text(
                            model.audioError
                                ?? "暂未发现输出设备，连接耳机后会自动刷新。"
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(
                            Array(model.outputDevices.enumerated()),
                            id: \.element.uid
                        ) { index, device in
                            deviceRow(device)
                            if index < model.outputDevices.count - 1 {
                                Divider()
                                    .overlay(
                                        AppTheme.hairline(colorScheme)
                                    )
                            }
                        }
                    }
                }

                if model.trackableDevices.contains(where: {
                    !$0.muteStateIsKnown
                }) {
                    Label(
                        "部分外置声卡不提供系统音量控制；开启静音规则时，这些设备无法判断是否静音。",
                        systemImage: "info.circle"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                }
            }
        }
    }

    private func deviceRow(_ device: AudioDeviceSnapshot) -> some View {
        let classification = model.classification(for: device)
        return HStack(spacing: 11) {
            Image(
                systemName:
                    classification.isTrackable
                    ? "headphones"
                    : device.transport.isBluetooth
                    ? "wave.3.right"
                    : "hifispeaker"
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(
                classification.isTrackable
                    ? AppTheme.accent
                    : Color.secondary
            )
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.deviceDisplayName(for: device))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(
                    "\(device.transport.displayName) · \(classification.title)"
                )
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
            }

            Spacer()

            if classification.isTrackable {
                Button {
                    state.deviceAliasDraft =
                        model.settings.deviceAliases[device.uid] ?? ""
                    state.deviceBeingRenamed = device
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    AppTheme.secondaryText(colorScheme)
                )
                .help("自定义耳机名称")

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                    .help(
                        classification.isBluetooth
                            ? "会计入这副蓝牙耳机的独立时长"
                            : "会计入聆听时长"
                    )
            } else {
                Toggle(
                    "用作计时设备",
                    isOn: Binding(
                        get: {
                            model.settings.manuallyWiredDeviceUIDs
                                .contains(device.uid)
                        },
                        set: { _ in
                            model.toggleManualTrackedDevice(device)
                        }
                    )
                )
                .font(.system(size: 10))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
        .alert(
            "自定义耳机名称",
            isPresented: Binding(
                get: {
                    state.deviceBeingRenamed?.uid == device.uid
                },
                set: { isPresented in
                    if !isPresented {
                        state.deviceBeingRenamed = nil
                    }
                }
            )
        ) {
            TextField(device.name, text: $state.deviceAliasDraft)
            Button("恢复系统名称") {
                model.setDeviceAlias("", for: device)
                state.deviceBeingRenamed = nil
            }
            Button("取消", role: .cancel) {
                state.deviceBeingRenamed = nil
            }
            Button("保存") {
                model.setDeviceAlias(
                    state.deviceAliasDraft,
                    for: device
                )
                state.deviceBeingRenamed = nil
            }
        } message: {
            Text("名称按设备保存，并同步用于历史和累计；留空会恢复系统名称。")
        }
    }

    private var behavior: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(title: "记录与启动")

                settingToggle(
                    title: "暂停记录",
                    detail: "暂停后不会产生新会话，已有历史不受影响。",
                    isOn: Binding(
                        get: { !model.settings.trackingEnabled },
                        set: { paused in
                            model.setTrackingEnabled(!paused)
                        }
                    )
                )

                Divider()
                    .overlay(AppTheme.hairline(colorScheme))

                settingToggle(
                    title: "静音时停止计时",
                    detail: "播放器仍在运行，但输出静音或音量为零时不计时。",
                    isOn: Binding(
                        get: { !model.settings.countWhenMuted },
                        set: { stopWhenMuted in
                            model.setCountWhenMuted(!stopWhenMuted)
                        }
                    )
                )

                Divider()
                    .overlay(AppTheme.hairline(colorScheme))

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("登录时静默启动")
                            .font(.system(size: 12, weight: .medium))
                        Text(model.loginItemState.detail)
                            .font(.system(size: 10))
                            .foregroundStyle(
                                AppTheme.secondaryText(colorScheme)
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: {
                                model.loginItemState.isEnabled
                                    || model.loginItemState
                                        == .requiresApproval
                                    || model.settings
                                        .launchAtLoginRequested
                            },
                            set: { model.setLaunchAtLogin($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                if model.loginItemState == .requiresApproval
                    || model.loginItemState == .notFound {
                    Button("打开登录项设置") {
                        model.openLoginItemSettings()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
        }
    }

    private var dataAndPrivacy: some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(
                    title: "数据与隐私",
                    detail: "原始会话永久保存在本机 Application Support 中"
                )

                HStack(spacing: 10) {
                    Button {
                        model.exportCSV()
                    } label: {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.glass)

                    Button(role: .destructive) {
                        state.showClearConfirmation = true
                    } label: {
                        Label("清空历史", systemImage: "trash")
                    }
                    .buttonStyle(.glass)
                }

                Divider()
                    .overlay(AppTheme.hairline(colorScheme))

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(AppTheme.accent)
                    Text(
                        "应用不联网、不录制音频、不读取媒体库，也不要求 Apple Events 自动化权限。所有统计仅保存在当前用户账户。"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                }

                Text("听鉴 \(appVersion)")
                    .font(.system(size: 9))
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme).opacity(0.8)
                    )
            }
        }
    }

    private func settingToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var availableSources: [PlayerIdentity] {
        var byBundleID: [String: PlayerIdentity] = [:]
        for player in AudioSourceResolver.commonPlayers
            + model.discoveredPlayers
            + model.settings.selectedPlayers {
            byBundleID[player.bundleID] = player
        }
        return byBundleID.values.sorted {
            let firstIsPlaying = model.playingAudioBundleIDs.contains(
                $0.bundleID
            )
            let secondIsPlaying = model.playingAudioBundleIDs.contains(
                $1.bundleID
            )
            if firstIsPlaying != secondIsPlaying {
                return firstIsPlaying
            }
            let firstIsSelected = model.isPlayerSelected($0)
            let secondIsSelected = model.isPlayerSelected($1)
            if firstIsSelected != secondIsSelected {
                return firstIsSelected
            }
            return $0.displayName.localizedStandardCompare(
                $1.displayName
            ) == .orderedAscending
        }
    }

    private func isDetected(_ player: PlayerIdentity) -> Bool {
        model.isAudioPlaying(player)
    }

    private var playingAudioNames: String {
        availableSources
            .filter(isDetected)
            .map(\.displayName)
            .joined(separator: "、")
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.2.1"
    }
}
