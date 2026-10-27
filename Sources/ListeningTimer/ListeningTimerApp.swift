import AppKit
import ListeningCore
import SwiftUI

@main
struct ListeningTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    @ObservedObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(
                model: model,
                openDashboard: {
                    WindowManager.shared.show(
                        model: model,
                        section: .overview
                    )
                }
            )
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let bundleID =
            Bundle.main.bundleIdentifier
            ?? "com.lazycanary.ListeningTimer"
        let currentPID =
            NSRunningApplication.current.processIdentifier
        let olderInstance =
            NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleID
            )
            .filter {
                !$0.isTerminated
                    && $0.processIdentifier != currentPID
                    && $0.processIdentifier < currentPID
            }
            .min {
                $0.processIdentifier < $1.processIdentifier
            }

        if olderInstance != nil {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.openDashboardAction = {
            WindowManager.shared.show(model: AppModel.shared)
        }
        Task {
            await AppModel.shared.start()
            if AppModel.shared.shouldPresentInitialWindow {
                NSApp.setActivationPolicy(.regular)
                WindowManager.shared.show(
                    model: AppModel.shared,
                    section: .overview
                )
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        WindowManager.shared.show(model: AppModel.shared)
        return true
    }

    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        Task {
            await AppModel.shared.prepareForTermination()
            await MainActor.run {
                sender.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 5) {
            Image(
                systemName:
                    model.activeSession == nil
                    ? "headphones"
                    : "headphones.circle.fill"
            )
            if let text = menuBarText {
                Text(text)
                    .monospacedDigit()
                    .font(.system(size: 11, design: .rounded))
            }
        }
        .accessibilityLabel(menuBarAccessibilityLabel)
    }

    private var menuBarText: String? {
        model.settings.menuBarDurationMode.displayText(
            current: model.currentDuration,
            today: model.todayTotal,
            allTime: model.allTimeTotal
        )
    }

    private var menuBarAccessibilityLabel: String {
        if let active = model.activeSession {
            return "听鉴，正在聆听 \(DurationFormatter.clock(active.accumulatedDuration))，全部累计 \(DurationFormatter.compact(model.allTimeTotal))"
        }
        return "听鉴，\(model.decision.status.title)，全部累计 \(DurationFormatter.compact(model.allTimeTotal))"
    }
}
