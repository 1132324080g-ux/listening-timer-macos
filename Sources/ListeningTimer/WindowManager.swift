import AppKit
import SwiftUI

private final class ListeningTimerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var window: NSWindow?
    private var isTerminating = false

    private init() {}

    func show(model: AppModel, section: MainSection? = nil) {
        guard !isTerminating else {
            return
        }
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        if let section {
            model.selectedSection = section
        }

        let window = existingOrNewWindow(model: model)
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        dashboardWindow?.orderOut(nil)
        if NSApp.activationPolicy() == .regular {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func closeCurrentWindow() {
        dashboardWindow?.performClose(nil)
    }

    func minimizeCurrentWindow() {
        guard let window = dashboardWindow else {
            return
        }
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            window.performMiniaturize(nil)
        }
    }

    func toggleFullScreen() {
        dashboardWindow?.toggleFullScreen(nil)
    }

    private var dashboardWindow: NSWindow? {
        if let window {
            return window
        }
        return NSApp.windows.first { $0 is ListeningTimerWindow }
    }

    private func existingOrNewWindow(model: AppModel) -> NSWindow {
        if let window {
            return window
        }

        let root = MainWindowView(model: model)
            .frame(minWidth: 900, minHeight: 620)
            .ignoresSafeArea(.container, edges: .top)
        let hosting = NSHostingController(rootView: root)
        let window = ListeningTimerWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 1080,
                height: 720
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )
        window.title = "听鉴"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar = nil
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 900, height: 620)
        window.collectionBehavior = [.fullScreenPrimary]
        window.contentViewController = hosting
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 17
        window.contentView?.layer?.cornerCurve = .continuous
        window.contentView?.layer?.masksToBounds = true

        if !window.setFrameUsingName("ListeningTimerDashboard") {
            window.center()
        }
        window.setFrameAutosaveName("ListeningTimerDashboard")

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
        self.window = window
        return window
    }
}
