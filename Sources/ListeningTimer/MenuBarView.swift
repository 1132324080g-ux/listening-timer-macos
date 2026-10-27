import ListeningCore
import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var model: AppModel
    let openDashboard: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            MenuBarGlassBackdrop()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                    .strokeBorder(
                        Color.white.opacity(
                            colorScheme == .dark ? 0.12 : 0.30
                        ),
                        lineWidth: 0.8
                    )
                    .allowsHitTesting(false)
                }

            VStack(spacing: 15) {
                header
                listeningCard
                todayCard
                quickActions

                if let warning = model.warnings.last {
                    warningBanner(warning)
                }

                HStack {
                    Spacer()
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Label("退出听鉴", systemImage: "power")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme)
                    )
                }
            }
            .padding(17)
        }
        .frame(width: 356)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            await model.start()
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            AppMark(size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("听鉴")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("有线与蓝牙耳机聆听统计")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
            }
            Spacer()
            StatusPill(
                status: model.decision.status,
                active: model.activeSession != nil
            )
        }
    }

    private var listeningCard: some View {
        GlassPanel(
            padding: 18,
            tint: model.activeSession == nil
                ? nil
                : AppTheme.accent.opacity(0.08)
        ) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            model.activeSession == nil
                                ? "本次聆听"
                                : "正在聆听"
                        )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(
                            AppTheme.secondaryText(colorScheme)
                        )
                        Text(
                            model.activeSession == nil
                                ? "00:00:00"
                                : DurationFormatter.clock(model.currentDuration)
                        )
                        .font(
                            .system(
                                size: 31,
                                weight: .medium,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                    }
                    Spacer()
                    Image(
                        systemName:
                            model.activeSession == nil
                            ? "headphones"
                            : "waveform"
                    )
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(
                        model.activeSession == nil
                            ? Color.secondary.opacity(0.45)
                            : AppTheme.accent
                    )
                    .symbolEffect(
                        .variableColor.iterative,
                        isActive: model.activeSession != nil
                    )
                }

                Divider()
                    .overlay(AppTheme.hairline(colorScheme))

                HStack(spacing: 12) {
                    Image(systemName: statusSymbol)
                        .frame(width: 20)
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(statusDetail)
                            .font(.system(size: 11))
                            .foregroundStyle(
                                AppTheme.secondaryText(colorScheme)
                            )
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
        }
    }

    private var todayCard: some View {
        GlassPanel(padding: 13) {
            HStack(spacing: 0) {
                compactStat("今日", model.todayTotal)
                statDivider
                compactStat("本周", model.weekTotal)
                statDivider
                compactStat("全部", model.allTimeTotal, highlighted: true)
            }
        }
    }

    private func compactStat(
        _ label: String,
        _ duration: TimeInterval,
        highlighted: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
            Text(DurationFormatter.compact(duration))
                .font(
                    .system(
                        size: 12,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    highlighted ? AppTheme.accent : Color.primary
                )
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(AppTheme.hairline(colorScheme))
            .frame(width: 1, height: 28)
            .padding(.horizontal, 9)
    }

    private var quickActions: some View {
        HStack(spacing: 9) {
            Button {
                model.requestDashboard(section: .overview)
            } label: {
                Label("查看统计", systemImage: "chart.bar.xaxis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)

            Button {
                model.setTrackingEnabled(!model.settings.trackingEnabled)
            } label: {
                Image(
                    systemName:
                        model.settings.trackingEnabled
                        ? "pause.fill"
                        : "play.fill"
                )
                .frame(width: 24)
            }
            .buttonStyle(.glass)
            .help(model.settings.trackingEnabled ? "暂停记录" : "继续记录")

            Button {
                model.requestDashboard(section: .settings)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 24)
            }
            .buttonStyle(.glass)
            .help("设置")
        }
    }

    private func warningBanner(_ warning: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warm)
            Text(warning)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                model.dismissWarning(warning)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            AppTheme.warm.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var statusSymbol: String {
        switch model.decision.status {
        case .listening: "headphones.circle.fill"
        case .paused: "pause.circle"
        case .noPlayers: "music.note.list"
        case .waitingForDevice: "headphones"
        case .muted: "speaker.slash"
        case .waitingForPlayback: "music.note"
        case .unavailable: "exclamationmark.triangle"
        }
    }

    private var statusTitle: String {
        if let device = model.currentDevice,
           model.decision.status != .paused {
            return model.deviceDisplayName(for: device)
        }
        return model.decision.status.title
    }

    private var statusDetail: String {
        if !model.installedSelectedPlayers.isEmpty,
           model.decision.status == .waitingForPlayback {
            return model.installedSelectedPlayers.map(\.displayName)
                .joined(separator: "、")
        }
        if model.decision.status == .waitingForDevice {
            return model.audioError ?? "连接蓝牙耳机或有线音频设备"
        }
        if model.decision.status == .noPlayers {
            return "打开设置选择音频应用"
        }
        if model.decision.status == .muted {
            return "提高音量或关闭“静音时停止计时”"
        }
        if model.decision.status == .listening {
            let names = model.activeSession?.players.map(\.displayName)
                .joined(separator: "、")
            return names ?? model.decision.activePlayers.first?.displayName ?? ""
        }
        return model.decision.status.title
    }
}
