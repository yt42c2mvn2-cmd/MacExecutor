# Rebilium

Rebilium is a native macOS **Luau editor and local script runner**, built with SwiftUI.

The Xcode project and executable target are still named MacExecutor internally to preserve the existing project configuration. The app's displayed name and window title are **Rebilium**.

## v0.5 fixes and features

- Purple-to-blue gradient for primary actions
- Modern geometric **R** logo in the sidebar
- Real macOS Tahoe Liquid Glass controls and a translucent dark workspace
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
6. Use **Settings** to review the Luau executable and the local script storage location.

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
