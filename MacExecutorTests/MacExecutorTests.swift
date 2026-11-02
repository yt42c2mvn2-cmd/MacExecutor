import Foundation
import Testing
@testable import MacExecutor

struct MacExecutorTests {
    private func createMockPlayer(
        at location: URL,
        identifier: String = "com.roblox.RobloxPlayer",
        architecture: [UInt8] = [0xCF, 0xFA, 0xED, 0xFE, 0x07, 0, 0, 0x01]
    ) throws -> URL {
        let app = location.appendingPathComponent("Roblox.app", isDirectory: true)
        let executableFolder = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(
            at: executableFolder, withIntermediateDirectories: true
        )
        let properties: [String: Any] = [
            "CFBundleIdentifier": identifier,
            "CFBundleExecutable": "RobloxPlayer",
            "CFBundlePackageType": "APPL",
            "CFBundleName": "Roblox"
        ]
        let info = try PropertyListSerialization.data(
            fromPropertyList: properties, format: .xml, options: 0
        )
        try info.write(
            to: app.appendingPathComponent("Contents/Info.plist")
        )
        try Data(architecture + [1, 2, 3, 4]).write(
            to: executableFolder.appendingPathComponent("RobloxPlayer")
        )
        return app
    }

    @Test
    func runtimeWorkingCopyPreservesPlayerExecutableAndNeverModifiesSource() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(
            "rebilium-runtime-test-" + UUID().uuidString, isDirectory: true
        )
        defer { try? manager.removeItem(at: root) }

        let source = try createMockPlayer(at: root.appendingPathComponent("install"))
        var inspectedPaths: [String] = []
        let manifest = try RobloxRuntimeMethod.prepare(
            source: source,
            workspaceRoot: root.appendingPathComponent("workspace"),
            verifySignature: { inspectedPaths.append($0.path) }
        )

