import Foundation
import Testing
@testable import MacExecutor

struct MacExecutorTests {
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
