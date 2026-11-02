import Foundation
import Darwin

/// A real, local-only TCP roundtrip to our intentionally launched test host.
///
/// This client always targets IPv4 loopback, not Roblox, external addresses,
/// arbitrary ports, or processes. It transmits only the versioned ping marker.
enum LocalBridgeClient {
    static let defaultPort: UInt16 = 37827
    private static let timeoutSeconds = 3

    enum ConnectionError: Error, LocalizedError {
        case hostNotRunning
        case socketFailure(Int32)
        case connectionFailure(Int32)
        case sendFailure(Int32)
        case receiveFailure(Int32)
        case incompleteReply

        var errorDescription: String? {
            switch self {
            case .hostNotRunning:
                "Test host not running. Start it in Terminal, then try again."
            case .socketFailure(let code):
                "Could not create the local socket (errno \(code))."
            case .connectionFailure(let code):
                "Could not reach the test host on localhost (errno \(code))."
            case .sendFailure(let code):
                "Could not send the diagnostic ping (errno \(code))."
            case .receiveFailure(let code):
                "Could not read the test host response (errno \(code))."
            case .incompleteReply:
                "The test host closed the connection before sending a full reply."
            }
        }
    }

    /// Synchronous socket I/O. Call this off the main actor (see ContentView).
    /// The port can be injected by the separate CI probe to avoid port conflicts;
    /// the Rebilium UI always uses the constant defaultPort.
    static func ping(port: UInt16 = defaultPort) throws -> BridgeTestResult {
        let request = BridgeEnvelope(
            action: .ping,
            payload: BridgeWireProtocol.diagnosticMarker
        )
        let (requestBytes, response) = try exchange(request, port: port)
        try BridgeWireProtocol.validateReply(response, to: request)
        return BridgeTestResult(
            requestID: request.requestID,
            requestBytes: requestBytes,
            responseBytes: response.count,
            completedAt: .now
        )
    }

    /// Reports a recent authenticated Studio plugin heartbeat, not Roblox
    /// Player compatibility or script execution.
    static func studioIsConnected(port: UInt16 = defaultPort) throws -> Bool {
        let request = BridgeEnvelope(
            action: .status,
            payload: BridgeWireProtocol.studioStatusMarker
        )
        let (_, response) = try exchange(request, port: port)
        return try BridgeWireProtocol.validateStudioStatus(response, to: request)
    }

    private static func exchange(
        _ envelope: BridgeEnvelope,
        port: UInt16
    ) throws -> (Int, Data) {
        var request = try BridgeWireProtocol.encode(envelope)
        let messageLength = request.count
        request.append(0x0A)

        let socketFD = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw ConnectionError.socketFailure(errno)
        }
        defer { _ = Darwin.close(socketFD) }

        // macOS normally delivers SIGPIPE when writing to a disconnected TCP
        // peer. Never let a stopped or malfunctioning test host crash Rebilium.
        var ignoreBrokenPipe: Int32 = 1
        let optionSize = socklen_t(MemoryLayout<Int32>.size)
        _ = Darwin.setsockopt(
            socketFD, SOL_SOCKET, SO_NOSIGPIPE, &ignoreBrokenPipe, optionSize
        )

        var timeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
        let size = socklen_t(MemoryLayout<timeval>.size)
        _ = withUnsafePointer(to: &timeout) { pointer in
            Darwin.setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, pointer, size)
        }
        _ = withUnsafePointer(to: &timeout) { pointer in
            Darwin.setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, pointer, size)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: in_addr_t(0x7F000001).bigEndian)

        let connectionResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard connectionResult == 0 else {
            let code = errno
            if code == ECONNREFUSED {
                throw ConnectionError.hostNotRunning
            }
            throw ConnectionError.connectionFailure(code)
        }

        var offset = 0
        while offset < request.count {
            let bytesSent = request.withUnsafeBytes { rawBuffer in
                Darwin.send(
                    socketFD,
                    rawBuffer.baseAddress!.advanced(by: offset),
                    request.count - offset,
                    0
                )
            }
            guard bytesSent > 0 else {
                throw ConnectionError.sendFailure(errno)
            }
            offset += bytesSent
        }

        var reply = Data()
        while reply.count <= BridgeWireProtocol.maxMessageBytes {
            var byte: UInt8 = 0
            let count = Darwin.recv(socketFD, &byte, 1, 0)
            if count == 0 {
                throw ConnectionError.incompleteReply
            }
            guard count > 0 else {
                throw ConnectionError.receiveFailure(errno)
            }
            if byte == 0x0A {
                return (messageLength, reply)
            }
            reply.append(byte)
        }
        throw BridgeProtocolError.oversizedMessage
    }
}
