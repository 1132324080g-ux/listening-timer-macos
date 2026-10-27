import Foundation
import Testing
@testable import ListeningCore

@Suite struct AppearanceSettingsTests {
    @Test func defaultsIncludeRealtimeTotalsAndBalancedSidebar() {
        let settings = AppSettings.default
        #expect(settings.overviewLayout.navigationStyle == .sidebar)
        #expect(settings.overviewLayout.overviewStyle == .balanced)
        #expect(
            settings.overviewLayout.heroTotals == .todayAndAllTime
        )
        #expect(settings.menuBarDurationMode == .currentAndAllTime)
        #expect(settings.appIconStyle == .deepSpacePurple)
        #expect(
            settings.overviewLayout.visibleWidgets.count
                == OverviewWidget.allCases.count
        )
    }

    @Test func legacySettingsDecodeWithNewDefaults() throws {
        let data = Data(
            """
            {
              "selectedPlayers": [],
              "manuallyWiredDeviceUIDs": [],
              "countWhenMuted": false,
              "trackingEnabled": true,
              "hasCompletedOnboarding": true,
              "launchAtLoginRequested": false,
              "schemaVersion": 1
            }
            """.utf8
        )
        let settings = try JSONDecoder().decode(
            AppSettings.self,
            from: data
        )
        #expect(settings.hasCompletedOnboarding)
        #expect(settings.overviewLayout == .default)
        #expect(settings.menuBarDurationMode == .currentAndAllTime)
        #expect(settings.appIconStyle == .deepSpacePurple)
    }

    @Test func menuBarModesFormatLiveValues() {
        let combined = MenuBarDurationMode.currentAndAllTime.displayText(
            current: 65,
            today: 3_600,
            allTime: 7_200
        )
        #expect(combined?.contains("00:01:05") == true)
        #expect(combined?.contains("总") == true)
        #expect(
            MenuBarDurationMode.current.displayText(
                current: 0,
                today: 20,
                allTime: 30
            ) == nil
        )
        #expect(
            MenuBarDurationMode.iconOnly.displayText(
                current: 10,
                today: 20,
                allTime: 30
            ) == nil
        )
    }

    @Test func normalizationKeepsAtLeastOneWidgetVisible() {
        var layout = OverviewLayoutSettings(
            hiddenWidgets: Set(OverviewWidget.allCases)
        )
        layout.normalize()
        #expect(!layout.visibleWidgets.isEmpty)
    }

    @Test func newSettingsRoundTripThroughJSON() throws {
        var layout = OverviewLayoutSettings(
            navigationStyle: .topBar,
            overviewStyle: .compact,
            heroTotals: .allTime,
            widgetOrder: [
                .periodMetrics,
                .liveDashboard,
                .weeklyChart,
                .sourceBreakdown,
                .recentSessions
            ],
            hiddenWidgets: [.recentSessions]
        )
        layout.normalize()
        let original = AppSettings(
            overviewLayout: layout,
            menuBarDurationMode: .allTime,
            appIconStyle: .ink
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            AppSettings.self,
            from: data
        )
        #expect(decoded == original)
    }
}
