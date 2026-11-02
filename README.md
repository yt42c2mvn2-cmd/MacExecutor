# Rebilium

Rebilium is a native macOS **Luau editor and local script runner**, built with SwiftUI.

The Xcode project and executable target are still named MacExecutor internally to preserve the existing project configuration. The app's displayed name and window title are **Rebilium**.

## v1.2 — first permission-based Roblox Studio handshake

Rebilium now includes a **local Roblox Studio plugin**, installed only by the
user in their own Studio development environment. The separate Python backend
provides an HTTP endpoint on **127.0.0.1:37828**. Each time the host starts it
generates and prints a short-lived pairing token in Terminal.

After the user enters that token in the Studio plugin, Studio sends an
authenticated heartbeat over localhost every 10 seconds. Heartbeats expire
after 30 seconds. Rebilium queries the existing TCP diagnostic backend and
shows whether a recent paired Studio heartbeat was received at
**Settings → Native backend lab → Check Roblox Studio Connection**.

See the [Roblox Studio plugin setup](Experiments/RobloxStudioPlugin/README.md).
Existing ping diagnostics on TCP 127.0.0.1:37827 remain available.
macOS CI now verifies an end-to-end HTTP-to-TCP status roundtrip using the
same Swift networking client used in Rebilium.

**Important:** Studio integration is an opt-in authorized plugin using the
documented HttpService localhost feature. It is not Roblox Player injection,
nor does it receive, import, or execute user scripts. The handshake only
reports connection status. Script import will be a separate review/approval
feature.

## v1.1 — first real local interprocess connection

Rebilium now has a real **TCP ping/pong exchange** between the SwiftUI app and
a separately running diagnostic host in Terminal. This is not the older
in-memory self-test.

1. From the MacExecutor repository folder, run:
   `python3 Experiments/LoopbackHost/host.py`
2. Leave Terminal open and start Rebilium from Xcode.
3. Go to **Settings → Native backend lab → Ping Separate Test Host**.
4. Confirm **Connected to local test host** and the request/reply byte counts.
   The Terminal prints each request ID as it arrives.
5. Stop the host with **Control+C**, then ping again. Rebilium should show
   **Not connected — Test host not running**.

The host binds **127.0.0.1:37827 only** and requires Python 3; it accepts a
single versioned diagnostic ping, not arbitrary Luau or execute commands.
Rebilium uses a bounded direct TCP connection on a background task and verifies
the reply's version, action, marker, and request ID before reporting success.

The [host instructions](Experiments/LoopbackHost/README.md) also include
automated unit and end-to-end tests. CI runs these tests with a real Python
listener and a Swift probe compiled from the same client code used by Rebilium.

**Scope:** A local roundtrip demonstrates communication with our own process.
It does **not** connect to Roblox Player, provide script execution inside
Roblox, authenticate an independent peer, or modify any Roblox files.

## v1.0 prototype — native library and backend diagnostics

