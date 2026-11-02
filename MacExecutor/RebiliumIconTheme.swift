import AppKit
import Foundation

/// Rebilium's asset selection is independent of its always-dark editor UI.
/// Automatic mode follows the user's macOS-wide appearance preference.
enum RebiliumIconTheme {
    static let preferenceKey = "rebilium.iconAppearance"

    static func isDark(_ preference: String) -> Bool {
        switch preference {
        case "dark": return true
        case "light": return false
        default:
            let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
            return (global?["AppleInterfaceStyle"] as? String) == "Dark"
        }
    }

    static func imageAssetName(for preference: String) -> String {
        isDark(preference) ? "RebiliumDarkIcon" : "RebiliumLightIcon"
    }
}
