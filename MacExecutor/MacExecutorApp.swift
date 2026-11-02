import SwiftUI
import AppKit

@main
struct RebiliumApp: App {
    var body: some Scene {
        WindowGroup("Rebilium") {
            ContentView()
                .onAppear {
                    RebiliumDockIcon.install()
                }
        }
        // Draw the app background under the native macOS titlebar.
        // Traffic-light window controls remain system-provided.
        .windowStyle(.hiddenTitleBar)
    }
}

/// Xcode's asset catalog installs AppIcon.icns in the finished macOS bundle,
/// but macOS sometimes keeps an older Dock tile for a previously launched
/// debug app with the same bundle identifier. Installing the bundled icon
/// explicitly updates the running application's Dock tile.
@MainActor
enum RebiliumDockIcon {
    static func install() {
        let preference = UserDefaults.standard.string(
            forKey: RebiliumIconTheme.preferenceKey
        ) ?? "automatic"

        // A full-resolution dark graphite image is shipped in Assets.car.
        // The default macOS .icns supplies multiple optimized light sizes.
        if RebiliumIconTheme.isDark(preference),
           let darkImage = NSImage(named: NSImage.Name("RebiliumDarkIcon")) {
            NSApplication.shared.applicationIconImage = darkImage
            return
        }

        if let iconURL = Bundle.main.url(
            forResource: "AppIcon", withExtension: "icns"
        ), let lightImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = lightImage
            return
        }

        // Fallback for build environments that package only the image set.
        if let lightImage = NSImage(named: NSImage.Name("RebiliumLightIcon")) {
            NSApplication.shared.applicationIconImage = lightImage
        }
    }
}
