import SwiftUI

/// Discover scripts from ScriptBlox. Import is explicit and never runs the source.
struct ScriptBloxDiscoveryView: View {
    let onImport: (String, String) -> Void

    @State private var searchText = ""
    @State private var scripts: [ScriptBloxEntry] = []
    @State private var selectedID: String?
    @State private var selectedSource: String?
    @State private var isLoading = false
    @State private var isLoadingSource = false
    @State private var errorMessage: String?
    @State private var sourceError: String?
    @State private var showingSearchResults = false
    @State private var requestID = UUID()

    private var selected: ScriptBloxEntry? {
        scripts.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover scripts")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Explore ScriptBlox, preview source, then save it to your library.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Link(destination: URL(string: "https://scriptblox.com")!) {
                    Label("Powered by ScriptBlox.com", systemImage: "arrow.up.right")
                        .font(.system(size: 11))
                }
                .foregroundStyle(RebiliumStyle.blue)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("Search games or scripts…", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await search() } }
                        .accessibilityIdentifier("scriptBloxSearch")
                }
                .padding(.horizontal, 13)
                .frame(height: 39)
                .glassEffect(.regular, in: Capsule())

                Button("Search") { Task { await search() } }
                    .buttonStyle(RebiliumGradientButtonStyle())
                    .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

                Button {
                    Task { await loadTrending() }
                } label: {
                    Label("Trending", systemImage: "flame")
                }
                .buttonStyle(.glass)
                .disabled(isLoading)
            }

            HStack(spacing: 14) {
                listPanel.frame(minWidth: 260, idealWidth: 325, maxWidth: 375)
                previewPanel.frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            Label(
                "Remote scripts are untrusted. Importing does not execute them. Roblox-specific APIs are unavailable in the local Luau runner.",
                systemImage: "exclamationmark.shield"
            )
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.57))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .task {
            if scripts.isEmpty { await loadTrending() }
        }
    }

    private var listPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(showingSearchResults ? "SEARCH RESULTS" : "TRENDING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
                else {
                    Text("\(scripts.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(15)

            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

            if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.title2)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            if showingSearchResults { await search() }
                            else { await loadTrending() }
                        }
                    }
                    .buttonStyle(.glass)
                }
                .foregroundStyle(.white.opacity(0.8))
                .font(.caption)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scripts.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No scripts found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Try a different search.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(scripts) { script in
                            Button {
                                Task { await preview(script) }
                            } label: {
                                scriptRow(script)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("scriptBloxResult-\(script.id)")
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19))
        .overlay {
            RoundedRectangle(cornerRadius: 19)
                .strokeBorder(.white.opacity(0.10))
        }
    }

    private func scriptRow(_ item: ScriptBloxEntry) -> some View {
        let active = item.id == selectedID
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if item.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(RebiliumStyle.blue)
                }
                Spacer(minLength: 0)
            }

            Text(item.game?.name ?? "Universal / Unspecified")
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 8) {
                Label(item.views.formatted(.number.notation(.compactName)), systemImage: "eye")
                if item.key { Label("Key", systemImage: "key") }
                if item.isPatched { Label("Patched", systemImage: "exclamationmark.triangle") }
            }
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.45))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            active ? RebiliumStyle.violet.opacity(0.23) : .white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selected {
                HStack(spacing: 9) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(RebiliumStyle.violet)
                    Text(selected.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 10)
                    if isLoadingSource { ProgressView().controlSize(.small) }

                    Button {
                        if let selectedSource {
                            onImport(selected.title, selectedSource)
                        }
                    } label: {
                        Label("Import to Library", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(RebiliumGradientButtonStyle())
                    .disabled(selectedSource == nil || isLoadingSource)
                    .accessibilityIdentifier("importScriptBloxButton")
                }
                .padding(14)

                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

                if let sourceError {
                    ContentUnavailableView(
                        "Preview unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(sourceError)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let selectedSource {
                    ScrollView([.vertical, .horizontal]) {
                        Text(selectedSource)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(15)
                    }
                    .accessibilityIdentifier("scriptBloxPreview")
                } else {
                    ProgressView("Loading script source…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 13) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(RebiliumStyle.violet)
                    Text("Select a script")
                        .font(.title3.bold())
                    Text("Preview source before importing it to your library.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19))
        .overlay {
            RoundedRectangle(cornerRadius: 19)
                .strokeBorder(.white.opacity(0.10))
        }
    }

    private func loadTrending() async {
        let id = UUID()
        requestID = id
        isLoading = true
        showingSearchResults = false
        errorMessage = nil
        do {
            let response = try await ScriptBloxService.trending()
            guard requestID == id else { return }
            scripts = response
            selectedID = nil
            selectedSource = nil
        } catch {
            guard requestID == id else { return }
            scripts = []
            errorMessage = error.localizedDescription
        }
        if requestID == id { isLoading = false }
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let id = UUID()
        requestID = id
        isLoading = true
        showingSearchResults = true
        errorMessage = nil
        do {
            let response = try await ScriptBloxService.search(query)
            guard requestID == id else { return }
            scripts = response
            selectedID = nil
            selectedSource = nil
        } catch {
            guard requestID == id else { return }
            scripts = []
            errorMessage = error.localizedDescription
        }
        if requestID == id { isLoading = false }
    }

    private func preview(_ script: ScriptBloxEntry) async {
        selectedID = script.id
        selectedSource = nil
        sourceError = nil
        isLoadingSource = true
        do {
            let text = try await ScriptBloxService.source(for: script)
            guard selectedID == script.id else { return }
            selectedSource = text
        } catch {
            guard selectedID == script.id else { return }
            sourceError = error.localizedDescription
        }
        if selectedID == script.id { isLoadingSource = false }
    }
}
