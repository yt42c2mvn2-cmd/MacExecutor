import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Read-only Roblox Player presence check. This view never offers Connect or
/// Execute actions and does not make capability claims based on app detection.
struct RobloxClientCheckView: View {
    @ObservedObject var inspector: RobloxClientInspector

    private var statusColor: Color {
        switch inspector.snapshot.presence {
        case .running: RebiliumStyle.blue
        case .installed: RebiliumStyle.violet
        case .unchecked, .notFound: .white.opacity(0.5)
        }
    }

    private var statusSymbol: String {
        switch inspector.snapshot.presence {
        case .running: "checkmark.circle.fill"
        case .installed: "app.badge"
        case .notFound: "questionmark.circle"
        case .unchecked: "circle.dotted"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 17))
                    .foregroundStyle(RebiliumStyle.violet)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Roblox Client Check")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Observation only · no connection attempted")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 12)

                Button {
                    inspector.refresh()
                } label: {
                    Label("Check Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("refreshRobloxClientButton")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Roblox installation", systemImage: "folder")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(inspector.isUsingCustomLocation ? "CUSTOM" : "AUTOMATIC")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RebiliumStyle.blue)
                }

                Text(inspector.customInstallationPath
                    ?? "Automatically find Roblox Player using macOS and common install locations")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.73))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)

                HStack(spacing: 9) {
                    Button {
                        chooseInstallation()
                    } label: {
                        Label("Choose Roblox.app…", systemImage: "folder.badge.gearshape")
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("chooseRobloxInstallationButton")

                    if inspector.isUsingCustomLocation {
                        Button("Use Automatic") {
                            inspector.useAutomaticDetection()
                        }
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("resetRobloxInstallationButton")
                    }

                    if let app = inspector.snapshot.applicationURL {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([app])
                        } label: {
                            Label("Show in Finder", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.glass)
                    }
                }

                if let issue = inspector.installationError {
                    Label(issue, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 9) {
                Image(systemName: statusSymbol)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(inspector.snapshot.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(inspector.snapshot.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.63))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("robloxClientStatus")

            if let location = inspector.snapshot.applicationURL {
                detail("App location", value: location.path)
            }

            if let bundleID = inspector.snapshot.bundleIdentifier {
                detail("Bundle ID", value: bundleID)
            }

            if let processID = inspector.snapshot.processIdentifier {
                detail("Process ID", value: String(processID))
            }

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(RebiliumStyle.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Connection compatibility: Not tested")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Detecting the Player does not establish whether an authorized communication interface exists. Rebilium will not connect, probe ports, attach to Roblox, or read process memory.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 17))
        .onAppear {
            inspector.refresh()
        }
    }

    @MainActor
    private func chooseInstallation() {
        let panel = NSOpenPanel()
        panel.title = "Choose Roblox Player"
        panel.message = "Select Roblox.app (or the outer Roblox.app bundle), not Roblox Studio."
        panel.prompt = "Use This App"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        if let path = inspector.customInstallationPath {
            panel.directoryURL = URL(fileURLWithPath: path)
                .deletingLastPathComponent()
        }
        if panel.runModal() == .OK, let url = panel.url {
            _ = inspector.setInstallation(url)
        }
    }

    private func detail(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.83))
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }
}
