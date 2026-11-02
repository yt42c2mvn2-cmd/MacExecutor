import AppKit
import Combine
import Foundation

/// A passive inspection of the Roblox Player's macOS application presence.
/// No handles, IPC, network sockets, scripting hooks or process memory access.
enum RobloxPresence: Equatable {
    case unchecked
    case notFound
    case installed
    case running
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
        case .unchecked:
            "Run a local read-only check to see whether Roblox Player is present."
        case .notFound:
            "Roblox Player was not found through Launch Services or common application locations."
        case .installed:
            "A Roblox Player application was located, but no running player was detected."
        case .running:
            "macOS reports a running Roblox Player application. No connection was made."
        }
    }

    /// Identifying an app cannot establish the existence or safety of an
    /// authorized communications interface.
    var connectionAssessment: String {
        "Unknown — no connection or compatibility test performed"
    }
}

enum RobloxClientRecognition {
    static let playerBundleIdentifier = "com.roblox.RobloxPlayer"

    static func isPlayer(_ identifier: String?) -> Bool {
        identifier?.caseInsensitiveCompare(playerBundleIdentifier) == .orderedSame
    }

    static func snapshot(
        runningApplications: [RobloxProcessDescription],
        installedApplicationURL: URL?,
        checkedAt: Date = .now
    ) -> RobloxClientSnapshot {
        if let player = runningApplications.first(where: {
            isPlayer($0.bundleIdentifier)
        }) {
            return RobloxClientSnapshot(
                presence: .running,
                applicationURL: player.applicationURL ?? installedApplicationURL,
                bundleIdentifier: player.bundleIdentifier,
                processIdentifier: player.processIdentifier,
                checkedAt: checkedAt
            )
        }

        if let url = installedApplicationURL {
            return RobloxClientSnapshot(
                presence: .installed,
                applicationURL: url,
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
    @Published private(set) var snapshot: RobloxClientSnapshot = .unchecked

    func refresh() {
        let bundleID = RobloxClientRecognition.playerBundleIdentifier

        // NSWorkspace exposes the process details already known to macOS.
        // This does not launch, message, attach to, or inspect Roblox itself.
        let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .map {
                RobloxProcessDescription(
                    bundleIdentifier: $0.bundleIdentifier,
                    applicationURL: $0.bundleURL,
                    processIdentifier: $0.processIdentifier
                )
            }

        let installed = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
            ?? Self.findPlayerAtKnownLocations()

        snapshot = RobloxClientRecognition.snapshot(
            runningApplications: running,
            installedApplicationURL: installed
        )
    }

    /// Roblox's public macOS help describes an outer Roblox.app containing
    /// the playable Roblox.app bundle in Contents/MacOS. These paths are only
    /// read for existence and bundle identity; no executable is launched.
    private static func findPlayerAtKnownLocations() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            URL(fileURLWithPath: "/Applications/Roblox.app", isDirectory: true),
            home.appendingPathComponent("Applications/Roblox.app", isDirectory: true)
        ]

        for root in roots {
            let nested = root.appendingPathComponent(
                "Contents/MacOS/Roblox.app",
                isDirectory: true
            )
            for candidate in [nested, root] {
                guard let bundle = Bundle(url: candidate),
                      RobloxClientRecognition.isPlayer(bundle.bundleIdentifier) else {
                    continue
                }
                return candidate
            }
        }

        return nil
    }
}
