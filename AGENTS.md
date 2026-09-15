# Thornhold local development

## Play the web game on the local network

From the repository root, run:

```sh
python3 tools/serve_web.py
```

This builds the Godot web export and serves only `builds/web/` over HTTPS,
listening on all IPv4 interfaces on port 8080. It prints the local-network URL.
Open that URL from another computer on the same network. Use a desktop browser
with WebGL 2, WebAssembly, a keyboard, and a mouse; touch controls are not included.
Click **Enter the labyrinth** to capture the mouse and start playing.

Keep the server computer awake and the command running. Stop with **Ctrl+C**.
No public deployment or router port forwarding is needed. If another computer
cannot connect, check that both devices share a reachable LAN and that the host
firewall permits inbound TCP on the selected port.

### Firewall on this Linux Mint host

UFW is enabled and was confirmed to block incoming connections on port 8080.
Allow the game from this host's current LAN subnet only (run on the server;
sudo may prompt for your password):

```sh
sudo ufw allow in on enp3s0 from 192.168.128.0/23 to any port 8080 proto tcp comment 'Thornhold LAN'
```

Then open `https://192.168.129.18:8080/` from the other computer. The interface,
subnet, and address above match this machine at setup time; check `ip -4 addr`
and the script's printed URL if the network changes. A successful curl request
on the server itself does not verify incoming firewall access. Check the
server access log for a request from the other device after refreshing.
Do not disable UFW. To remove this specific exception later:

```sh
sudo ufw delete allow in on enp3s0 from 192.168.128.0/23 to any port 8080 proto tcp
```

To leave an already-built game running in the background on Linux/macOS:

```sh
nohup python3 -u tools/serve_web.py --skip-build > builds/lan-server.log 2>&1 &
echo $! > builds/lan-server.pid
```

Stop that background server before starting another on the same port:

```sh
kill "$(cat builds/lan-server.pid)"
```

The log and PID file are local runtime files; the server does not start at boot.

Options:

```sh
# Start quickly using the last successful export:
python3 tools/serve_web.py --skip-build

# Choose another port:
python3 tools/serve_web.py --port 8090

# Restrict access to this computer:
python3 tools/serve_web.py --bind 127.0.0.1
```

Run without `--skip-build` after changing game source or assets. Paths are
resolved relative to the script, so it also works from another directory.
Requirements: Python 3.11+, curl, OpenSSL, and Godot 4.7.2 on PATH (`godot` or `godot4`).
Use `--godot /path/to/godot` or `GODOT_BIN` to override the executable.
The first build downloads about 1.3 GB of official export templates and verifies
their pinned checksums. Later builds reuse the cached web template in `.tools/`.
Generated exports and caches are ignored by Git.

## HTTPS and browser trust

Godot requires a secure context, including in this single-threaded export.
HTTP on a LAN IP fails this requirement. The server now defaults to HTTPS on
port 8080, so use **https://**, and keep the existing firewall exception.
It generates a local self-signed certificate with the LAN IP, 127.0.0.1, and
localhost in its subject alternative names. Certificates and private keys stay
in `.tools/lan-tls/`, outside the served directory; keys must never be shared.
Certificates are reused until near expiration; a changed LAN IP gets a new one.

On the playing device, the browser will initially warn about the local
certificate. The user must handle that warning or explicitly trust the public
`.crt` certificate on their device; the agent must not click through a browser
security warning. Only trust the certificate for this known local server.
Existing trusted certificates can be supplied using `--cert FILE --key FILE`.

For a client with SSH, an alternative that needs no certificate trust is to run
a loopback-only HTTP server on the game host:

```sh
python3 tools/serve_web.py --skip-build --http --bind 127.0.0.1 --port 8081
```

Then run this on the playing computer and leave it running:

```sh
ssh -N -L 8081:127.0.0.1:8081 slimmii@192.168.129.18
```

Open `http://localhost:8081/` on the playing computer. Browsers treat localhost
as a secure context; SSH encrypts the connection between the computers.

## Verification

### Diagnose a browser stuck on the Godot splash

Open `https://192.168.129.18:8080/?diagnostics=1` on the affected device, then
inspect `BROWSER` lines in `builds/lan-server.log`. This opt-in page reports
browser/version, resource timings, console errors, and five-second heartbeats
to this LAN server only. The game prints startup milestones for scene entry,
environment, audio, castle generation, and title initialization. A missing
milestone helps locate the stall; do not infer that native/headless tests prove
browser startup or rendering works. Normal URLs do not inject diagnostics.

The web game uses a static title screen, disables 3D multisampling and sun
shadows, and renders gameplay at 75% 3D resolution to reduce browser GPU load.
Native rendering keeps its original settings. Exercise the web profile in the
headless smoke suite with:

```sh
godot --headless --path . --script res://tests/smoke_test.gd -- --web-profile
```

This verifies gameplay and menu transitions, not browser frame rate. Check the
actual playing device for rendering performance after rebuilding the export.

Run `python3 tests/lan_server_test.py` after changing the server. It verifies
that unfinished TLS handshakes, idle HTTPS connections, and accidental plain
HTTP connections cannot block other clients. Keep TLS negotiation in worker
threads with timeouts; wrapping the listening socket can stall all clients.

Verify a server change by starting it, fetching `/` and `/index.wasm`, checking
the WebAssembly MIME type (`application/wasm`), and confirming `/project.godot`
returns 404. For the generated certificate, verify TLS without disabling
certificate validation:

```sh
curl --cacert .tools/lan-tls/192.168.129.18.crt -I https://192.168.129.18:8080/
```

A successful HTTP/TLS check does not prove browser trust or gameplay. Verify
loading and starting the game from the other device after trusting the
certificate. Run gameplay checks for changes to game behavior:

```sh
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/progression_test.gd
godot --headless --path . --script res://tests/enemy_animation_test.gd
```
