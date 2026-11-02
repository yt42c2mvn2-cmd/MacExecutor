import Foundation

struct ScriptBloxGame: Decodable {
    let name: String?
}

struct ScriptBloxEntry: Decodable, Identifiable {
    let id: String
    let title: String
    let slug: String?
    let game: ScriptBloxGame?
    let script: String?
    let verified: Bool
    let key: Bool
    let isPatched: Bool
    let views: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id", title, slug, game, script, verified, key, isPatched, views
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        game = try container.decodeIfPresent(ScriptBloxGame.self, forKey: .game)
        script = try container.decodeIfPresent(String.self, forKey: .script)
        verified = try container.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        key = try container.decodeIfPresent(Bool.self, forKey: .key) ?? false
        isPatched = try container.decodeIfPresent(Bool.self, forKey: .isPatched) ?? false
        views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
    }
}

struct ScriptBloxResult: Decodable {
    let scripts: [ScriptBloxEntry]
}

struct ScriptBloxListEnvelope: Decodable {
    let result: ScriptBloxResult
}

struct ScriptBloxDetailEnvelope: Decodable {
    let script: ScriptBloxEntry
}

enum ScriptBloxServiceError: LocalizedError {
    case badURL
    case invalidResponse
    case serverError(Int)
    case emptySource
    case sourceTooLong

    var errorDescription: String? {
        switch self {
        case .badURL: return "Could not construct the ScriptBlox request."
        case .invalidResponse: return "ScriptBlox returned an unexpected response."
        case .serverError(let code): return "ScriptBlox returned HTTP \(code)."
        case .emptySource: return "This ScriptBlox entry does not include script source."
        case .sourceTooLong: return "This script is too large to preview and import."
        }
    }
}

/// Read-only integration with the documented ScriptBlox public API.
/// Remote code is never evaluated or run while browsing.
enum ScriptBloxService {
    private static let baseURL = URL(string: "https://scriptblox.com")!

    static func trending() async throws -> [ScriptBloxEntry] {
        let url = baseURL.appendingPathComponent("api/script/trending")
        let envelope: ScriptBloxListEnvelope = try await request(url)
        return envelope.result.scripts
    }

    static func search(_ query: String) async throws -> [ScriptBloxEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/script/search"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "max", value: "20"),
            URLQueryItem(name: "mode", value: "free"),
            URLQueryItem(name: "sortBy", value: "views"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "strict", value: "false")
        ]
        guard let url = components?.url else { throw ScriptBloxServiceError.badURL }
        let envelope: ScriptBloxListEnvelope = try await request(url)
        return envelope.result.scripts
    }

    static func source(for entry: ScriptBloxEntry) async throws -> String {
        if let source = entry.script, !source.isEmpty {
            return try checkedSource(source)
        }

        let url = baseURL.appendingPathComponent("api/script")
            .appendingPathComponent(entry.id)
        let envelope: ScriptBloxDetailEnvelope = try await request(url)
        guard let source = envelope.script.script, !source.isEmpty else {
            throw ScriptBloxServiceError.emptySource
        }
        return try checkedSource(source)
    }

    private static func checkedSource(_ text: String) throws -> String {
        guard text.utf8.count <= 500_000 else {
            throw ScriptBloxServiceError.sourceTooLong
        }
        return text
    }

    private static func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScriptBloxServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ScriptBloxServiceError.serverError(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
