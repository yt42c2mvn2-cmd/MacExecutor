import Foundation

/// Sends a user-selected Luau file to a paired, loopback-only backend.
/// The backend only stages text for manual Studio preview and import.
/// This never calls Roblox Player, runs scripts, or modifies game processes.
enum StudioScriptTransfer {
    static let maxSourceBytes = 65_536
    private static let endpoint = URL(
        string: "http://127.0.0.1:37828/v1/scripts/submit"
    )!

    enum TransferError: LocalizedError {
        case missingPairingToken
        case emptyScript
        case oversizedScript
        case invalidTitle
        case studioNotConnected
        case incorrectToken
        case unexpectedResponse

        var errorDescription: String? {
            switch self {
            case .missingPairingToken:
                "Paste this host session's pairing token into Rebilium first."
            case .emptyScript:
                "Select a nonempty script to preview in Studio."
            case .oversizedScript:
                "Script exceeds the 64 KiB preview transfer limit."
            case .invalidTitle:
                "Script name must contain between 1 and 80 characters."
            case .studioNotConnected:
                "Pair the Studio plugin and check its connection first."
            case .incorrectToken:
                "The backend rejected the pairing token."
            case .unexpectedResponse:
                "The backend returned an unexpected response."
            }
        }
    }

    private struct Offer: Encodable {
        let version: Int
        let title: String
        let source: String
    }

    private struct Accepted: Decodable {
        let version: Int
        let ok: Bool
        let id: String
    }

    static func submit(
        title: String,
        source: String,
        pairingToken: String
    ) async throws -> String {
        let token = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.count >= 20 else { throw TransferError.missingPairingToken }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty && cleanTitle.count <= 80 else {
            throw TransferError.invalidTitle
        }
        let size = source.lengthOfBytes(using: .utf8)
        guard size > 0 else { throw TransferError.emptyScript }
        guard size <= maxSourceBytes else { throw TransferError.oversizedScript }

        let body = try JSONEncoder().encode(
            Offer(version: 1, title: cleanTitle, source: source)
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Rebilium-Token")
        request.httpBody = body
        request.timeoutInterval = 8

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (responseData, urlResponse) = try await session.data(for: request)
        guard let response = urlResponse as? HTTPURLResponse else {
            throw TransferError.unexpectedResponse
        }
        switch response.statusCode {
        case 403: throw TransferError.incorrectToken
        case 409: throw TransferError.studioNotConnected
        case 200: break
        default: throw TransferError.unexpectedResponse
        }
        let accepted = try JSONDecoder().decode(Accepted.self, from: responseData)
        guard accepted.version == 1, accepted.ok,
              UUID(uuidString: accepted.id) != nil else {
            throw TransferError.unexpectedResponse
        }
        return accepted.id
    }
}
