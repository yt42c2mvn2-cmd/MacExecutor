import AppKit
import Combine
import Foundation

/// Passive inspection of Roblox Player. No IPC, sockets, hooks or memory access.
enum RobloxPresence: Equatable {
    case unchecked, notFound, installed, running
}

struct RobloxProcessDescription: Equatable {
    let bundleIdentifier: String?
    let applicationURL: URL?
    let processIdentifier: Int32
}

struct RobloxClientSnapshot: Equatable {
    let presence: RobloxPresence
    let applicationURL: URL?
    let bundleIdentifier: String?
    let processIdentifier: Int32?
    let checkedAt: Date?

    static let unchecked = RobloxClientSnapshot(
        presence: .unchecked,
        applicationURL: nil,
        bundleIdentifier: nil,
        processIdentifier: nil,
        checkedAt: nil
    )

    var title: String {
        switch presence {
        case .unchecked: "Not checked yet"
        case .notFound: "Roblox Player not found"
        case .installed: "Roblox Player installed"
        case .running: "Roblox Player running"
        }
    }

    var explanation: String {
        switch presence {
        case .unchecked: "Run a local read-only check to see whether Roblox Player is present."
        case .notFound: "No Roblox Player installation was detected at the configured location."
        case .installed: "The Player app was located, but a matching running Player was not detected."
        case .running: "macOS reports a running Roblox Player application. No connection was made."
        }
    }

    var connectionAssessment: String {
        "Unknown — no connection or compatibility test performed"
    }
}

enum RobloxInstallationError: LocalizedError {
    case notPlayer

    var errorDescription: String? {
        "That location is not a valid Roblox Player app. Choose Roblox.app, not Roblox Studio."
    }
}

enum RobloxClientRecognition {
    static let playerBundleIdentifier = "com.roblox.RobloxPlayer"

    static func isPlayer(_ identifier: String?) -> Bool {
        identifier?.caseInsensitiveCompare(playerBundleIdentifier) == .orderedSame
    }

    /// Accept either the actual Player bundle or Roblox's outer .app wrapper.
    /// The provided lookup makes this resolver testable without an installation.
    static func resolvePlayer(
        at selectedURL: URL,
        bundleIdentifierAt: (URL) -> String?
    ) -> URL? {
        let root = selectedURL.standardizedFileURL
        let nested = root.appendingPathComponent("Contents/MacOS/Roblox.app", isDirectory: true)
        for candidate in [root, nested] {
            if isPlayer(bundleIdentifierAt(candidate)) {
                return candidate
            }
        }
        return nil
    }

    static func snapshot(
        runningApplications: [RobloxProcessDescription],
        installedApplicationURL: URL?,
        restrictToInstalledURL: Bool = false,
        checkedAt: Date = .now
    ) -> RobloxClientSnapshot {
        let running = runningApplications.first { process in
            guard isPlayer(process.bundleIdentifier) else { return false }
            guard restrictToInstalledURL else { return true }
            guard let installedApplicationURL, let processURL = process.applicationURL else {
                return false
            }
            return processURL.standardizedFileURL.resolvingSymlinksInPath()
                == installedApplicationURL.standardizedFileURL.resolvingSymlinksInPath()
        }

        if let player = running {
            return RobloxClientSnapshot(
                presence: .running,
                applicationURL: player.applicationURL ?? installedApplicationURL,
                bundleIdentifier: player.bundleIdentifier,
                processIdentifier: player.processIdentifier,
                checkedAt: checkedAt
            )
        }

        if let installedApplicationURL {
            return RobloxClientSnapshot(
                presence: .installed,
                applicationURL: installedApplicationURL,
                bundleIdentifier: playerBundleIdentifier,
                processIdentifier: nil,
                checkedAt: checkedAt
            )
        }

        return RobloxClientSnapshot(
            presence: .notFound,
            applicationURL: nil,
            bundleIdentifier: nil,
            processIdentifier: nil,
            checkedAt: checkedAt
        )
    }
}

@MainActor
final class RobloxClientInspector: ObservableObject {
    static let installationPreferenceKey = "rebilium.robloxInstallationURL"

    @Published private(set) var snapshot: RobloxClientSnapshot = .unchecked
    @Published private(set) var customInstallationPath: String?
    @Published private(set) var installationError: String?

    private let preferences: UserDefaults

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        customInstallationPath = preferences.string(forKey: Self.installationPreferenceKey)
    }

    var isUsingCustomLocation: Bool { customInstallationPath != nil }

    /// A rejected choice does not replace the saved installation.
    @discardableResult
    func setInstallation(_ selectedURL: URL) -> Bool {
        guard let resolved = Self.resolvePlayer(at: selectedURL) else {
            installationError = RobloxInstallationError.notPlayer.localizedDescription
            return false
        }
        customInstallationPath = resolved.path
        preferences.set(resolved.path, forKey: Self.installationPreferenceKey)
        installationError = nil
        refresh()
        return true
    }

    func useAutomaticDetection() {
        customInstallationPath = nil
        preferences.removeObject(forKey: Self.installationPreferenceKey)
        installationError = nil
        refresh()
    }

    func refresh() {
        let bundleID = RobloxClientRecognition.playerBundleIdentifier
        let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .map {
                RobloxProcessDescription(
                    bundleIdentifier: $0.bundleIdentifier,
                    applicationURL: $0.bundleURL,
                    processIdentifier: $0.processIdentifier
                )
            }

        if let customInstallationPath {
            let url = URL(fileURLWithPath: customInstallationPath, isDirectory: true)
            let validated = Self.resolvePlayer(at: url)
            installationError = validated == nil
                ? "The saved Player installation is no longer valid. Choose another app or use automatic detection."
                : nil
            snapshot = RobloxClientRecognition.snapshot(
                runningApplications: running,
                installedApplicationURL: validated,
                restrictToInstalledURL: true
            )
            return
        }

        installationError = nil
        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .flatMap { Self.resolvePlayer(at: $0) }
            ?? Self.findPlayerAtKnownLocations()
        snapshot = RobloxClientRecognition.snapshot(
            runningApplications: running,
            installedApplicationURL: installed
        )
    }

    private static func resolvePlayer(at url: URL) -> URL? {
        RobloxClientRecognition.resolvePlayer(at: url) { candidate in
            Bundle(url: candidate)?.bundleIdentifier
        }
    }

    private static func findPlayerAtKnownLocations() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            URL(fileURLWithPath: "/Applications/Roblox.app", isDirectory: true),
            home.appendingPathComponent("Applications/Roblox.app", isDirectory: true)
        ]
        for root in roots {
            if let player = resolvePlayer(at: root) {
                return player
            }
        }
        return nil
    }
}
