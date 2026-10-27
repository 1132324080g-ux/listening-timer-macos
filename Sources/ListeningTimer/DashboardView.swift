import ListeningCore
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                WindowChromeBar(model: model)

                Group {
                    if !model.isLoaded {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !model.settings.hasCompletedOnboarding {
                        OnboardingView(model: model)
                            .transition(
                                .opacity.combined(
                                    with: .scale(scale: 0.98)
                                )
                            )
                    } else {
                        DashboardShell(model: model)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(
                    AppTheme.hairline(colorScheme),
                    lineWidth: 0.8
                )
                .allowsHitTesting(false)
        }
        .preferredColorScheme(nil)
        .task {
            await model.start()
        }
    }
}

private struct DashboardShell: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if model.settings.overviewLayout.navigationStyle == .sidebar {
                sidebarLayout
            } else {
                topBarLayout
            }
        }
        .background(.clear)
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.25),
            value: model.selectedSection
        )
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.25),
            value: model.settings.overviewLayout.navigationStyle
        )
    }

    private var sidebarLayout: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 208)

            Rectangle()
                .fill(AppTheme.hairline(colorScheme))
                .frame(width: 1)

            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var topBarLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                HStack(spacing: 9) {
                    AppMark(
                        size: 28,
                        style: model.settings.appIconStyle
                    )
                    Text("听鉴")
                        .font(
                            .system(
                                size: 14,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                }

                Rectangle()
                    .fill(AppTheme.hairline(colorScheme))
                    .frame(width: 1, height: 22)

                HStack(spacing: 5) {
                    ForEach(MainSection.allCases) { section in
                        topNavigationButton(section)
                    }
                }

                Spacer()

                StatusPill(
                    status: model.decision.status,
                    active: model.activeSession != nil
                )
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial.opacity(0.30))

            Rectangle()
                .fill(AppTheme.hairline(colorScheme))
                .frame(height: 1)

            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func topNavigationButton(_ section: MainSection) -> some View {
        Button {
            model.selectedSection = section
        } label: {
            HStack(spacing: 7) {
                Image(systemName: section.symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(section.title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 11)
            .frame(height: 31)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            model.selectedSection == section
                ? Color.primary
                : AppTheme.secondaryText(colorScheme)
        )
        .background(
            model.selectedSection == section
                ? AppTheme.accent.opacity(0.12)
                : .clear,
            in: Capsule()
        )
        .keyboardShortcut(
            section == .overview
                ? "1"
                : section == .history ? "2" : "3",
            modifiers: .command
        )
        .accessibilityAddTraits(
            model.selectedSection == section ? .isSelected : []
        )
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AppMark(
                    size: 32,
                    style: model.settings.appIconStyle
                )
                Text("听鉴")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
            }
            .padding(.bottom, 30)

            VStack(spacing: 5) {
                ForEach(MainSection.allCases) { section in
                    Button {
                        model.selectedSection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.symbol)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 18)
                            Text(section.title)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 11)
                        .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        model.selectedSection == section
                            ? Color.primary
                            : AppTheme.secondaryText(colorScheme)
                    )
                    .background(
                        model.selectedSection == section
                            ? AppTheme.accent.opacity(0.11)
                            : .clear,
                        in: RoundedRectangle(
                            cornerRadius: 10,
                            style: .continuous
                        )
                    )
                    .keyboardShortcut(
                        section == .overview
                            ? "1"
                            : section == .history ? "2" : "3",
                        modifiers: .command
                    )
                    .accessibilityAddTraits(
                        model.selectedSection == section
                            ? .isSelected
                            : []
                    )
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(
                            model.activeSession == nil
                                ? Color.secondary.opacity(0.4)
                                : AppTheme.accent
                        )
                        .frame(width: 7, height: 7)
                    Text(model.decision.status.title)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(
                    model.currentDevice.map {
                        model.deviceDisplayName(for: $0)
                    } ?? "等待耳机设备"
                )
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
                    .lineLimit(2)

                Divider()
                    .overlay(AppTheme.hairline(colorScheme))

                Text("所有数据仅保存在这台 Mac")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial.opacity(0.46))
    }

    @ViewBuilder
    private var page: some View {
        switch model.selectedSection {
        case .overview:
            OverviewView(model: model)
        case .history:
            HistoryView(model: model)
        case .settings:
            SettingsView(model: model)
        }
    }
}

struct WindowPageHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(
                        .system(
                            size: 27,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText(colorScheme))
            }
            Spacer()
        }
    }
}
