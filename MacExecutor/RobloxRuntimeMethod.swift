import Foundation
import CryptoKit

/// A method object representing an isolated, verified workspace for the
/// *real installed* macOS Roblox Player. It never modifies a Roblox binary,
/// changes its signature, launches the copy, or attaches to any process.
enum RobloxRuntimeMethod {
    static let methodID = "signed-player-working-copy-v1"
    static let playerIdentifier = RobloxClientRecognition.playerBundleIdentifier

    struct Manifest: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let method: String
        let sourceBundlePath: String
        let workingBundlePath: String
        let sourceExecutableSHA256: String
        let workingExecutableSHA256: String
        let preparedAt: Date
        let modified: Bool
        let launched: Bool
        let signingVerified: Bool
    }

    enum MethodError: Error, LocalizedError {
        case notRobloxPlayer
        case missingExecutable
        case wrongArchitecture
        case cannotUseWorkingCopyAsSource
        case notEnoughDiskSpace
        case signatureRejected(String)
        case contentChanged
        case duplicateWorkspace

        var errorDescription: String? {
            switch self {
            case .notRobloxPlayer:
                "Select the actual com.roblox.RobloxPlayer app, not Roblox Studio."
            case .missingExecutable:
                "The Player bundle does not contain its declared executable."
            case .wrongArchitecture:
                "This method currently supports the x86_64 Roblox Player only."
            case .cannotUseWorkingCopyAsSource:
                "Choose the original installed Roblox Player, not a Rebilium workspace."
            case .notEnoughDiskSpace:
                "Insufficient free storage for an isolated Roblox Player copy."
            case .signatureRejected(let message):
                "macOS rejected the application's code signature: \(message)"
            case .contentChanged:
                "The copied Player executable differs from the original; the workspace was discarded."
            case .duplicateWorkspace:
                "The proposed workspace is inside the source app or overlaps an existing workspace."
            }
        }
    }

    /// Does not read memory or query the Roblox process; checks only a
    /// selected, on-disk app bundle and its Mach-O header.
    static func executable(at applicationURL: URL) throws -> URL {
        let source = applicationURL.standardizedFileURL.resolvingSymlinksInPath()
        guard Bundle(url: source)?.bundleIdentifier?.caseInsensitiveCompare(playerIdentifier)
            == .orderedSame else {
            throw MethodError.notRobloxPlayer
        }
        guard let bundle = Bundle(url: source),
              let name = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
              !name.isEmpty else {
            throw MethodError.missingExecutable
        }
        let path = source.appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw MethodError.missingExecutable
        }
        let handle = try FileHandle(forReadingFrom: path)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 8) ?? Data()

        // MH_MAGIC_64 + CPU_TYPE_X86_64 in little endian.
        guard Array(header) == [0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00, 0x00, 0x01] else {
            throw MethodError.wrongArchitecture
        }
        return path
    }

    static func workspaceDirectory(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/Rebilium/PlayerRuntimeWorkspaces", isDirectory: true)
    }

    /// Creates a fresh, pristine copy of Roblox.app plus an external manifest.
    /// The signature validator runs on BOTH original and copied bundles.
    /// Tests can inject a validator that does not require a signed fixture.
    static func prepare(
        source sourceURL: URL,
        workspaceRoot root: URL = workspaceDirectory(),
        verifySignature: (URL) throws -> Void = verifyWithCodeSign
    ) throws -> Manifest {
        let source = sourceURL.standardizedFileURL.resolvingSymlinksInPath()
        let rootURL = root.standardizedFileURL.resolvingSymlinksInPath()
        guard !source.path.hasPrefix(rootURL.path + "/") else {
            throw MethodError.cannotUseWorkingCopyAsSource
        }

        let originalExecutable = try executable(at: source)
        try verifySignature(source)

        // Avoid starting an expensive copy when free space clearly cannot
        // hold the bundle. Prefer the allocated size, including nested files.
        let required = try estimatedBundleBytes(at: source)
        if let available = try? rootURL.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage,
           Int64(available) < required + 256 * 1024 * 1024 {
            throw MethodError.notEnoughDiskSpace
        }

        let manager = FileManager.default
        try manager.createDirectory(at: rootURL, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])

        let session = rootURL.appendingPathComponent("Workspace-" + UUID().uuidString,
                                                      isDirectory: true)
        let destination = session.appendingPathComponent("Roblox.app", isDirectory: true)
        guard !rootURL.path.hasPrefix(source.path + "/"),
              !session.path.hasPrefix(source.path + "/") else {
            throw MethodError.duplicateWorkspace
        }
        try manager.createDirectory(at: session, withIntermediateDirectories: false,
                                    attributes: [.posixPermissions: 0o700])

        var complete = false
        defer {
            if !complete {
                try? manager.removeItem(at: session)
            }
        }

        let sourceDigest = try sha256(originalExecutable)
        try manager.copyItem(at: source, to: destination)
        let copiedExecutable = try executable(at: destination)
        let copiedDigest = try sha256(copiedExecutable)
        guard sourceDigest == copiedDigest else {
            throw MethodError.contentChanged
        }
        try verifySignature(destination)

        let manifest = Manifest(
            schemaVersion: 1,
            method: methodID,
            sourceBundlePath: source.path,
            workingBundlePath: destination.path,
            sourceExecutableSHA256: sourceDigest,
            workingExecutableSHA256: copiedDigest,
            preparedAt: .now,
            modified: false,
            launched: false,
            signingVerified: true
        )
        let bytes = try JSONEncoder().encode(manifest)
        try bytes.write(to: session.appendingPathComponent("manifest.json"), options: .atomic)
        complete = true
        return manifest
    }

    private static func sha256(_ file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        while let block = try handle.read(upToCount: 1024 * 1024), !block.isEmpty {
            hash.update(data: block)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func estimatedBundleBytes(at source: URL) throws -> Int64 {
        let manager = FileManager.default
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let iterator = manager.enumerator(at: source, includingPropertiesForKeys: Array(keys),
                                                options: []) else {
            throw MethodError.notRobloxPlayer
        }
        // Enumerate all descendants, including nested app bundles and frameworks.
        var result: Int64 = 0
        for case let item as URL in iterator {
            let metadata = try item.resourceValues(forKeys: keys)
            if metadata.isRegularFile == true {
                result += Int64(metadata.totalFileAllocatedSize ?? metadata.fileAllocatedSize ?? 0)
            }
        }
        return result
    }

    private static func verifyWithCodeSign(_ application: URL) throws {
        let tool = Process()
        tool.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        tool.arguments = ["--verify", "--verbose=2", application.path]
        let output = Pipe()
        tool.standardOutput = output
        tool.standardError = output
        try tool.run()
        tool.waitUntilExit()
        guard tool.terminationStatus == 0 else {
            let diagnostic = String(data: output.fileHandleForReading.readDataToEndOfFile(),
                                    encoding: .utf8) ?? "verification failed"
            throw MethodError.signatureRejected(String(diagnostic.prefix(700)))
        }
    }
}
