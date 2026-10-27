import AppKit
import ListeningCore

enum ApplicationIconCatalog {
    static func image(for style: AppIconStyle) -> NSImage? {
        guard let url = Bundle.main.url(
            forResource: "AppIcon-\(style.resourceName)",
            withExtension: "icns"
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    @MainActor
    static func apply(_ style: AppIconStyle) {
        guard let image = image(for: style) else {
            return
        }
        NSApp.applicationIconImage = image
        NSApp.dockTile.display()
    }
}
