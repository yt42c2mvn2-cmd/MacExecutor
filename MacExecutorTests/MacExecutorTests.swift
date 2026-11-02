import Foundation
import Testing
@testable import MacExecutor

struct MacExecutorTests {
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
