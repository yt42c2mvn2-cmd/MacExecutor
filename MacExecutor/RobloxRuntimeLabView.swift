import SwiftUI
import AppKit

/// Safe staging for on-disk research with the actual installed Player.
struct RobloxRuntimeLabView: View {
    @ObservedObject var inspector: RobloxClientInspector

    @State private var isPreparing = false
    @State private var confirmationVisible = false
    @State private var currentManifest: RobloxRuntimeMethod.Manifest?
    @State private var status = "No isolated Player workspace prepared."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 18))
                    .foregroundStyle(RebiliumStyle.violet)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Roblox Player Runtime Lab")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Real Player binary · isolated signed working copy")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }

            Text("Rebilium will copy the actual installed x86_64 Roblox Player into your Application Support folder, verify the original and copy's signatures, and compare their executable SHA-256 hashes. Your installed Roblox.app stays untouched.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Text("The first workspace is intentionally unmodified and is not launched. Code signing and Roblox integrity checks remain in effect; this does not enable injection or make third-party libraries loadable.")
                .font(.system(size: 11))
                .foregroundStyle(.orange.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button {
                    confirmationVisible = true
                } label: {
                    Label("Prepare Isolated Player Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.glass)
                .disabled(isPreparing || inspector.snapshot.applicationURL == nil)
                .accessibilityIdentifier("prepareRobloxRuntimeCopyButton")

                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .confirmationDialog(
                "Prepare a separate, unmodified Roblox Player copy?",
                isPresented: $confirmationVisible
            ) {
                Button("Copy and Verify Player") {
                    prepare()
                }
            } message: {
                Text("This can consume substantial disk space. Rebilium will not launch, patch, re-sign, or inject into Roblox Player.")
            }

            Text(status)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.76))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("playerRuntimeCopyStatus")

            if let currentManifest {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Pristine working copy verified", systemImage: "checkmark.shield")
                        .foregroundStyle(RebiliumStyle.blue)
                        .font(.system(size: 12, weight: .semibold))

                    Text(currentManifest.workingBundlePath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .textSelection(.enabled)

                    Text("SHA-256: \(currentManifest.workingExecutableSHA256)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.60))
                        .textSelection(.enabled)

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([
                            URL(fileURLWithPath: currentManifest.workingBundlePath)
                        ])
                    } label: {
                        Label("Reveal Working Copy", systemImage: "folder")
                    }
                    .buttonStyle(.glass)
                }
                .padding(12)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 17))
    }

    private func prepare() {
        guard let original = inspector.snapshot.applicationURL else {
            status = "Roblox Player not found. Run Roblox Client Check first."
            return
        }
        isPreparing = true
        status = "Copying the real Player and validating integrity…"
        Task {
            do {
                let manifest = try await Task.detached(priority: .userInitiated) {
                    try RobloxRuntimeMethod.prepare(source: original)
                }.value
                currentManifest = manifest
                status = "Working copy prepared and verified. Not modified or launched."
            } catch {
                status = "Cannot prepare working copy: \(error.localizedDescription)"
            }
            isPreparing = false
        }
    }
}
