# Actual macOS Roblox Player — read-only feasibility inventory

This experiment inspects the **Roblox Player installed on your Mac**, not Roblox Studio, Delta's IPA, or our synthetic test host.

To run it from your MacExecutor repository root:

    bash Experiments/RobloxPlayerInspection/inspect.sh

If Roblox is in a nonstandard location, specify the actual bundle:

    bash Experiments/RobloxPlayerInspection/inspect.sh "/Applications/Roblox.app"

The script recognizes the Player bundle identifier `com.roblox.RobloxPlayer`, including Roblox's common nested `Contents/MacOS/Roblox.app` wrapper.

It reports the current executable's **CPU architecture**, **code-signing and hardened-runtime metadata**, **declared entitlements**, **signature verification**, and **existing linked libraries**. These are the first facts needed to assess whether there is a documented extension point on *this specific macOS Player build*.

The report does **not** prove that third-party libraries can load into Player, that a Luau VM interface is accessible, or that altering the process would go unnoticed. Roblox's modified-client policies and Apple's runtime protections still apply.

This audit does **not** connect to a running process, read memory, disable SIP, alter app signing, patch the app bundle, or inject any code. Run it with Roblox closed. The app's absolute installation path appears in the output; review it before sharing.

Once we have this report, we can compare actual macOS architecture and security constraints against the *load-at-startup* structure found in the Delta IPA, then choose a concrete, authorized research path. Avoid promising stealth or runtime execution without evidence.
