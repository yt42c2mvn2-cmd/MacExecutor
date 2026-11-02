import Foundation

// Standalone Swift probe compiled against the exact same transport and JSON
// protocol as Rebilium, so CI covers the real app-side networking code.
guard CommandLine.arguments.count == 2,
      let port = UInt16(CommandLine.arguments[1]) else {
    fatalError("Usage: RebiliumLoopbackProbe <test-port>")
}

do {
    let result = try LocalBridgeClient.ping(port: port)
    guard result.requestBytes > 0, result.responseBytes > 0 else {
        fatalError("No bytes transferred")
    }
    print("Real IPC ping/pong passed: \(result.requestBytes) request bytes, \(result.responseBytes) response bytes")
} catch {
    fputs("Real IPC failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
