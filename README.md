# Rebilium

Rebilium is a native macOS **Luau editor and local script runner**, built with SwiftUI.

The Xcode project and executable target are still named MacExecutor internally to preserve the existing project configuration. The app's displayed name and window title are **Rebilium**.

## v0.2 features

- Purple-to-blue gradient for primary actions
- Modern geometric **R** logo in the sidebar
- Real macOS Tahoe Liquid Glass controls and a translucent dark workspace
- **Top tabs** for multiple open scripts
- Script sidebar with search, new, rename, duplicate and delete
- Local autosave to \`~/Library/Application Support/Rebilium/scripts.json\`
- Luau script editor, console and a 10-second run timeout
- Swift Testing coverage for persistence and tab behavior

## Running it

1. Open \`MacExecutor.xcodeproj\` in Xcode 26 or newer.
2. Choose the \`MacExecutor\` scheme and press **Cmd+R**.
3. Click **Choose Luau** and select the \`luau\` executable you built from [the official Luau project](https://github.com/luau-lang/luau).
4. Enter or edit your script, then click **Run Script**.

The executable path is remembered on your Mac. Script changes are saved automatically; closed tabs remain in the script library. Right-click a sidebar item to rename, duplicate or delete it.

## Safety and scope

**This is a local Luau script runner.** It does not attach to Roblox, inject into the Roblox client, or provide Roblox \`game\` / \`workspace\` APIs.

The Xcode target currently disables App Sandbox to launch a separately built Luau CLI. Only execute scripts you trust, and do not treat the local interpreter as a sandbox for hostile code. A distributable app should bundle and sandbox its runtime before release.
