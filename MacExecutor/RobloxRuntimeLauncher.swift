import Foundation
import AppKit

/// Opens the actual, pristine Roblox Player working copy with LaunchServices.
///
/// This is an ordinary, unmodified application launch. There are no DYLD
/// overrides, entitlement changes, library injection, VM hooks or anti-cheat
/// workarounds. A separate launch check confirms the OS did not substitute
/// the primary /Applications installation for the requested working copy.
@MainActor
enum RobloxRuntimeLauncher {
    struct LaunchReport: Sendable {
        let processID: Int32
        let requestedBundlePath: String
        let reportedBundlePath: String
        let manifest: RobloxRuntimeMethod.Manifest
    }

    enum LaunchError: LocalizedError {
        case noApplicationReturned
        case applicationSubstituted(expected: String, actual: String)

        var errorDescription: String? {
            switch self {
            case .noApplicationReturned:
                "LaunchServices didn't return a running app. Roblox may require its normal website launcher."
            case .applicationSubstituted(let expected, let actual):
                "macOS opened a different Roblox installation, not the working copy.\nExpected: \(expected)\nReported: \(actual)"
            }
        }
    }

    /// Pure URL comparison that can be tested without opening a game process.
    nonisolated static func isRequestedWorkingCopy(
        _ requested: URL,
        reported: URL?
    ) -> Bool {
        guard let reported else { return false }
        return requested.standardizedFileURL.resolvingSymlinksInPath()
            == reported.standardizedFileURL.resolvingSymlinksInPath()
    }

    static func openPristineWorkingCopy(
        manifest: RobloxRuntimeMethod.Manifest
    ) async throws -> LaunchReport {
        // Run code-signing and executable SHA-256 checks off the UI actor.
        try await Task.detached(priority: .userInitiated) {
            try RobloxRuntimeMethod.verifyPristine(manifest)
        }.value

        let bundleURL = URL(fileURLWithPath: manifest.workingBundlePath, isDirectory: true)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.allowsRunningApplicationSubstitution = false
        configuration.activates = true
        configuration.addsToRecentItems = false

        let application = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<NSRunningApplication, Error>) in
            NSWorkspace.shared.openApplication(
                at: bundleURL,
                configuration: configuration
            ) { launchedApplication, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let launchedApplication {
                    continuation.resume(returning: launchedApplication)
                } else {
                    continuation.resume(throwing: LaunchError.noApplicationReturned)
                }
            }
        }

        guard isRequestedWorkingCopy(bundleURL, reported: application.bundleURL) else {
            throw LaunchError.applicationSubstituted(
                expected: bundleURL.path,
                actual: application.bundleURL?.path ?? "(unknown)"
            )
        }

        // Record launched=true only in the external research manifest.
        // Roblox.app remains unmodified and retains its original signature.
        let updated = try await Task.detached(priority: .utility) {
            try RobloxRuntimeMethod.recordSuccessfulLaunch(manifest)
        }.value

        return LaunchReport(
            processID: application.processIdentifier,
            requestedBundlePath: bundleURL.path,
            reportedBundlePath: application.bundleURL?.path ?? "(unknown)",
            manifest: updated
        )
    }
}
