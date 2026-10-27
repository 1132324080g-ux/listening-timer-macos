import ListeningCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                WindowPageHeader(
                    title: "历史",
                    subtitle: "按自然日查看所有耳机的聆听记录"
                )

                if model.sessions.isEmpty {
                    GlassPanel(padding: 28) {
                        EmptyListeningView()
                    }
                } else {
                    ForEach(model.groupedSessions, id: \.day) { group in
                        GlassPanel(padding: 19) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(dayTitle(group.day))
                                            .font(
                                                .system(
                                                    size: 15,
                                                    weight: .semibold,
                                                    design: .rounded
                                                )
                                            )
                                        Text(
                                            "\(group.sessions.count) 次会话"
                                        )
                                        .font(.system(size: 10))
                                        .foregroundStyle(
                                            AppTheme.secondaryText(colorScheme)
                                        )
                                    }
                                    Spacer()
                                    Text(
                                        DurationFormatter.compact(group.total)
                                    )
                                    .font(
                                        .system(
                                            size: 13,
                                            weight: .semibold,
                                            design: .rounded
                                        )
                                    )
                                    .monospacedDigit()
                                }

                                ForEach(
                                    Array(group.sessions.enumerated()),
                                    id: \.element.id
                                ) { index, session in
                                    HStack(spacing: 12) {
                                        VStack(spacing: 3) {
                                            Text(
                                                session.startedAt.formatted(
                                                    date: .omitted,
                                                    time: .shortened
                                                )
                                            )
                                            .font(
                                                .system(
                                                    size: 11,
                                                    weight: .medium,
                                                    design: .rounded
                                                )
                                            )
                                            Text(
                                                session.endedAt.formatted(
                                                    date: .omitted,
                                                    time: .shortened
                                                )
                                            )
                                            .font(.system(size: 9))
                                            .foregroundStyle(
                                                AppTheme.secondaryText(
                                                    colorScheme
                                                )
                                            )
                                        }
                                        .frame(width: 54, alignment: .leading)

                                        Rectangle()
                                            .fill(AppTheme.accent.opacity(0.18))
                                            .frame(width: 1, height: 31)

                                        PlayerGlyph(
                                            bundleID:
                                                session.players.first?.bundleID
                                                ?? "",
                                            size: 29
                                        )

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(
                                                session.players
                                                    .map(\.displayName)
                                                    .joined(separator: "、")
                                            )
                                            .font(
                                                .system(
                                                    size: 12,
                                                    weight: .medium
                                                )
                                            )
                                            .lineLimit(1)
                                            Text(
                                                "\(model.deviceDisplayName(uid: session.deviceUID, fallback: session.deviceName)) · \(session.transport.displayName)"
                                            )
                                            .font(.system(size: 10))
                                            .foregroundStyle(
                                                AppTheme.secondaryText(
                                                    colorScheme
                                                )
                                            )
                                            .lineLimit(1)
                                        }

                                        Spacer()

                                        if session.wasRecovered {
                                            Label(
                                                "恢复",
                                                systemImage:
                                                    "arrow.counterclockwise"
                                            )
                                            .labelStyle(.iconOnly)
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.warm)
                                        }

                                        Text(
                                            DurationFormatter.clock(
                                                session.duration
                                            )
                                        )
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

                                    if index < group.sessions.count - 1 {
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
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) {
            return "今天"
        }
        if Calendar.current.isDateInYesterday(day) {
            return "昨天"
        }
        return day.formatted(
            .dateTime.year().month(.wide).day().weekday(.wide)
        )
    }
}
