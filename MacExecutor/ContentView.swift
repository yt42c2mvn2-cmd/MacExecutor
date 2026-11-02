import SwiftUI
import AppKit

private enum RebiliumPage: String, CaseIterable, Identifiable {
    case scripts = "Scripts"
    case discover = "Discover"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .scripts: "curlybraces"
        case .discover: "sparkle.magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @StateObject private var library = ScriptLibrary()
    @StateObject private var robloxInspector = RobloxClientInspector()
    @State private var currentPage: RebiliumPage = .scripts
    // Track the capsule continuously while the pointer is held down.
    @State private var navigationDragOffset: CGFloat?
    @State private var navigationGrabOffset: CGFloat?
    @State private var navigationIsHeld = false
    private let navigationSegmentWidth: CGFloat = 132
    private let navigationPadding: CGFloat = 5
    @AppStorage("luauExecutablePath") private var executablePath = ""

    @State private var searchText = ""
    @State private var consoleOutput = "Ready. Select your Luau executable, then run a script."
    @State private var isRunning = false
    @State private var isRenaming = false
    @State private var renameID: UUID?
    @State private var renameText = ""

    private var defaultLuauPath: String {
        NSString(string: "~/Projects/MacExecutor/luau/build/release/luau")
            .expandingTildeInPath
    }

    private var selectedLuauPath: String {
        executablePath.isEmpty ? defaultLuauPath : executablePath
    }

    private var filteredScripts: [SavedScript] {
        guard !searchText.isEmpty else { return library.scripts }
        return library.scripts.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            RebiliumStyle.background.ignoresSafeArea()

            RadialGradient(
                colors: [RebiliumStyle.violet.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 15,
                endRadius: 690
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            RadialGradient(
                colors: [RebiliumStyle.blue.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 570
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 16) {
                primaryNavigation
                currentPageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(18)
            // Leave the native close/minimize/zoom controls unobstructed
            // while the background extends seamlessly behind them.
            .padding(.top, 28)
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 930, minHeight: 630)
        .onAppear {
            robloxInspector.refresh()
        }
        // macOS sends these events even when Rebilium is not the frontmost app.
        // We only re-read the public application list; we never contact Roblox.
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didLaunchApplicationNotification
            )
        ) { _ in
            robloxInspector.refresh()
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didTerminateApplicationNotification
            )
        ) { _ in
            robloxInspector.refresh()
        }
        .alert("Rename Script", isPresented: $isRenaming) {
            TextField("Script name", text: $renameText)
            Button("Rename") {
                if let id = renameID { library.rename(id, to: renameText) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a name for this script.")
        }
    }

    private var selectedNavigationIndex: Int {
        RebiliumPage.allCases.firstIndex(of: currentPage) ?? 0
    }

    private var navigationOffset: CGFloat {
        navigationDragOffset ?? CGFloat(selectedNavigationIndex) * navigationSegmentWidth
    }

    private var primaryNavigation: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                RebiliumMark(size: 43)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rebilium")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                    Text("LUAU STUDIO")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // The selected capsule is one real draggable object rather than
            // three separate backgrounds that happen to animate between tabs.
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.025))

