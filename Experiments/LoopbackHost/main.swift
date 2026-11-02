import Foundation

// Standalone probe compiled with Rebilium's production client code.
// Calls a live Python process over TCP, not an in-memory mock.
guard CommandLine.arguments.count >= 2,
      let port = UInt16(CommandLine.arguments[1]) else {
    fatalError("Usage: RebiliumLoopbackProbe <port> [studio:offline|studio:online]")
}

do {
    let ping = try LocalBridgeClient.ping(port: port)
    guard ping.requestBytes > 0, ping.responseBytes > 0 else {
        fatalError("No bytes transferred")
    }
    print("Live ping/pong passed: \(ping.requestBytes) request bytes, \(ping.responseBytes) reply bytes")

    if CommandLine.arguments.count == 3 {
        let expectedOnline: Bool
        switch CommandLine.arguments[2] {
        case "studio:offline": expectedOnline = false
        case "studio:online": expectedOnline = true
        default: fatalError("Unknown expected Studio state")
        }

        let online = try LocalBridgeClient.studioIsConnected(port: port)
        guard online == expectedOnline else {
            fatalError("Studio state mismatch: expected \(expectedOnline), actual \(online)")
        }
        print("Verified Studio heartbeat status: \(online ? "connected" : "not connected")")
    }
} catch {
    fputs("Real IPC failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
