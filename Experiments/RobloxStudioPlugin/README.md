# Rebilium Roblox Studio plugin — opt-in handshake

**Purpose:** prove that Roblox Studio can communicate with Rebilium's local
backend using supported plugin HTTP APIs. **This does not inject into Roblox Player or execute Luau.**

## Install and connect (first manual Studio test)

1. Merge this PR and pull the repo into your Mac.
2. In Terminal, from the MacExecutor repo root, run:

        python3 Experiments/LoopbackHost/host.py

   The host now opens two loopback-only listeners:
   - TCP 127.0.0.1:37827: Rebilium diagnostics and Studio status
   - HTTP 127.0.0.1:37828: Studio plugin heartbeat endpoint

   Terminal prints a **Studio pairing token**. Leave Terminal running.
   This token changes each time you restart the host. Treat it as a local
   secret; do not paste it into screenshots or publish it.

3. Open **Roblox Studio** in a development place you control. Insert a normal
   Script inside ServerStorage, paste the contents of
   [RebiliumBridge.plugin.luau](RebiliumBridge.plugin.luau), then use
   **Plugins → Save as Local Plugin**. Remove the original ServerStorage script
   after saving it as a local plugin.
4. In Studio, click the **Rebilium Connection** plugin button. Paste the pairing
   token into the widget and click **Connect to local backend**.
5. Roblox Studio may prompt you to allow the plugin's HTTP requests to
   127.0.0.1; approve that address if you trust this code. If permission was
   denied, update it through **Manage Plugins**.
6. In the Rebilium macOS app, open **Settings → Native backend lab** and click
   **Check Roblox Studio Connection**. It should report an authenticated
   Studio heartbeat (only if the handshake succeeded).
7. Stop the Terminal host or unload the plugin. The connection indicator
   expires after 30 seconds without a heartbeat.

## Security boundaries

- Studio initiates every request, after the user's explicit pairing click.
- The backend listens only on 127.0.0.1, not the LAN or internet.
- A fresh random token is generated on each backend launch.
  The HTTP endpoint rejects invalid tokens and accepts only a fixed
  version-1 client declaration (not source code).
- Heartbeats refresh an expiring **presence lease**, not a script receiver.
- Rebilium queries that lease through its existing local TCP channel.
- This is proof of pairing and liveness, **not identity assurance against
  local processes with access to the token**, nor production authentication.
- No Luau execution, process memory, Player modifications, or script transfer.

## Next steps

After validating the real Studio plugin, add a distinct
**review/approve/import** workflow using ScriptEditorService to edit scripts
in a development experience you control. Never automatically execute scripts
during pairing or import.

## Documentation references

- [Roblox HttpService: Studio plugins and localhost](https://create.roblox.com/docs/cloud-services/http-service)
- [Roblox Studio plugins](https://create.roblox.com/docs/studio/plugins)
- [Roblox ScriptEditorService](https://create.roblox.com/docs/reference/engine/classes/ScriptEditorService)


## Review-only script transfer

After pairing Studio and confirming its connection in Rebilium:

1. Select a saved script in Rebilium's Scripts tab.
2. Open Settings → Native backend lab, paste the **same** temporary token
   into the secure Studio-send field, then select **Send Selected Script to Studio**.
3. Open the installed Studio plugin. Click **Fetch script preview**. Inspect
   its full source in the read-only preview box.
4. Click **Approve: import inert ModuleScript** only if you trust the content.
   This creates a ModuleScript in ServerStorage, where it is not automatically
   executed. You can review or edit it further in Studio.

No script is imported merely by sending or previewing it. The backend holds
one offer in memory, with a maximum source size of 64 KiB and a ten-minute
expiry; submitting a new offer replaces the previous one. An acknowledgement
removes the offer after successful import. Restarting the host also clears
it. Do not import untrusted code expecting it to be sandboxed.

**Existing local plugin installations must be updated** with the revised
plugin source for the new preview and approval buttons to appear.

This feature does not attach to a regular Roblox Player, change a Roblox
client, or silently run any Luau code.
