# Native library loading experiment (macOS only)

This is an isolated research prototype for **our own executable**. It does
not attach to Roblox, inject code, bypass anti-cheat, or execute Luau.

## What we verified in the supplied Delta IPA

The modified iOS \`Roblox\` executable has an
\`@executable_path/libgloop.dylib\` load dependency. This means the library
is loaded **inside that application process**, unlike an external editor
attaching to an unmodified Roblox Player. Because the binary is iOS/ARM64,
its library cannot be loaded directly into the macOS Roblox Player.

## What the experiment tests

- A deliberately small and auditable native-library ABI.
- The host passes a Luau source string and byte count to a separate dylib.
- The dylib returns validation metadata without evaluating the source.
- The host uses \`@executable_path/librebilium_bridge.dylib\` in its load
  commands; the dynamic linker loads the library *at launch*.
- A temporary-directory build and smoke test run on macOS CI.
- Oversized and null payloads are rejected.

To run on a Mac with the Xcode Command Line Tools installed:

\`\`\`bash
bash Experiments/InProcessHost/build_and_test.sh
\`\`\`

This proves that the library-host division and native source handoff work
in a program we **own and control**. It does not prove that ordinary Roblox
Player supports plugins, nor does it modify its signing or load commands.

## Next integration work

Expose a native-backend interface in Rebilium, add versioned messages and
roundtrip diagnostics, and implement a real connection to a cooperating
Roblox Studio plugin in a test project owned by the developer.

No functionality in this directory should be used to modify a third-party
game executable or defeat its runtime security protections.
