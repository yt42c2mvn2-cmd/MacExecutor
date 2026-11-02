# Rebilium

Rebilium is a native macOS **Luau editor and local script runner**, built with SwiftUI.

The Xcode project and executable target are still named MacExecutor internally to preserve the existing project configuration. The app's displayed name and window title are **Rebilium**.

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
