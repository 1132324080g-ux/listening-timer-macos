import ListeningCore
import SwiftUI

@MainActor
private final class OnboardingState: ObservableObject {
    @Published var step = 0
    @Published var enableLaunchAtLogin = true
    @Published var sourcesExpanded = false
}

private enum OnboardingStage: Int, CaseIterable, Identifiable {
    case welcome
    case sources
    case ready

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: "欢迎"
        case .sources: "音频来源"
        case .ready: "准备完成"
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "sparkles"
        case .sources: "music.note.list"
        case .ready: "checkmark"
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var state = OnboardingState()

    private let lastStep = OnboardingStage.allCases.count - 1
    private let sourcePreviewLimit = 5

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppTheme.hairline(colorScheme))
                .frame(height: 1)

            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        stageContent
                            .id(state.step)
                            .frame(maxWidth: 850, alignment: .leading)
                            .transition(stageTransition)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 24)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geometry.size.height,
                        alignment: .center
                    )
                }
                .scrollIndicators(.hidden)
            }

            footer
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.32),
            value: state.step
        )
        .onAppear {
            state.enableLaunchAtLogin =
                model.settings.launchAtLoginRequested
        }
    }

    private var header: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(headerTitle)
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                Text(headerDetail)
                    .font(.system(size: 10))
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme)
                    )
                    .lineLimit(1)
            }
            .frame(minWidth: 230, alignment: .leading)

            Spacer(minLength: 12)

            OnboardingProgress(
                currentStep: state.step,
                stages: OnboardingStage.allCases
            )

            Spacer(minLength: 12)

            HStack(spacing: 7) {
                Image(systemName: "lock.shield.fill")
                Text("全程本地处理")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 10)
            .frame(height: 27)
            .background(
                AppTheme.accent.opacity(0.08),
                in: Capsule()
            )
        }
        .padding(.horizontal, 28)
        .frame(height: 72)
        .background(.ultraThinMaterial.opacity(0.16))
    }

    @ViewBuilder
    private var stageContent: some View {
        switch OnboardingStage(rawValue: state.step) ?? .welcome {
        case .welcome:
            welcomeStep
        case .sources:
            sourcesStep
        case .ready:
            readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                GlassPanel(
                    padding: 24,
                    tint: AppTheme.accent.opacity(0.065)
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(
                            "自动识别 · 安静记录",
                            systemImage: "waveform.badge.mic"
                        )
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 25)
                        .background(
                            AppTheme.accent.opacity(0.10),
                            in: Capsule()
                        )

                        Text("听见时间，\n不必刻意记录。")
                            .font(
                                .system(
                                    size: 31,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .tracking(-0.5)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(
                            "当你用蓝牙或有线耳机播放选定音频时，听鉴会在菜单栏里悄悄开始；暂停或断开耳机后自动结束。"
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                        Spacer(minLength: 6)

                        HStack(spacing: 12) {
                            Button {
                                state.step = 1
                            } label: {
                                Label(
                                    "选择音频来源",
                                    systemImage: "arrow.right"
                                )
                                .frame(minWidth: 116)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(AppTheme.accent)
                            .keyboardShortcut(.return, modifiers: [])

                            Text("约需 30 秒")
                                .font(.system(size: 10))
                                .foregroundStyle(
                                    AppTheme.secondaryText(colorScheme)
                                )
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 250,
                        alignment: .leading
                    )
                }

                listeningPreview
                    .frame(width: 275)
            }

            HStack(spacing: 10) {
                benefit(
                    "耳机才计时",
                    detail: "蓝牙、3.5 mm 与 USB",
                    symbol: "headphones"
                )
                benefit(
                    "只计选定应用",
                    detail: "不被其他声音干扰",
                    symbol: "music.note"
                )
                benefit(
                    "数据留在本机",
                    detail: "不联网、不录音",
                    symbol: "lock.shield"
                )
            }
        }
    }

    private var listeningPreview: some View {
        GlassPanel(padding: 19, tint: Color.primary.opacity(0.012)) {
            VStack(spacing: 13) {
                HStack {
                    Text("本次聆听")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 6, height: 6)
                        Text("自动计时")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                ZStack {
                    Circle()
                        .stroke(AppTheme.hairline(colorScheme), lineWidth: 9)
                        .frame(width: 122, height: 122)
                    Circle()
                        .trim(from: 0, to: 0.62)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    AppTheme.accentSoft,
                                    AppTheme.accent,
                                    AppTheme.warm,
                                    AppTheme.accentSoft
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(
                                lineWidth: 9,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 122, height: 122)
                    Image(systemName: "headphones")
                        .font(.system(size: 29, weight: .light))
                        .foregroundStyle(AppTheme.accent)
                }

                Text("00:00:00")
                    .font(
                        .system(
                            size: 27,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()

                HStack(spacing: 8) {
                    PlayerGlyph(bundleID: "com.apple.Music", size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Apple Music")
                            .font(.system(size: 10, weight: .medium))
                        Text("外置耳机 · 播放中")
                            .font(.system(size: 9))
                            .foregroundStyle(
                                AppTheme.secondaryText(colorScheme)
                            )
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func benefit(
        _ title: String,
        detail: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30, height: 30)
                .background(
                    AppTheme.accent.opacity(0.09),
                    in: RoundedRectangle(
                        cornerRadius: 9,
                        style: .continuous
                    )
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme)
                    )
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            Color.primary.opacity(
                colorScheme == .dark ? 0.035 : 0.025
            ),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(
                    AppTheme.hairline(colorScheme),
                    lineWidth: 0.7
                )
        }
    }

    private var sourcesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("哪些应用可以计入聆听时间？")
                        .font(
                            .system(
                                size: 18,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                    Text("已自动识别正在播放音频的软件；你可以逐项开启或关闭计时。")
                        .font(.system(size: 11))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                }
                Spacer()
                Button {
                    model.refreshAudio()
                } label: {
                    Label("重新检测", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }

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
            .padding(.horizontal, 11)
            .frame(height: 29)
            .background(
                (
                    model.playingAudioBundleIDs.isEmpty
                        ? Color.primary.opacity(0.035)
                        : Color.green.opacity(0.08)
                ),
                in: Capsule()
            )

            let sources = availableSources
            let visibleSources =
                state.sourcesExpanded
                ? sources
                : Array(sources.prefix(sourcePreviewLimit))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(visibleSources) { player in
                    sourceCard(player)
                }
            }

            if sources.count > sourcePreviewLimit {
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
                        .font(.system(size: 10, weight: .semibold))
                        Text(
                            state.sourcesExpanded
                                ? "折叠至前 5 个音频来源"
                                : "展开其余 \(sources.count - sourcePreviewLimit) 个音频来源"
                        )
                        .font(.system(size: 10, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 4)
                    .frame(height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    state.sourcesExpanded
                        ? "折叠音频来源列表"
                        : "展开全部音频来源"
                )
            }

            GlassPanel(padding: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("暂时没看到正在使用的应用？")
                            .font(.system(size: 11, weight: .semibold))
                        Text(
                            "列表仅显示这台 Mac 上已安装的音频应用。先打开播放器再点“重新检测”；卸载后会自动隐藏，重新安装后会恢复之前的选择。"
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(selectionSummary)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(
                            model.installedSelectedPlayers.isEmpty
                                ? AppTheme.secondaryText(colorScheme)
                                : AppTheme.accent
                        )
                }
            }
        }
    }

    private func sourceCard(_ player: PlayerIdentity) -> some View {
        let isSelected = model.isPlayerSelected(player)
        let isDetected = detected(player)

        return Button {
            if isSelected {
                model.deselectPlayer(player)
            } else {
                model.selectPlayer(player)
            }
        } label: {
            HStack(spacing: 13) {
                PlayerGlyph(bundleID: player.bundleID, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(
                                isDetected
                                    ? AppTheme.accent
                                    : Color.secondary.opacity(0.4)
                            )
                            .frame(width: 5, height: 5)
                        Text(
                            isDetected
                                ? "正在播放音频"
                                : isSelected
                                    ? "已计入，当前未播放"
                                    : "未计入聆听"
                        )
                            .font(.system(size: 9))
                            .foregroundStyle(
                                isDetected
                                    ? AppTheme.accent
                                    : AppTheme.secondaryText(colorScheme)
                            )
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? AppTheme.accent
                                : Color.primary.opacity(0.045)
                        )
                    Circle()
                        .strokeBorder(
                            isSelected
                                ? AppTheme.accent
                                : Color.primary.opacity(0.15),
                            lineWidth: 1
                        )
                    Image(
                        systemName: isSelected ? "checkmark" : "plus"
                    )
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : AppTheme.secondaryText(colorScheme)
                    )
                }
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 15)
            .frame(height: 72)
            .background(
                isSelected
                    ? AppTheme.accent.opacity(0.095)
                    : Color.primary.opacity(
                        colorScheme == .dark ? 0.035 : 0.025
                    ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? AppTheme.accent.opacity(0.48)
                            : AppTheme.hairline(colorScheme),
                        lineWidth: isSelected ? 1 : 0.7
                    )
            }
            .contentShape(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(
            "\(player.displayName)，\(isDetected ? "正在播放音频，" : "")\(isSelected ? "计入聆听时间" : "不计入聆听时间")"
        )
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                GlassPanel(
                    padding: 22,
                    tint: AppTheme.accent.opacity(0.055)
                ) {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            AppMark(size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("已经可以开始")
                                    .font(
                                        .system(
                                            size: 17,
                                            weight: .semibold,
                                            design: .rounded
                                        )
                                    )
                                Text("完成后会自动收起设置窗口")
                                    .font(.system(size: 10))
                                    .foregroundStyle(
                                        AppTheme.secondaryText(colorScheme)
                                    )
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 23))
                                .foregroundStyle(AppTheme.accent)
                        }

                        Divider()
                            .overlay(AppTheme.hairline(colorScheme))

                        readyLine(
                            symbol: "music.note",
                            title: "音频来源",
                            value: selectedPlayersText
                        )
                        readyLine(
                            symbol:
                                model.trackableDevices.isEmpty
                                ? "headphones"
                                : "headphones",
                            title: "耳机设备",
                            value:
                                model.trackableDevices.first.map {
                                    model.deviceDisplayName(for: $0)
                                }
                                ?? "连接后自动识别"
                        )
                        readyLine(
                            symbol: "menubar.rectangle",
                            title: "驻留方式",
                            value: "菜单栏实时显示"
                        )
                        readyLine(
                            symbol: "lock.shield",
                            title: "隐私",
                            value: "不录音、不联网、不读取媒体库"
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 12) {
                    GlassPanel(padding: 17) {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Label(
                                    "登录时静默启动",
                                    systemImage: "power"
                                )
                                .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Toggle(
                                    "",
                                    isOn: $state.enableLaunchAtLogin
                                )
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            }
                            Text(
                                state.enableLaunchAtLogin
                                    ? "登录 Mac 后自动驻留菜单栏，不弹出窗口。"
                                    : "也可以在设置中随时开启。"
                            )
                            .font(.system(size: 10))
                            .foregroundStyle(
                                AppTheme.secondaryText(colorScheme)
                            )
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    GlassPanel(padding: 17) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(
                                    "设备检测",
                                    systemImage: "waveform"
                                )
                                .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Circle()
                                    .fill(
                                        model.trackableDevices.isEmpty
                                            ? AppTheme.warm
                                            : AppTheme.accent
                                    )
                                    .frame(width: 7, height: 7)
                            }
                            Text(
                                model.trackableDevices.isEmpty
                                    ? "尚未检测到耳机。连接蓝牙或有线耳机后会自动开始，无需返回设置。"
                                    : "已检测到可用输出，播放选定音乐即可开始计时。"
                            )
                            .font(.system(size: 10))
                            .foregroundStyle(
                                AppTheme.secondaryText(colorScheme)
                            )
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(width: 300)
            }

            if state.enableLaunchAtLogin,
               model.loginItemState == .notFound {
                Label(
                    "开启登录启动前，请先将应用放入“应用程序”文件夹。",
                    systemImage: "info.circle"
                )
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.warm)
                .padding(.horizontal, 3)
            }
        }
    }

    private func readyLine(
        symbol: String,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
                .lineLimit(1)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.accent)
        }
    }

    private var footer: some View {
        HStack(spacing: 18) {
            if state.step > 0 {
                Button {
                    state.step = max(0, state.step - 1)
                } label: {
                    Label("上一步", systemImage: "chevron.left")
                }
                .buttonStyle(.glass)
            } else {
                Color.clear
                    .frame(width: 76, height: 1)
                    .accessibilityHidden(true)
            }

            Spacer()

            HStack(spacing: 7) {
                ForEach(0...lastStep, id: \.self) { index in
                    Capsule()
                        .fill(
                            index == state.step
                                ? AppTheme.accent
                                : AppTheme.hairline(colorScheme)
                        )
                        .frame(
                            width: index == state.step ? 20 : 6,
                            height: 6
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("第 \(state.step + 1) 步，共 3 步")

            Spacer()

            if state.step < lastStep {
                Button(primaryButtonTitle) {
                    state.step += 1
                }
                .buttonStyle(.glassProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
                .frame(minWidth: 126)
                .disabled(cannotAdvance)
                .help(
                    cannotAdvance
                        ? "请至少选择一个音频来源"
                        : primaryButtonTitle
                )
                .keyboardShortcut(.return, modifiers: [])
            } else {
                Button("开始聆听") {
                    model.completeOnboarding(
                        enableLaunchAtLogin:
                            state.enableLaunchAtLogin
                    )
                }
                .buttonStyle(.glassProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
                .frame(minWidth: 126)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(.horizontal, 30)
        .frame(height: 68)
        .background(.ultraThinMaterial.opacity(0.18))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.hairline(colorScheme))
                .frame(height: 1)
        }
    }

    private var stageTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
    }

    private var headerTitle: String {
        switch state.step {
        case 0: "欢迎来到听鉴"
        case 1: "选择你的音频来源"
        default: "确认并开始"
        }
    }

    private var headerDetail: String {
        switch state.step {
        case 0: "认识自动、私密的聆听统计"
        case 1: "只统计你允许的应用"
        default: "一切准备就绪"
        }
    }

    private var primaryButtonTitle: String {
        state.step == 0 ? "开始设置" : "继续"
    }

    private var cannotAdvance: Bool {
        state.step == 1 && model.installedSelectedPlayers.isEmpty
    }

    private var selectionSummary: String {
        let count = model.installedSelectedPlayers.count
        return count == 0 ? "尚未选择" : "已选择 \(count) 个"
    }

    private var selectedPlayersText: String {
        let names = model.installedSelectedPlayers.map(\.displayName)
        return names.isEmpty ? "尚未选择" : names.joined(separator: "、")
    }

    private func detected(_ player: PlayerIdentity) -> Bool {
        model.isAudioPlaying(player)
    }

    private var playingAudioNames: String {
        availableSources
            .filter(detected)
            .map(\.displayName)
            .joined(separator: "、")
    }

    private var availableSources: [PlayerIdentity] {
        var sources: [String: PlayerIdentity] = [:]
        for player in AudioSourceResolver.commonPlayers
            + model.discoveredPlayers
            + model.settings.selectedPlayers {
            sources[player.bundleID] = player
        }
        return sources.values
            .filter(model.isPlayerInstalled)
            .sorted {
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
}

private struct OnboardingProgress: View {
    let currentStep: Int
    let stages: [OnboardingStage]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(stages) { stage in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                stage.rawValue <= currentStep
                                    ? AppTheme.accent
                                    : Color.primary.opacity(0.055)
                            )
                        Image(
                            systemName:
                                stage.rawValue < currentStep
                                ? "checkmark"
                                : stage.symbol
                        )
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(
                            stage.rawValue <= currentStep
                                ? Color.white
                                : AppTheme.secondaryText(colorScheme)
                        )
                    }
                    .frame(width: 21, height: 21)

                    Text(stage.title)
                        .font(
                            .system(
                                size: 10,
                                weight:
                                    stage.rawValue == currentStep
                                    ? .semibold
                                    : .regular
                            )
                        )
                        .foregroundStyle(
                            stage.rawValue == currentStep
                                ? Color.primary
                                : AppTheme.secondaryText(colorScheme)
                        )
                        .lineLimit(1)

                    if stage.id < stages.count - 1 {
                        Capsule()
                            .fill(
                                stage.rawValue < currentStep
                                    ? AppTheme.accent.opacity(0.55)
                                    : AppTheme.hairline(colorScheme)
                            )
                            .frame(width: 18, height: 2)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "第 \(currentStep + 1) 步：\(stages[currentStep].title)"
        )
    }
}
