import Foundation
import Testing
@testable import MacExecutor

struct MacExecutorTests {
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
