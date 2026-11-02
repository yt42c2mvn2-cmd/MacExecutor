import Foundation

/// A deliberately narrow wire format for future authorized integrations.
/// Only ping/pong and status are representable. This layer cannot execute
/// scripts, attach to processes, scan ports or communicate with Roblox.
enum BridgeAction: String, Codable, Equatable {
    case ping, pong, status
}

struct BridgeEnvelope: Codable, Equatable {
    let version: Int
    let requestID: UUID
    let action: BridgeAction
    let payload: String

    init(version: Int = BridgeWireProtocol.version,
         requestID: UUID = UUID(),
         action: BridgeAction,
         payload: String = "") {
        self.version = version
        self.requestID = requestID
        self.action = action
        self.payload = payload
    }
}

enum BridgeProtocolError: Error, LocalizedError, Equatable {
    case oversizedMessage
    case incompatibleVersion
    case unexpectedAction
    case mismatchedRequest
    case unexpectedPayload

    var errorDescription: String? {
        switch self {
        case .oversizedMessage:
            "Bridge message exceeds the size limit."
        case .incompatibleVersion:
            "Bridge message uses an unsupported version."
        case .unexpectedAction:
            "Bridge message type is not valid in this context."
        case .mismatchedRequest:
            "Bridge reply does not match its original request."
        case .unexpectedPayload:
            "Bridge diagnostic message had unexpected contents."
        }
    }
}

/// A transport-independent, testable protocol for controlled integrations.
/// No network listener is opened here. In the local self-test both sides
/// serialize and parse their messages in memory.
enum BridgeWireProtocol {
    static let version = 1
    static let maxMessageBytes = 4_096
    static let diagnosticMarker = "rebilium-local-ping-v1"
    static let studioStatusMarker = "rebilium-studio-status-v1"
    static let studioConnectedMarker = "studio-connected"
    static let studioDisconnectedMarker = "studio-not-connected"

    static func encode(_ envelope: BridgeEnvelope) throws -> Data {
        guard envelope.version == version else {
            throw BridgeProtocolError.incompatibleVersion
        }
        let bytes = try JSONEncoder().encode(envelope)
        guard bytes.count <= maxMessageBytes else {
            throw BridgeProtocolError.oversizedMessage
        }
        return bytes
    }

    static func decode(_ bytes: Data) throws -> BridgeEnvelope {
        guard bytes.count <= maxMessageBytes else {
            throw BridgeProtocolError.oversizedMessage
        }
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: bytes)
        guard decoded.version == version else {
            throw BridgeProtocolError.incompatibleVersion
        }
        return decoded
    }

    /// Simulates the approved remote peer without reaching any external app.
    static func localPeerReply(to requestData: Data) throws -> Data {
        let request = try decode(requestData)
        guard request.action == .ping else {
            throw BridgeProtocolError.unexpectedAction
        }
        guard request.payload == diagnosticMarker else {
            throw BridgeProtocolError.unexpectedPayload
        }
        return try encode(BridgeEnvelope(
            requestID: request.requestID,
            action: .pong,
            payload: diagnosticMarker
        ))
    }

    static func validateReply(_ bytes: Data, to ping: BridgeEnvelope) throws {
        let reply = try decode(bytes)
        guard reply.action == .pong else {
            throw BridgeProtocolError.unexpectedAction
        }
        guard reply.requestID == ping.requestID else {
            throw BridgeProtocolError.mismatchedRequest
        }
        guard reply.payload == diagnosticMarker else {
            throw BridgeProtocolError.unexpectedPayload
        }
    }

    static func validateStudioStatus(
        _ bytes: Data,
        to request: BridgeEnvelope
    ) throws -> Bool {
        let reply = try decode(bytes)
        guard request.action == .status, reply.action == .status else {
            throw BridgeProtocolError.unexpectedAction
        }
        guard reply.requestID == request.requestID else {
            throw BridgeProtocolError.mismatchedRequest
        }
        switch reply.payload {
        case studioConnectedMarker: return true
        case studioDisconnectedMarker: return false
        default: throw BridgeProtocolError.unexpectedPayload
        }
    }

    static func selfTest() throws -> BridgeTestResult {
        let ping = BridgeEnvelope(action: .ping, payload: diagnosticMarker)
        let wireRequest = try encode(ping)
        let wireReply = try localPeerReply(to: wireRequest)
        try validateReply(wireReply, to: ping)
        return BridgeTestResult(
            requestID: ping.requestID,
            requestBytes: wireRequest.count,
            responseBytes: wireReply.count,
            completedAt: .now
        )
    }
}

struct BridgeTestResult: Equatable {
    let requestID: UUID
    let requestBytes: Int
    let responseBytes: Int
    let completedAt: Date
}
