# MacExecutor

An experimental native macOS SwiftUI app for running **local Luau scripts**.

## First prototype

- Script editor and clear button
- Execute using the separately compiled Luau command-line interpreter
- Console output and error messages
- Choose the Luau executable via a file picker (path saved locally)
- 10-second execution timeout
- Intel macOS support (matching the locally compiled CLI)

## Run

1. Build the Luau CLI from https://github.com/luau-lang/luau:
   `make config=release luau`
2. Open `MacExecutor.xcodeproj` in Xcode.
3. Build and run the **MacExecutor** target.
4. If needed, click **Choose Luau…** and select `build/release/luau` from your Luau checkout.
5. Edit the sample script and click **Execute**.

The app uses your local Luau executable; it does **not** embed Luau or run scripts inside Roblox. Roblox services such as `game` and `workspace` are unavailable. This initial prototype disables App Sandbox to run a selected local executable: do not run untrusted scripts, and do not distribute it as a hardened/sandboxed release.

## Development

This branch is an unverified initial implementation. Build and test on macOS using Xcode. The current UI is intentionally simple; future work can add script storage and unit/UI tests.
