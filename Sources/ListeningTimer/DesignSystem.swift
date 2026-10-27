import AppKit
import ListeningCore
import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.16, green: 0.53, blue: 0.49)
    static let accentSoft = Color(red: 0.40, green: 0.73, blue: 0.67)
    static let warm = Color(red: 0.88, green: 0.56, blue: 0.42)
    static let danger = Color(red: 0.75, green: 0.25, blue: 0.24)

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.60) : .black.opacity(0.52)
    }

    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.10) : .black.opacity(0.08)
    }
}

struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    colorScheme == .dark
                        ? Color(red: 0.075, green: 0.085, blue: 0.09)
                        : Color(red: 0.95, green: 0.95, blue: 0.93)
                )

            RadialGradient(
                colors: [
                    AppTheme.accent.opacity(colorScheme == .dark ? 0.14 : 0.10),
                    .clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 620
            )

            RadialGradient(
                colors: [
                    AppTheme.warm.opacity(colorScheme == .dark ? 0.08 : 0.07),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let padding: CGFloat
    private let tint: Color?
    private let interactive: Bool
    @ViewBuilder private let content: Content

    init(
        padding: CGFloat = 20,
        tint: Color? = nil,
        interactive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.tint = tint
        self.interactive = interactive
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: 22,
            style: .continuous
        )
        content
            .padding(padding)
            .glassEffect(
                .regular
                    .tint(tint)
                    .interactive(interactive),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    AppTheme.hairline(colorScheme),
                    lineWidth: 0.7
                )
            }
    }
}

struct AppMark: View {
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: size * 0.30,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentSoft],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppTheme.warm.opacity(0.88))
                    .frame(width: size * 0.26, height: size * 0.26)
                    .padding(size * 0.10)
            }

            Image(systemName: "headphones")
                .font(
                    .system(
                        size: size * 0.48,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(
            color: AppTheme.accent.opacity(0.18),
            radius: size * 0.22,
            y: size * 0.10
        )
        .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    let status: TrackingStatus
    let active: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(active ? AppTheme.accent : Color.secondary.opacity(0.45))
                .frame(width: 7, height: 7)
                .shadow(
                    color: active ? AppTheme.accent.opacity(0.55) : .clear,
                    radius: 5
                )
            Text(status.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .glassEffect(
            .regular
                .tint(active ? AppTheme.accent.opacity(0.12) : nil),
            in: .capsule
        )
    }
}

struct MetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    let value: String
    let detail: String?
    let symbol: String
    var tint: Color = AppTheme.accent

    var body: some View {
        GlassPanel(padding: 17) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText(colorScheme))
                    Spacer()
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(value)
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText(colorScheme))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SectionLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            if let detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
            }
        }
    }
}

struct PlayerGlyph: View {
    let bundleID: String
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let icon = applicationIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: size * 0.28,
                        style: .continuous
                    )
                    .fill(AppTheme.accent.opacity(0.11))
                    Image(systemName: fallbackSymbol)
                        .font(
                            .system(
                                size: size * 0.43,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        )
        .accessibilityHidden(true)
    }

    private var applicationIcon: NSImage? {
        let sourceBundleID = AudioSourceResolver.canonicalBundleID(
            for: bundleID
        )
        guard
            let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: sourceBundleID
            )
        else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    private var fallbackSymbol: String {
        bundleID == "com.apple.Music" ? "music.note" : "play.circle.fill"
    }
}

struct EmptyListeningView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "headphones")
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(AppTheme.accent.opacity(0.75))
            Text("还没有聆听记录")
                .font(.system(size: 14, weight: .medium))
            Text("连接蓝牙或有线耳机，播放已选应用中的音乐后，这里会自动出现统计。")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText(colorScheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
