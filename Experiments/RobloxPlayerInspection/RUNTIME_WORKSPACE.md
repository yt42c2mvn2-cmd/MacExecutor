# Real macOS Roblox Player working-copy method

This is a **method object** running inside Rebilium that works with the actual
installed `com.roblox.RobloxPlayer` app, rather than a simulated game process.

## Why not modify the runtime yet?

The user's 23 October 2026 signed x86_64 Roblox Player reports Hardened
Runtime (`flags=0x10000(runtime)`) and an Apple Developer ID signing
identity. Its listed entitlements include
`com.apple.security.cs.disable-executable-page-protection`, **not**
`com.apple.security.cs.disable-library-validation`.

Those are distinct privileges. A binary copy alone does not authorize
loading an independent third-party dylib, and changing the executable
invalidates its Roblox Corporation signature. No working modified client or
anti-cheat-compatible injection method is implied by this experiment.

## Implemented

The `RobloxRuntimeMethod` type:

- Verifies the selected bundle identifier and x86_64 Mach-O header.
- Uses macOS `codesign --verify --verbose=2` on the **original** bundle.
- Creates an isolated per-session directory under:
  `~/Library/Application Support/Rebilium/PlayerRuntimeWorkspaces/`
- Copies **the entire signed Player bundle** to a new workspace (including
  its nested apps/frameworks), without changing the original.
- Computes SHA-256 hashes of both executables and requires them to match.
- Re-verifies the copied app's code signature.
- Writes a JSON manifest **outside Roblox.app** showing source/working
  paths, hash, method version, and `modified:false`, `launched:false`.
- Deletes a failed workspace if copying, hashing, or signing checks fail.

Nothing is patched, re-signed, launched, injected, attached, or sent over a
network. This is an isolated signed working-copy baseline to guide research.
A workspace is not a VM and does not itself sandbox any future execution.

## Try it

1. In Rebilium, choose **Settings → Roblox Client Check** and confirm the
   actual Player installation is recognized.
2. Open **Roblox Player Runtime Lab** below the Client Check.
3. Select **Prepare Isolated Player Copy**, then confirm the disk use.
4. Rebilium copies and verifies the app off the UI thread; the original
   remains untouched.
5. After success, select **Reveal Working Copy** to inspect its folder.
   The sibling `manifest.json` lists the verified digest and state.

This may consume substantial disk space. To clear old copies, remove
individual `Workspace-...` directories from the folder above while Rebilium
and Roblox are closed.

## Next engineering decision

Use the actual audit and verified baseline to evaluate whether Roblox
exposes a *documented* and authorized extension route. If not, continue
native integration research on a host that we own, where signing and library
loading are under our control. A modified Roblox Player is not promised.

## References

- [Apple Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- [Apple Disable Library Validation entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation)
- [Roblox modified client guidance](https://en.help.roblox.com/hc/en-us/articles/24275616578708-Anti-cheat-Messages)

## v1.5: launch the exact pristine copy

After creating a verified workspace, use **Launch Unmodified Working Copy**
in the same Settings card. Confirm the prompt. Rebilium:

1. Re-reads the workspace's external manifest and checks its identity.
2. Re-hashes the original and copied Player executables.
3. Re-verifies both app signatures using macOS codesign.
4. Asks LaunchServices to start a *new app instance* using the exact
   copied Roblox.app URL, without substituting a running installed copy.
5. Checks the reported application bundle path, displays the process ID,
   then records `launched: true` in the external manifest.

No bundled files, entitlements or code signatures are altered. Roblox may
independently update itself, reject launch without its normal website launcher,
or display an error. If macOS returns a different app URL, Rebilium says the
launch identity wasn't verified rather than reporting success. It doesn't
terminate other running Roblox apps.

This normal-launch baseline should **not** be described as an injector,
a modified game client, or proof of executing an in-game script like
Infinite Yield. The known signed Hardened Runtime protections still apply,
and any attempt to modify the binary would invalidate the signature.