Rebilium now includes an isolated macOS native-library loading experiment at
[Experiments/InProcessHost](Experiments/InProcessHost/README.md).
An executable **we own** explicitly loads \`librebilium_bridge.dylib\` at
process launch and passes Luau source bytes to the library, which returns
validation metadata **without running the script**. The macOS CI job compiles
and tests this host, including invalid/oversized payloads.

A separate versioned Swift bridge protocol provides an in-memory ping/pong
roundtrip and strict version, reply, and size validation. Run the diagnostic
from **Settings → Native backend lab → Run Backend Self-Test**.

**Scope:** This is a proof of the app/native-library division seen in Delta's
iOS IPA, **not** a Roblox Player attachment or executor. The publicly shipped
macOS Roblox Player has not been modified, no port or anti-cheat bypass is
attempted, and the diagnostic performs no Roblox or network communication.

## v0.9 — deeper graphite, brighter icon gradients

Rebilium's **Dark** icon now has a near-black graphite/slate gradient closer to standard dark macOS icons, rather than a medium gray. The R stays legible with a bright silver-white gradient, while the square fitted into it uses stronger violet-to-blue saturation and a dark recessed socket. The **Light** variant has a richer purple-blue background and a more saturated inset square too. Both are generated from the same vector geometry, so the Dock and header logo stay consistent.

The icon preference remains **Settings → App icon appearance** (Automatic / Light / Dark). macOS may cache a previous Dock image: stop Rebilium, use **Product → Clean Build Folder** in Xcode, and run again if the previous colors persist.

## v0.8 — selectable Roblox installation and gradient icon variants

- Purple-to-blue gradient for primary actions
- Modern geometric **R** logo in the sidebar
- Real macOS Tahoe Liquid Glass controls and a translucent dark workspace
- **Custom Roblox installation location**: select a Player .app in Settings, validate its bundle ID, save the path, show the selected app in Finder, and return to automatic detection
- **Matched light and dark icons**: base R with a tilted square fitted into the bowl and a smaller inset square; vivid gradient for light, neutral graphite gradient with subtle violet-blue accents for dark
- **Icon appearance preference**: Automatic (follows macOS), Light, Dark; updates the Dock and the in-app badge
- **Read-only Roblox Client Check** in Settings: reports Player running, Player installed but not running, or not found
- Live status refresh on macOS app launch/quit notifications and a manual **Check Again** button
- Only observes Launch Services/NSWorkspace and validated app bundles; no communication, probing, hooking or memory access
- Explicit **Connection compatibility: Not tested** indicator so detection is never mistaken for a successful connection
- **Press-to-expand glass capsule**: the selected pill gently grows and glows while dragging, then springs to normal size when released
- **Uniform main page height**: Scripts, Discover, and Settings share one full-size outer glass panel
- **Matching in-app brand icon**: the header displays the same compiled AppIcon artwork as the Dock, replacing the old placeholder R
- **Directly draggable Liquid Glass navigation pill** for Scripts, Discover, and Settings; drag to move the highlight and release to spring-snap to the nearest page (clicking works too)
- **Seamless native macOS titlebar** with the standard red/yellow/green window controls, and app background extending beneath the titlebar
- Rebilium R/glass Dock icon generated into the macOS asset catalog during builds, declared in Info.plist, and explicitly applied to the running Dock tile
- Individual document tabs remain within the Scripts page
- Script sidebar with search, new, rename, duplicate and delete
- ScriptBlox trending and search using the public ScriptBlox API, script source preview, and manual import into the local library
- Visible ScriptBlox attribution, no automatic execution of downloaded code
- Local autosave to \`~/Library/Application Support/Rebilium/scripts.json\`
- Luau script editor, console and a 10-second run timeout
- Swift Testing coverage for persistence and tab behavior

## Running it

1. Open \`MacExecutor.xcodeproj\` in Xcode 26 or newer.
2. Choose the \`MacExecutor\` scheme and press **Cmd+R**.
3. Click **Choose Luau** and select the \`luau\` executable you built from [the official Luau project](https://github.com/luau-lang/luau).
4. Use **Scripts** to edit and run local Luau code.
5. Use **Discover** to search ScriptBlox, inspect the script source, and click **Import to Library**. Imported scripts open as local tabs; importing does not run them.
6. Use **Settings** to view **Roblox Client Check**, refresh the observed status, and review the Luau executable and local script storage location.

The executable path is remembered on your Mac. Script changes are saved automatically; closed tabs remain in the script library. Right-click a sidebar item to rename, duplicate or delete it.

## Safety and scope

**This is a local Luau script runner.** It does not attach to Roblox, inject into the Roblox client, or provide Roblox \`game\` / \`workspace\` APIs.

The Xcode target currently disables App Sandbox to launch a separately built Luau CLI. Only execute scripts you trust, and do not treat the local interpreter as a sandbox for hostile code. A distributable app should bundle and sandbox its runtime before release.

## ScriptBlox integration

The Discover panel uses ScriptBlox's documented `/api/script/trending`, `/api/script/search`, and `/api/script/:script` endpoints. Attribution: [Powered by ScriptBlox.com](https://scriptblox.com). No user API key is required for these public endpoints. External scripts can be unsafe and may depend on Roblox-specific APIs which the local Luau runtime does not provide. Read source before running anything.

## Design implementation

Rebilium's centered segmented navigation uses SwiftUI `matchedGeometryEffect` for one moving purple-blue selection capsule. To produce the macOS Dock icon, the Xcode target runs `Scripts/GenerateRebiliumIcon.swift` as a pre-build step and generates the PNGs listed in `AppIcon.appiconset/Contents.json`. The vector mark is a rendered implementation of the Rebilium sketch and glass-gradient design. Generated PNGs appear in the source asset catalog after a build and are not checked into Git.

## Dock icon troubleshooting

The runtime loads the compiled `AppIcon.icns` and applies it to the running Dock tile. The CI build also verifies that `MacExecutor.app/Contents/Resources/AppIcon.icns` is nonempty. If the old icon persists after you merge and pull this release, stop the app, choose **Product → Clean Build Folder** in Xcode (hold Option to reveal it if needed), and run again. A stale debug-app icon can survive previous builds because macOS caches application icons. Avoid resetting Dock preferences or deleting unrelated user data.

## UI consistency (v0.6)

The navigation capsule grows by 12 points in width and 6 points in height while held, remains centered under the pointer, and springs back on release. All three main pages share a common outer glass panel rather than each creating a separate page-sized background. The window header loads the compiled `AppIcon.icns` to match the Dock artwork, with a fallback only when running without bundled assets.


## Roblox Client Check — observation only

Open **Settings → Roblox Client Check** to see whether the macOS Roblox Player is running or installed. The header shows the last observed presence state; Settings displays the application path, bundle ID, and process ID when available.

The check uses Apple's \`NSRunningApplication.runningApplications(withBundleIdentifier:)\`, \`NSWorkspace.urlForApplication(withBundleIdentifier:)\`, and local bundle metadata. It recognizes the Player identifier \`com.roblox.RobloxPlayer\`; Roblox Studio has a different identifier and does not count. It also examines Roblox's documented macOS application locations as a fallback. Status automatically refreshes on macOS app launch/quit and can be manually refreshed.

**Connection readiness is unknown.** Detecting a running application does not show whether Roblox offers a usable/authorized API or that a connection would be possible. Rebilium does not send requests to Roblox, open a socket or port, attach to a process, read/write Roblox memory, run injection code, or alter the Roblox application. This release intentionally makes no attempt to establish communication.


## Custom Roblox installation location (v0.8)

Open **Settings → Roblox Client Check → Choose Roblox.app…** and pick the macOS Player application bundle. Rebilium accepts the outer Roblox.app wrapper or an inner Contents/MacOS/Roblox.app bundle, but requires the exact \`com.roblox.RobloxPlayer\` bundle identifier. Roblox Studio will be rejected. Your chosen path is saved in app preferences and retained between launches. **Use Automatic** clears the override.

When you select a custom location, the **Running** indicator is scoped to that installation: a different Player instance running from another folder won't be reported as the selected installation. Moving or deleting a selected installation triggers a validation warning. This remains a passive presence check, never a process connection.

## Rebilium icon appearance (v0.8)

The vector icon generator creates identical geometric R/insert silhouettes for the light and graphite-dark variants. Light PNG sizes are bundled in AppIcon.appiconset; full-resolution light/dark assets are also bundled as RebiliumLightIcon and RebiliumDarkIcon for the Dock and header. Choose **Automatic**, **Light** or **Dark** in Settings; Automatic follows the macOS-wide appearance (not the always-dark code editor theme). Restart or re-focus Rebilium after changing the macOS system appearance to refresh the icon if needed.
