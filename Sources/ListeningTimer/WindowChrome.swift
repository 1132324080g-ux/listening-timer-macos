import AppKit
import ListeningCore
import SwiftUI

struct WindowChromeBar: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            HStack {
                Spacer()

                if model.activeSession != nil {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 5, height: 5)
                        Text(DurationFormatter.clock(model.currentDuration))
                            .font(
                                .system(
                                    size: 10,
                                    weight: .medium,
                                    design: .monospaced
                                )
                            )
                            .monospacedDigit()
                            .foregroundStyle(
                                AppTheme.secondaryText(colorScheme)
                            )
                    }
                    .padding(.trailing, 4)
                }

                Button {
                    WindowManager.shared.minimizeCurrentWindow()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    AppTheme.secondaryText(colorScheme)
                )
                .background(
                    Color.primary.opacity(
                        colorScheme == .dark ? 0.07 : 0.045
                    ),
                    in: Circle()
                )
                .keyboardShortcut("m", modifiers: .command)
                .help("最小化到 Dock（⌘M）")
                .accessibilityLabel("最小化到 Dock")
            }

            HStack(spacing: 7) {
                AppMark(size: 18)
                Text("听鉴")
                    .font(
                        .system(
                            size: 11,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        AppTheme.secondaryText(colorScheme)
                    )
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .contentShape(Rectangle())
        .background(.ultraThinMaterial.opacity(0.22))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.hairline(colorScheme))
                .frame(height: 1)
        }
    }
}

struct MenuBarGlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            VisualEffectBlur(
                material: .popover,
                blendingMode: .behindWindow
            )
            LinearGradient(
                colors: [
                    Color.white.opacity(
                        colorScheme == .dark ? 0.035 : 0.20
                    ),
                    AppTheme.accent.opacity(
                        colorScheme == .dark ? 0.075 : 0.045
                    ),
                    AppTheme.warm.opacity(
                        colorScheme == .dark ? 0.035 : 0.04
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    Color.white.opacity(
                        colorScheme == .dark ? 0.035 : 0.14
                    ),
                    .clear
                ],
                center: .topLeading,
                startRadius: 4,
                endRadius: 260
            )
            MenuBarWindowConfigurator()
                .frame(width: 0, height: 0)
        }
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
    }
}

private struct MenuBarWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(view.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else {
            return
        }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 20
        window.contentView?.layer?.cornerCurve = .continuous
        window.contentView?.layer?.masksToBounds = true
        window.invalidateShadow()
    }
}