        #expect(inspectedPaths.count == 2)
        #expect(inspectedPaths[0] == source.path)
        #expect(inspectedPaths[1] == manifest.workingBundlePath)
        #expect(manifest.method == RobloxRuntimeMethod.methodID)
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.signingVerified)
        #expect(manifest.modified == false)
        #expect(manifest.launched == false)
        #expect(manifest.sourceExecutableSHA256 == manifest.workingExecutableSHA256)
        #expect(FileManager.default.fileExists(atPath: manifest.sourceBundlePath))
        #expect(FileManager.default.fileExists(atPath: manifest.workingBundlePath))
        #expect(manifest.sourceBundlePath != manifest.workingBundlePath)

        let manifestURL = URL(fileURLWithPath: manifest.workingBundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("manifest.json")
        let decoded = try JSONDecoder().decode(
            RobloxRuntimeMethod.Manifest.self,
            from: Data(contentsOf: manifestURL)
        )
        #expect(decoded == manifest)
    }

    @Test
    func runtimeLaunchPreflightVerifiesSourceCopyAndExternalManifest() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(
            "rebilium-launch-test-" + UUID().uuidString, isDirectory: true
        )
        defer { try? manager.removeItem(at: root) }
        let original = try createMockPlayer(at: root.appendingPathComponent("installed"))
        let destinationRoot = root.appendingPathComponent("workspaces")
        let manifest = try RobloxRuntimeMethod.prepare(
            source: original,
            workspaceRoot: destinationRoot,
            verifySignature: { _ in }
        )
        try RobloxRuntimeMethod.verifyPristine(
            manifest,
            workspaceRoot: destinationRoot,
            verifySignature: { _ in }
        )
        let recorded = try RobloxRuntimeMethod.recordSuccessfulLaunch(manifest)
        #expect(recorded.launched)
        #expect(!recorded.modified)
        try RobloxRuntimeMethod.verifyPristine(
            recorded,
            workspaceRoot: destinationRoot,
            verifySignature: { _ in }
        )
        let originalBinary = try RobloxRuntimeMethod.executable(at: original)
        let originalBytes = try Data(contentsOf: originalBinary)
        #expect(try Data(contentsOf: originalBinary) == originalBytes)

        // Appending data preserves the Mach-O header but changes the hash.
        let copied = try RobloxRuntimeMethod.executable(
            at: URL(fileURLWithPath: manifest.workingBundlePath)
        )
        let handle = try FileHandle(forWritingTo: copied)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0x0A]))
        try handle.close()
        #expect(throws: RobloxRuntimeMethod.MethodError.self) {
            try RobloxRuntimeMethod.verifyPristine(
                recorded,
                workspaceRoot: destinationRoot,
                verifySignature: { _ in }
            )
        }
        #expect(try Data(contentsOf: originalBinary) == originalBytes)
    }

    @Test
    func runtimeLauncherDetectsSubstitutedOrUnknownBundle() {
        let copied = URL(fileURLWithPath: "/tmp/Rebilium/Workspace-A/Roblox.app")
        let installed = URL(fileURLWithPath: "/Applications/Roblox.app")

        #expect(RobloxRuntimeLauncher.isRequestedWorkingCopy(copied, reported: copied))
        #expect(!RobloxRuntimeLauncher.isRequestedWorkingCopy(copied, reported: installed))
        #expect(!RobloxRuntimeLauncher.isRequestedWorkingCopy(copied, reported: nil))
    }

    @Test
    func runtimeMethodRejectsNonPlayerAndOtherArchitecture() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(
            "rebilium-reject-test-" + UUID().uuidString, isDirectory: true
        )
        defer { try? manager.removeItem(at: root) }

        let fakeStudio = try createMockPlayer(
            at: root.appendingPathComponent("studio"),
            identifier: "com.roblox.RobloxStudio"
        )
        #expect(throws: RobloxRuntimeMethod.MethodError.self) {
            try RobloxRuntimeMethod.executable(at: fakeStudio)
        }

        let wrongCPU = try createMockPlayer(
            at: root.appendingPathComponent("arm"),
            architecture: [0xCF, 0xFA, 0xED, 0xFE, 0x0C, 0, 0, 0x01]
        )
        #expect(throws: RobloxRuntimeMethod.MethodError.self) {
            try RobloxRuntimeMethod.executable(at: wrongCPU)
        }
    }

    @Test
    func runtimeMethodDeletesFailedWorkingCopyWithoutChangingOriginal() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(
            "rebilium-cleanup-test-" + UUID().uuidString, isDirectory: true
        )
        defer { try? manager.removeItem(at: root) }

        let source = try createMockPlayer(at: root.appendingPathComponent("original"))
        let sourceBinary = try RobloxRuntimeMethod.executable(at: source)
        let originalData = try Data(contentsOf: sourceBinary)
        let targetRoot = root.appendingPathComponent("working")
        var verificationCount = 0

        #expect(throws: RobloxRuntimeMethod.MethodError.self) {
            try RobloxRuntimeMethod.prepare(
                source: source,
                workspaceRoot: targetRoot,
                verifySignature: { _ in
                    verificationCount += 1
                    if verificationCount == 2 {
                        throw RobloxRuntimeMethod.MethodError.signatureRejected("test")
                    }
                }
            )
        }

        #expect(verificationCount == 2)
        #expect(try Data(contentsOf: sourceBinary) == originalData)
        let remaining = try manager.contentsOfDirectory(
            atPath: targetRoot.path
        )
        #expect(remaining.isEmpty)
    }

    @Test
    func studioStatusAcceptsOnlyVersionedCorrelatedReplies() throws {
        let request = BridgeEnvelope(
            action: .status,
            payload: BridgeWireProtocol.studioStatusMarker
        )

        let online = try BridgeWireProtocol.encode(BridgeEnvelope(
            requestID: request.requestID,
            action: .status,
            payload: BridgeWireProtocol.studioConnectedMarker
        ))
        let offline = try BridgeWireProtocol.encode(BridgeEnvelope(
            requestID: request.requestID,
            action: .status,
            payload: BridgeWireProtocol.studioDisconnectedMarker
        ))
        #expect(try BridgeWireProtocol.validateStudioStatus(online, to: request))
        #expect(try !BridgeWireProtocol.validateStudioStatus(offline, to: request))

        let unrelated = try BridgeWireProtocol.encode(BridgeEnvelope(
            action: .status,
            payload: BridgeWireProtocol.studioConnectedMarker
        ))
        #expect(throws: BridgeProtocolError.self) {
            try BridgeWireProtocol.validateStudioStatus(unrelated, to: request)
        }

        let wrongPayload = try BridgeWireProtocol.encode(BridgeEnvelope(
            requestID: request.requestID,
            action: .status,
            payload: "execute"
        ))
        #expect(throws: BridgeProtocolError.self) {
            try BridgeWireProtocol.validateStudioStatus(wrongPayload, to: request)
        }
    }

    @Test
    func backendPingPongCompletesWithoutAnyNetwork() throws {
        let result = try BridgeWireProtocol.selfTest()
        #expect(result.requestBytes > 0)
        #expect(result.responseBytes > 0)
        #expect(result.requestID != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test
    func backendRejectsUnsupportedVersionsAndOversizeMessages() throws {
        let wrongVersion = BridgeEnvelope(version: 77, action: .ping)
        #expect(throws: BridgeProtocolError.self) {
            try BridgeWireProtocol.encode(wrongVersion)
        }

        let oversized = BridgeEnvelope(
            action: .ping,
            payload: String(repeating: "x", count: BridgeWireProtocol.maxMessageBytes)
        )
        #expect(throws: BridgeProtocolError.self) {
            try BridgeWireProtocol.encode(oversized)
        }
    }

    @Test
    func backendCorrelatesRepliesAndChecksActions() throws {
        let request = BridgeEnvelope(action: .ping, payload: BridgeWireProtocol.diagnosticMarker)
        let wrongAction = try BridgeWireProtocol.encode(
            BridgeEnvelope(requestID: request.requestID, action: .status)
        )
        #expect(throws: BridgeProtocolError.self) {
            try BridgeWireProtocol.validateReply(wrongAction, to: request)
        }

        let wrongRequest = try BridgeWireProtocol.encode(
            BridgeEnvelope(action: .pong, payload: BridgeWireProtocol.diagnosticMarker)
        )
        #expect(throws: BridgeProtocolError.self) {
            try BridgeWireProtocol.validateReply(wrongRequest, to: request)
        }
    }

    @Test
    func installationPickerAcceptsOnlyPlayerBundles() {
        let root = URL(fileURLWithPath: "/My Games/Roblox.app", isDirectory: true)
        let inner = root.appendingPathComponent("Contents/MacOS/Roblox.app", isDirectory: true)
        let studio = URL(fileURLWithPath: "/Applications/RobloxStudio.app", isDirectory: true)

        #expect(RobloxClientRecognition.resolvePlayer(at: root) { candidate in
            candidate == inner ? "com.roblox.RobloxPlayer" : nil
        } == inner)

        #expect(RobloxClientRecognition.resolvePlayer(at: inner) { candidate in
            candidate == inner ? "com.roblox.RobloxPlayer" : nil
        } == inner)

        #expect(RobloxClientRecognition.resolvePlayer(at: studio) { _ in
            "com.Roblox.RobloxStudio"
        } == nil)
    }

    @Test
    func selectedInstallationDoesNotClaimDifferentPlayerIsRunning() {
        let selected = URL(fileURLWithPath: "/Applications/Roblox.app")
        let elsewhere = URL(fileURLWithPath: "/Users/test/Games/Roblox.app")
        let running = RobloxProcessDescription(
            bundleIdentifier: "com.roblox.RobloxPlayer",
            applicationURL: elsewhere,
            processIdentifier: 3456
        )

        let selectedSnapshot = RobloxClientRecognition.snapshot(
            runningApplications: [running],
            installedApplicationURL: selected,
            restrictToInstalledURL: true
        )
        #expect(selectedSnapshot.presence == .installed)
        #expect(selectedSnapshot.processIdentifier == nil)

        let autoSnapshot = RobloxClientRecognition.snapshot(
            runningApplications: [running],
            installedApplicationURL: selected
        )
        #expect(autoSnapshot.presence == .running)
    }

    @Test
    func iconThemeManualChoicesStayPredictable() {
        #expect(RebiliumIconTheme.isDark("dark"))
        #expect(!RebiliumIconTheme.isDark("light"))
        #expect(RebiliumIconTheme.imageAssetName(for: "dark") == "RebiliumDarkIcon")
        #expect(RebiliumIconTheme.imageAssetName(for: "light") == "RebiliumLightIcon")
    }

    @Test
    func playerRunningIsRecognizedWithoutAssumingConnection() {
        let appURL = URL(fileURLWithPath: "/Applications/Roblox.app")
        let running = RobloxProcessDescription(
            bundleIdentifier: "com.roblox.RobloxPlayer",
            applicationURL: appURL,
            processIdentifier: 4312
        )

        let snapshot = RobloxClientRecognition.snapshot(
            runningApplications: [running],
            installedApplicationURL: appURL
        )

        #expect(snapshot.presence == .running)
        #expect(snapshot.processIdentifier == 4312)
        #expect(snapshot.applicationURL == appURL)
        #expect(snapshot.connectionAssessment.contains("Unknown"))
    }

    @Test
    func studioIsNotMistakenForPlayer() {
        let studio = RobloxProcessDescription(
            bundleIdentifier: "com.Roblox.RobloxStudio",
            applicationURL: URL(fileURLWithPath: "/Applications/RobloxStudio.app"),
            processIdentifier: 345
        )

        let snapshot = RobloxClientRecognition.snapshot(
            runningApplications: [studio],
            installedApplicationURL: nil
        )

        #expect(snapshot.presence == .notFound)
        #expect(snapshot.processIdentifier == nil)
        #expect(!RobloxClientRecognition.isPlayer("com.Roblox.RobloxStudio"))
        #expect(!RobloxClientRecognition.isPlayer(nil))
    }

    @Test
    func installedButNotRunningIsReportedSeparately() {
        let appURL = URL(fileURLWithPath: "/Applications/Roblox.app")
        let snapshot = RobloxClientRecognition.snapshot(
            runningApplications: [],
            installedApplicationURL: appURL
        )

        #expect(snapshot.presence == .installed)
        #expect(snapshot.applicationURL == appURL)
        #expect(snapshot.processIdentifier == nil)
        #expect(snapshot.connectionAssessment.contains("no connection"))
    }

    @Test
    func missingPlayerRemainsUnknownForCompatibility() {
        let snapshot = RobloxClientRecognition.snapshot(
            runningApplications: [],
            installedApplicationURL: nil
        )

        #expect(snapshot.presence == .notFound)
        #expect(snapshot.applicationURL == nil)
        #expect(snapshot.connectionAssessment.contains("Unknown"))
    }

    @Test @MainActor
    func scriptsSurviveRelaunch() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RebiliumTests-\(UUID().uuidString)", isDirectory: true)
        let file = folder.appendingPathComponent("scripts.json")
        defer { try? FileManager.default.removeItem(at: folder) }

        let first = ScriptLibrary(storageURL: file)
        let id = first.createScript()
        first.rename(id, to: "Saved script")
        first.updateSource("print(123)")

        let reopened = ScriptLibrary(storageURL: file)
        #expect(reopened.scripts.contains {
            $0.id == id && $0.title == "Saved script" && $0.source == "print(123)"
        })
        #expect(reopened.storageError == nil)
    }

    @Test @MainActor
    func tabsCanSwitchAndCloseWithoutDeletingScripts() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RebiliumTests-\(UUID().uuidString)", isDirectory: true)
        let file = folder.appendingPathComponent("scripts.json")
        defer { try? FileManager.default.removeItem(at: folder) }

        let library = ScriptLibrary(storageURL: file)
        let firstID = library.selectedID
        let secondID = library.createScript()

        #expect(library.openIDs.count == 2)
        library.closeTab(secondID)
        #expect(library.selectedID == firstID)
        #expect(library.scripts.contains { $0.id == secondID })

        library.select(secondID)
        #expect(library.selectedID == secondID)
    }

    @Test @MainActor
    func importedScriptsAreSavedWithoutExecuting() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RebiliumTests-\(UUID().uuidString)", isDirectory: true)
        let file = folder.appendingPathComponent("scripts.json")
        defer { try? FileManager.default.removeItem(at: folder) }

        let library = ScriptLibrary(storageURL: file)
        let scriptID = library.importScript(
            title: " Example ",
            source: "print('imported')"
        )
        #expect(library.selectedID == scriptID)
        #expect(library.selectedScript?.title == "Example")
        #expect(library.selectedScript?.source == "print('imported')")

        let reloaded = ScriptLibrary(storageURL: file)
        #expect(reloaded.scripts.contains { $0.id == scriptID })
    }

    @Test
    func scriptBloxEntriesDecodeWithOptionalFields() throws {
        let data = Data("""
        {"result":{"scripts":[
          {"_id":"test123","title":"Sample","views":120,"game":{"name":"Example"}},
          {"_id":"test456","title":"With source","script":"print(5)","verified":true,"key":false}
        ]}}
        """.utf8)

        let response = try JSONDecoder().decode(
            ScriptBloxListEnvelope.self,
            from: data
        )
        #expect(response.result.scripts.count == 2)
        #expect(response.result.scripts[0].id == "test123")
        #expect(response.result.scripts[0].verified == false)
        #expect(response.result.scripts[0].game?.name == "Example")
        #expect(response.result.scripts[1].script == "print(5)")
        #expect(response.result.scripts[1].verified)
    }

    @Test @MainActor
    func duplicateCopiesScriptContents() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("RebiliumTests-\(UUID().uuidString)", isDirectory: true)
        let file = folder.appendingPathComponent("scripts.json")
        defer { try? FileManager.default.removeItem(at: folder) }

        let library = ScriptLibrary(storageURL: file)
        library.updateSource("print('copy')")
        let originalID = try #require(library.selectedID)
        library.duplicate(originalID)
        let copy = try #require(library.selectedScript)

        #expect(copy.id != originalID)
        #expect(copy.source == "print('copy')")
        #expect(copy.title == "Welcome Copy")
    }
}
