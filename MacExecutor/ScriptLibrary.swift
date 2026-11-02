import Foundation
import Combine

struct SavedScript: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var source: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        source: String,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.updatedAt = updatedAt
    }
}

/// Manages editable tabs and persists the script library in Application Support.
/// The files are local to Rebilium, not synced to Roblox.
@MainActor
final class ScriptLibrary: ObservableObject {
    @Published private(set) var scripts: [SavedScript] = []
    @Published private(set) var openIDs: [UUID] = []
    @Published private(set) var selectedID: UUID?
    @Published private(set) var storageError: String?

    private let storageURL: URL

    init(storageURL: URL? = nil) {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        self.storageURL = storageURL
            ?? appSupport.appendingPathComponent("Rebilium", isDirectory: true)
                .appendingPathComponent("scripts.json")

        if let data = try? Data(contentsOf: self.storageURL),
           let decoded = try? JSONDecoder().decode([SavedScript].self, from: data),
           !decoded.isEmpty {
            scripts = decoded
        } else {
            scripts = [
                SavedScript(
                    title: "Welcome",
                    source: """
                    -- Welcome to Rebilium
                    print("Hello from Rebilium!")

                    local x = 10
                    local y = 25
                    print("Result:", x + y)
                    """
                )
            ]
            if FileManager.default.fileExists(atPath: self.storageURL.path) {
                storageError = "The script library could not be read. Please check scripts.json."
            } else {
                save()
            }
        }

        if let first = scripts.first {
            selectedID = first.id
            openIDs = [first.id]
        }
    }

    var selectedScript: SavedScript? {
        scripts.first { $0.id == selectedID }
    }

    var openScripts: [SavedScript] {
        openIDs.compactMap { id in scripts.first { $0.id == id } }
    }

    @discardableResult
    func createScript() -> UUID {
        let newScript = SavedScript(title: "Untitled \(scripts.count + 1)", source: "")
        scripts.insert(newScript, at: 0)
        select(newScript.id)
        save()
        return newScript.id
    }

    func select(_ id: UUID) {
        guard scripts.contains(where: { $0.id == id }) else { return }
        if !openIDs.contains(id) { openIDs.append(id) }
        selectedID = id
    }

    func closeTab(_ id: UUID) {
        openIDs.removeAll { $0 == id }
        guard selectedID == id else { return }
        selectedID = openIDs.last
        if selectedID == nil, let first = scripts.first {
            select(first.id)
        }
    }

    func updateSource(_ text: String) {
        guard let id = selectedID,
              let index = scripts.firstIndex(where: { $0.id == id }),
              scripts[index].source != text else { return }
        scripts[index].source = text
        scripts[index].updatedAt = .now
        save()
    }

    func rename(_ id: UUID, to title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].title = cleaned
        scripts[index].updatedAt = .now
        save()
    }

    /// Import a reviewed remote script without running it.
    @discardableResult
    func importScript(title: String, source: String) -> UUID {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let imported = SavedScript(
            title: cleaned.isEmpty ? "Imported Script" : cleaned,
            source: source
        )
        scripts.insert(imported, at: 0)
        select(imported.id)
        save()
        return imported.id
    }

    func duplicate(_ id: UUID) {
        guard let original = scripts.first(where: { $0.id == id }) else { return }
        let copy = SavedScript(title: original.title + " Copy", source: original.source)
        scripts.insert(copy, at: 0)
        select(copy.id)
        save()
    }

    func delete(_ id: UUID) {
        scripts.removeAll { $0.id == id }
        openIDs.removeAll { $0 == id }

        if scripts.isEmpty {
            createScript()
        } else {
            if selectedID == id {
                selectedID = nil
                if let next = openIDs.last ?? scripts.first?.id { select(next) }
            }
            save()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(scripts)
            try data.write(to: storageURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "Could not autosave scripts: \(error.localizedDescription)"
        }
    }
}
