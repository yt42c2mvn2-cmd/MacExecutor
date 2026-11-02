import SwiftUI
import AppKit

enum RebiliumStyle {
    static let violet = Color(red: 0.59, green: 0.43, blue: 0.98)
    static let blue = Color(red: 0.28, green: 0.55, blue: 0.98)
    static let background = Color(red: 0.045, green: 0.055, blue: 0.10)
    static let gradient = LinearGradient(
        colors: [violet, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct RebiliumGradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RebiliumStyle.gradient, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.18)))
            .shadow(color: RebiliumStyle.violet.opacity(0.28), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.4)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// The in-app mark always uses the actual light/dark dock artwork.
struct RebiliumMark: View {
    var size: CGFloat = 42
    @AppStorage(RebiliumIconTheme.preferenceKey) private var iconPreference = "automatic"

    var body: some View {
        Image(RebiliumIconTheme.imageAssetName(for: iconPreference))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Rebilium logo")
    }
}
