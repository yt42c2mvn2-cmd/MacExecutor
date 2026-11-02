import SwiftUI
import AppKit

struct ContentView: View {
    @AppStorage("luauExecutablePath") private var executablePath = ""
    @State private var script = """
    print("Hello from MacExecutor!")
    print("Luau is working!")
    """
    @State private var output = "Ready. Choose your Luau executable to start."
    @State private var running = false

    private var defaultPath: String {
        NSString(string: "~/Projects/MacExecutor/luau/build/release/luau")
            .expandingTildeInPath
    }

    private var selectedPath: String {
        executablePath.isEmpty ? defaultPath : executablePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.title2)
                    .foregroundStyle(.purple)
                Text("MacExecutor")
                    .font(.title2.bold())
                Spacer()
                Label("Local Luau", systemImage: "terminal")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: "shippingbox")
                    .foregroundStyle(.secondary)
                Text(selectedPath)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(selectedPath)
                Spacer()
                Button("Choose Luau…", action: chooseLuau)
                    .accessibilityIdentifier("chooseLuauButton")
            }

            Text("Script")
                .font(.headline)
            TextEditor(text: $script)
                .font(.system(size: 14, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 210)
                .accessibilityIdentifier("scriptEditor")

            HStack {
                Button {
                    execute()
                } label: {
                    Label(running ? "Running…" : "Execute", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(running || script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("executeButton")

                Button("Clear Script") { script = "" }
                    .disabled(running)
                Spacer()
                if running { ProgressView().controlSize(.small) }
                Text("Runs locally, not inside Roblox")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Console").font(.headline)
                Spacer()
                Button("Clear Output") { output = "" }
                    .accessibilityIdentifier("clearOutputButton")
            }
            ScrollView {
                Text(output)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
                    .accessibilityIdentifier("consoleOutput")
            }
            .frame(minHeight: 120)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(18)
        .frame(minWidth: 700, minHeight: 520)
    }

    private func chooseLuau() {
        let panel = NSOpenPanel()
        panel.title = "Select the Luau executable"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            executablePath = url.path
            output = "Selected \(url.lastPathComponent). Ready."
        }
    }

    private func execute() {
        running = true
        output = "Running…"
        let code = script
        let path = selectedPath

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                LuauRunner.run(source: code, executableURL: URL(fileURLWithPath: path))
            }.value
            output = result
            running = false
        }
    }
}

#Preview {
    ContentView()
}
