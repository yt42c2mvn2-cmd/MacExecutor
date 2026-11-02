import Foundation

/// Runs a script with a separately installed Luau CLI.
/// This does not attach to or modify the Roblox process.
enum LuauRunner {
    nonisolated static func run(source: String, executableURL: URL) -> String {
        let fileManager = FileManager.default

        guard fileManager.isExecutableFile(atPath: executableURL.path) else {
            return """
            Luau executable not found:
            \(executableURL.path)

            Click 'Choose Luau' and select the 'luau' binary you built.
            """
        }

        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("MacExecutor-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            defer { try? fileManager.removeItem(at: directory) }

            let scriptURL = directory.appendingPathComponent("script.luau")
            let outputURL = directory.appendingPathComponent("output.txt")
            try source.write(to: scriptURL, atomically: true, encoding: .utf8)

            guard fileManager.createFile(atPath: outputURL.path, contents: nil) else {
                return "Could not create a temporary output file."
            }
            let outputHandle = try FileHandle(forWritingTo: outputURL)
            defer { try? outputHandle.close() }

            let process = Process()
            process.executableURL = executableURL
            process.arguments = [scriptURL.path]
            process.currentDirectoryURL = directory
            process.standardOutput = outputHandle
            process.standardError = outputHandle

            try process.run()

            // Keep accidental infinite loops from freezing an execution forever.
            let deadline = Date().addingTimeInterval(10)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }

            let didTimeOut = process.isRunning
            if didTimeOut {
                process.terminate()
            }
            process.waitUntilExit()
            try outputHandle.synchronize()

            let output = try String(contentsOf: outputURL, encoding: .utf8)
                .trimmingCharacters(in: .newlines)

            if didTimeOut {
                return output.isEmpty
                    ? "Execution stopped after 10 seconds (timeout)."
                    : output + "\n\nExecution stopped after 10 seconds (timeout)."
            }

            if process.terminationStatus != 0 {
                return output.isEmpty
                    ? "Luau exited with code \(process.terminationStatus)."
                    : output + "\n\nExit code: \(process.terminationStatus)"
            }

            return output.isEmpty ? "Script finished (no output)." : output
        } catch {
            return "Execution error: \(error.localizedDescription)"
        }
    }
}
