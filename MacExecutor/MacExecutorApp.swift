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
        guard let iconURL = Bundle.main.url(
            forResource: "AppIcon",
            withExtension: "icns"
        ), let icon = NSImage(contentsOf: iconURL) else {
            // Do not override the system icon with a blank image.
            return
        }

        NSApplication.shared.applicationIconImage = icon
    }
}