                Capsule()
                    .fill(RebiliumStyle.gradient.opacity(0.33))
                    .glassEffect(
                        .regular.tint(RebiliumStyle.violet.opacity(0.18)).interactive(),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.32), lineWidth: 1)
                    }
                    .shadow(
                        color: RebiliumStyle.violet.opacity(navigationIsHeld ? 0.47 : 0.29),
                        radius: navigationIsHeld ? 15 : 9,
                        y: navigationIsHeld ? 5 : 3
                    )
                    // A gentle "picked up" expansion while held.
                    .frame(
                        width: navigationSegmentWidth + (navigationIsHeld ? 12 : 0),
                        height: navigationIsHeld ? 45 : 39
                    )
                    .animation(
                        .spring(response: 0.23, dampingFraction: 0.68),
                        value: navigationIsHeld
                    )
                    // Expand equally around the capsule's current center.
                    .offset(
                        x: navigationPadding + navigationOffset
                            - (navigationIsHeld ? 6 : 0)
                    )
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    ForEach(RebiliumPage.allCases) { page in
                        let active = currentPage == page

                        Button {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                currentPage = page
                                navigationDragOffset = nil
                                navigationGrabOffset = nil
                                navigationIsHeld = false
                            }
                        } label: {
                            Label(page.rawValue, systemImage: page.symbol)
                                .font(.system(size: 13, weight: active ? .semibold : .medium))
                                .foregroundStyle(active ? .white : .white.opacity(0.75))
                                .frame(width: navigationSegmentWidth, height: 39)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("navigation-\(page.rawValue)")
                    }
                }
                .padding(navigationPadding)
            }
            .frame(
                width: navigationPadding * 2
                    + navigationSegmentWidth * CGFloat(RebiliumPage.allCases.count),
                height: 49
            )
            .glassEffect(.regular, in: Capsule())
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        // Save the initial grab position so the pill does not
                        // jump when someone drags it from an edge.
                        if navigationGrabOffset == nil {
                            let center = navigationPadding
                                + (CGFloat(selectedNavigationIndex) + 0.5)
                                * navigationSegmentWidth
                            navigationGrabOffset = value.startLocation.x - center
                            withAnimation(.spring(response: 0.23, dampingFraction: 0.68)) {
                                navigationIsHeld = true
                            }
                        }

                        let pointerCenter = value.location.x - (navigationGrabOffset ?? 0)
                        let proposedOffset = pointerCenter
                            - navigationPadding - navigationSegmentWidth / 2
                        let maximumOffset = navigationSegmentWidth
                            * CGFloat(RebiliumPage.allCases.count - 1)

                        // No animation during the drag: follow the pointer.
                        navigationDragOffset = min(max(proposedOffset, 0), maximumOffset)
                    }
                    .onEnded { _ in
                        let index = Int(
                            (navigationOffset / navigationSegmentWidth).rounded()
                        )
                        let snapped = min(
                            max(index, 0),
                            RebiliumPage.allCases.count - 1
                        )

                        // The glass capsule springs to the nearest destination
                        // and the page only changes when it is released.
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                            currentPage = RebiliumPage.allCases[snapped]
                            navigationDragOffset = nil
                            navigationGrabOffset = nil
                            navigationIsHeld = false
                        }
                    }
            )
            .accessibilityHint("Click a page or drag the highlighted glass tab horizontally to switch pages.")

            HStack(spacing: 6) {
                Circle()
                    .fill(
                        robloxInspector.snapshot.presence == .running
                            ? RebiliumStyle.blue
                            : .white.opacity(0.4)
                    )
                    .frame(width: 7, height: 7)
                Text(robloxInspector.snapshot.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.63))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .help("Roblox presence only. No connection has been attempted.")
        }
        .padding(.horizontal, 5)
    }

    /// All main destinations share this one flexible glass canvas. Keeping
    /// the outer panel outside the switch avoids differing page heights.
    private var currentPageContent: some View {
        ZStack(alignment: .topLeading) {
            switch currentPage {
            case .scripts:
                scriptsWorkspace
            case .discover:
                ScriptBloxDiscoveryView { title, source in
                    library.importScript(title: title, source: source)
                    currentPage = .scripts
                    consoleOutput = "Imported “\(title)” into your library. Review before running."
                }
            case .settings:
                settingsPage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(15)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 27))
    }

    private var scriptsWorkspace: some View {
        HStack(alignment: .top, spacing: 14) {
            sidebar.frame(width: 230)

            VStack(alignment: .leading, spacing: 14) {
                header
                tabStrip
                editor
                console
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("Configure Rebilium and inspect local Roblox Player presence.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))

                RobloxClientCheckView(inspector: robloxInspector)

                VStack(alignment: .leading, spacing: 13) {
                    Label("Luau interpreter", systemImage: "terminal")
                        .font(.headline)

                    Text("Choose the executable you built from the official Luau project.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(selectedLuauPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .textSelection(.enabled)

                    Button(action: chooseLuau) {
                        Label("Choose Luau executable", systemImage: "folder")
                    }
                    .buttonStyle(RebiliumGradientButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 17))

                VStack(alignment: .leading, spacing: 10) {
                    Label("Local script storage", systemImage: "externaldrive")
                        .font(.headline)
                    Text("Scripts are autosaved as JSON in your Application Support directory.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("~/Library/Application Support/Rebilium/scripts.json")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .textSelection(.enabled)
                    Text("\(library.scripts.count) saved scripts")
                        .font(.caption)
                        .foregroundStyle(RebiliumStyle.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 17))

                Text("ScriptBlox imports source for review only. Scripts are not executed until you choose to run them. Roblox-specific APIs are not available in the standalone Luau runner.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(25)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                _ = library.createScript()
            } label: {
                Label("New Script", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RebiliumGradientButtonStyle())
            .accessibilityIdentifier("newScriptButton")

            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR LIBRARY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.1)
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("Search scripts", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .accessibilityIdentifier("searchScriptsField")
                }
                .padding(10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredScripts) { script in
                            sidebarRow(script)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("Autosaved locally", systemImage: "checkmark.icloud")
                    .foregroundStyle(.white.opacity(0.65))
                Label("Independent Luau runtime", systemImage: "cpu")
                    .foregroundStyle(.white.opacity(0.65))
            }
            .font(.system(size: 11))

            if let storageError = library.storageError {
                Text(storageError)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .frame(maxHeight: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
    }

    private func sidebarRow(_ script: SavedScript) -> some View {
        let active = library.selectedID == script.id

        return Button {
            library.select(script.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? RebiliumStyle.violet : .white.opacity(0.55))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(script.title)
                        .font(.system(size: 12, weight: active ? .semibold : .medium))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    Text("Luau script")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: 0)
                if active {
                    Circle()
                        .fill(RebiliumStyle.blue)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .background(
                active ? RebiliumStyle.violet.opacity(0.22) : Color.white.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename…") { startRename(script) }
            Button("Duplicate") { library.duplicate(script.id) }
            Divider()
            Button("Delete", role: .destructive) { library.delete(script.id) }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Workspace")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Create, test, and organize Luau scripts.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 10)

            Button(action: chooseLuau) {
                Label("Choose Luau", systemImage: "folder")
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("chooseLuauButton")

            Button(action: execute) {
                Label(isRunning ? "Running…" : "Run Script", systemImage: "play.fill")
            }
            .buttonStyle(RebiliumGradientButtonStyle())
            .disabled(
                isRunning ||
                (library.selectedScript?.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            )
            .accessibilityIdentifier("executeButton")
        }
    }

    private var tabStrip: some View {
        GlassEffectContainer(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(library.openScripts) { script in
                        let active = library.selectedID == script.id

                        HStack(spacing: 5) {
                            Button {
                                library.select(script.id)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                    Text(script.title)
                                        .font(.system(size: 12, weight: active ? .semibold : .regular))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(.white.opacity(active ? 1 : 0.70))
                            }
                            .buttonStyle(.plain)

                            Button {
                                library.closeTab(script.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .help("Close tab")
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 35)
                        .background(
                            active ? RebiliumStyle.violet.opacity(0.28) : .clear,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        _ = library.createScript()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 35, height: 35)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    .help("New tab")
                }
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(RebiliumStyle.violet)
                    .frame(width: 7, height: 7)
                Text(library.selectedScript?.title ?? "Script")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                Spacer()
                Button {
                    if let script = library.selectedScript { startRename(script) }
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.6))
                .help("Rename selected script")
                Text("LUAU")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(RebiliumStyle.violet)
                    .padding(.leading, 7)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 13)

            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(height: 1)

            TextEditor(text: Binding(
                get: { library.selectedScript?.source ?? "" },
                set: { library.updateSource($0) }
            ))
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.91))
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("scriptEditor")
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
        .frame(minHeight: 230)
    }

    private var console: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "terminal")
                    .foregroundStyle(RebiliumStyle.blue)
                Text("Output")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if isRunning { ProgressView().controlSize(.small) }
                Text("LOCAL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.47))
                Button {
                    consoleOutput = ""
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.glass)
                .help("Clear output")
                .accessibilityIdentifier("clearOutputButton")
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)

            ScrollView {
                Text(consoleOutput)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.80))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(14)
                    .accessibilityIdentifier("consoleOutput")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19))
        .overlay {
            RoundedRectangle(cornerRadius: 19)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
        .frame(height: 185)
    }

    private func startRename(_ script: SavedScript) {
        renameID = script.id
        renameText = script.title
        isRenaming = true
    }

    private func chooseLuau() {
        let panel = NSOpenPanel()
        panel.title = "Select your Luau executable"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            executablePath = url.path
            consoleOutput = "Selected \(url.lastPathComponent). Ready."
        }
    }

    private func execute() {
        guard let source = library.selectedScript?.source, !isRunning else { return }
        isRunning = true
        consoleOutput = "Running…"
        let path = selectedLuauPath

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                LuauRunner.run(source: source, executableURL: URL(fileURLWithPath: path))
            }.value
            consoleOutput = result
            isRunning = false
        }
    }
}

#Preview {
    ContentView()
}
