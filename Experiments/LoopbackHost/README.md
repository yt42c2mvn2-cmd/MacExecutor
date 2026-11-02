# Rebilium localhost transport — real interprocess test

This milestone tests actual communication between **two separate processes**.
It is not a Roblox connection. The test host is a small Python 3 process
you explicitly start, and it only responds to one strict ping/pong message.

## Run it

1. Open Terminal at your MacExecutor repository folder.
2. Run:

    python3 Experiments/LoopbackHost/host.py

3. Leave that Terminal window running.
4. Open Rebilium, go to **Settings → Native backend lab**, and press
   **Ping Separate Test Host**.
5. You should see **Connected to local test host** with request/response sizes.
   The Terminal window logs each ping.
6. Stop the host with **Control+C**. Ping again; Rebilium should say the host
   is not running rather than claiming success.

The listener binds only to IPv4 127.0.0.1, port 37827. It does not accept
arbitrary Lua source and has no execute action or access to Roblox.
Messages are JSON over TCP, newline-delimited, max 4,096 bytes, protocol v1.
The ping includes a UUID correlation ID and a fixed diagnostic marker. Replies
must carry the same ID, protocol version, and marker.

**This is a transport functionality test, not peer authentication or a
security boundary.** Another local program able to use the same port could
imitate the diagnostic host. No secrets or user scripts are sent.

### Automated tests

    python3 -m unittest discover -s Experiments/LoopbackHost -p 'test_*.py' -v
    bash Experiments/LoopbackHost/test_end_to_end.sh

The end-to-end test compiles Rebilium's exact Swift TCP client and the shared
wire protocol as a standalone probe, launches the Python host on an available
ephemeral loopback port, and verifies a successful real ping/pong exchange.

A subsequent milestone could implement a separately authenticated adapter
for a cooperating Roblox Studio plugin, within documented Studio capabilities.
Do not treat a successful local ping as proof Roblox Player accepts scripts.
