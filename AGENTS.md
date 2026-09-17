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

### Menus and browser mouse capture

Escape releases the pointer and pauses the web game. Click **Resume your journey**
to continue; Escape stays in the pause menu because browsers reserve that key
for unlocking the pointer. Use **Return to the maze** or B to leave the armory.
Returning from another tab also requires a Resume click.

Request mouse capture synchronously from a real input event. Web buttons activate
on mouse-down, and `capture_pointer()` focuses the HTML canvas before requesting
capture. `capture_pending` keeps the current menu and gameplay paused until
`Input.mouse_mode` confirms the browser has granted the lock. Do not set the game
to `playing` merely because capture was requested. Failed requests leave the
button available to retry; late grants after opening another menu are released.
Clear held gameplay actions and GUI keyboard focus when resuming so menu clicks
do not attack and lost key-up events do not leave movement stuck.

```sh
godot --headless --path . --script res://tests/menu_input_test.gd
```

This exercises actual Godot GUI clicks with simulated asynchronous capture
grants, denials, Escape ordering, tab changes, and movement after resuming.
Also test Escape → Resume and B → Return in the playing browser: headless tests
cannot verify that browser's pointer-lock permissions.

### Diagnose a browser stuck on the Godot splash

Open `https://192.168.129.18:8080/?diagnostics=1` on the affected device, then
inspect `BROWSER` lines in `builds/lan-server.log`. This opt-in page reports
browser/version, resource timings, console errors, and five-second heartbeats
to this LAN server only. The game prints startup milestones for scene entry,
environment, audio, castle generation, and title initialization. A missing
milestone helps locate the stall; do not infer that native/headless tests prove
browser startup or rendering works. Normal URLs do not inject diagnostics.

### Web rendering performance

The web build uses **Sharp (100%)** only, with no MSAA. Keep
`Viewport.scaling_3d_scale = 1.0`: matching the 3D and viewport resolutions
bypasses the resolution-upscaling step. The user reported higher FPS at 100%
on their machine and explicitly requested removal of the lower-resolution
modes. There is no F6 quality shortcut or Graphics menu button. The HUD stays
at full resolution. F3 toggles the FPS display; it is on by default for web.

The game uses simple Minecraft-inspired block lighting with flat comic colors.
`BlockLighting` builds a 98 × 24 × 98 grid at 0.8 m spacing when a level loads.
Sky and torch levels range from 0 to 15. Open sky stays at level 15 straight
down; light spreading sideways or around cover loses one level per grid step.
Torches emit level 14. Solid masonry blocks propagation; overlapping sources
use the brighter level. Structural towers and gatehouse arches also occlude
light. Small decorative props do not become oversized opaque blocks.

The two light channels are uploaded once to a small RG8 3D texture.
`assets/shaders/comic.gdshader` samples this map in world space, just outside the
visible face, and keeps the three fixed normal-based tones. Every torch remains
active; there is no light selection, distance switching, or per-frame bake.
Moving enemies, weapons and pickups sample the same map. Torch flames use a
constant bright color. The portal retains its opaque diamond and pennant design.

Keep the shader opaque, unshaded and single-pass, with no Light3D nodes, shadow
maps, reflections, fog, bloom, or screen-texture postprocessing. Do not add
view-angle rim darkening: it creates a dark band on floors and walls that follows
the player. A fixed surface's lighting must remain unchanged as the camera moves.
Imported enemies keep their original colors and skinning. `CastleArt` binds the
active game's light map to shared materials, including subsequently created
weapon and pickup materials, and releases that binding when the game exits.

Web masonry uses spatial MultiMesh chunks with instance colors, one shared comic
material, and explicit bounds. Preserve all transforms and colors when changing
batching. Avoid grouping all bricks of a color across the entire maze in the
web build: that prevents useful frustum culling. Large foundation slabs use a
separate batch. Native batches use the same comic shader with solid base colors.
All geometry has shadow casting disabled; the local shadow atlas has size zero.
Enemies and the two courtyard statues have soft contact shadows from
`GroundShadows`: one MultiMesh batch of at most 15 ground quads (30 triangles).
These are small transparent ellipses with ordinary depth testing, clipped at
closed cell walls. Their world positions follow the casters, hound ellipses
follow the model's facing, and corpse shadows fade with disappearing bodies.
The floor height is fixed because this maze has a flat floor. Raised platforms
or terrain would require a different receiver height. Keep these patches small;
they do not cast silhouettes onto walls or require lights, shadow maps, texture
lookups, raycasts, or screen-space effects. Stationary instances reuse their
buffer data. No distance-based shadow switching or camera-facing darkening.
Distant enemy animation poses update at 15 Hz beyond 20 m, but physics, AI, and
attack impact timing always keep their normal cadence. Pickups beyond 28 m skip
visual updates. The web HUD redraws at 30 Hz; button/state changes redraw at once.

Run these checks after web rendering changes:

```sh
godot --headless --path . --script res://tests/web_performance_test.gd
godot --headless --path . --script res://tests/smoke_test.gd -- --web-profile
godot --headless --path . --script res://tests/progression_test.gd -- --web-profile
godot --headless --path . --script res://tests/enemy_animation_test.gd -- --web-profile
godot --headless --path . --script res://tests/wall_safety_test.gd -- --web-profile
godot --headless --path . --script res://tests/lighting_stability_test.gd
godot --headless --path . --script res://tests/block_lighting_test.gd
godot --headless --path . --script res://tests/ground_shadows_test.gd
```

The performance test compares exact generated masonry data, chunk bounds,
frustum candidates over 16 views, animation cadence, comic materials, and fixed
100% rendering. The dummy renderer cannot read back MultiMesh instance transforms;
the test captures the CPU-side inputs passed to the batch builder instead.
Its candidate counts are workload estimates, **not FPS measurements**. Confirm
actual frame rate with the in-game counter on the playing device.

### Weapon clearance and comic rendering

First-person equipment is scaled together with its camera offsets, preserving
its projected size while keeping even the halberd swing inside the player's
0.32 m wall clearance. Keep the equipment on its shared `viewmodel` parent and
disable its world shadow casting after every weapon purchase. Melee reach and
wall-blocking damage rays remain in world units. Wall colliders include the
stone base/coping overhang. Equipment uses render layer 2 and the same comic
materials as the world.
The wall safety suite checks real movement against
four walls and every weapon through a full swing with the shield raised/lowered
and camera pitched up/down; run it with and without `--web-profile`.

For actual image-based material verification, use a working graphics display:

```sh
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/lighting_render_test.gd
```

This renders native and web masonry with no lights. It verifies three distinct
face tones, a readable floor, matching instance/base colors, and stable surface
color as the camera approaches. Perspective checks at eye height cross the old
rim-darkening threshold on floors and walls. An injected light must not alter
these materials. A second fixture checks warm torchlight, distance attenuation,
a sealed wall, and camera-independent baked brightness.
Contact-shadow captures also check subtle opacity, soft edges, wall occlusion,
and stable placement/brightness when approaching at eye height.
Captures go to `builds/visual-checks/`. On this host the X11 display is `:1`;
prefix the command with `DISPLAY=:1` if running from a shell without DISPLAY.
It requires a real renderer and intentionally rejects `--headless`. A native
Compatibility rendering check still does not measure FPS on the remote browser.

The lighting stability test checks three seeds in native and web profiles:
no generated lights, no shadow casting or atlas, no fog/glow/SSAO, and comic
materials on procedural geometry and every imported enemy surface. The test
also verifies that moving through the castle never creates lights or changes the
baked data/texture. The block-light suite checks skylight, roof openings, torch
falloff, wall occlusion, overlapping sources, bounded map size, and every torch
across three generated seeds. These checks do not measure FPS on a remote device.
The ground-shadow suite checks movement, hound facing, bounds, all four wall
directions, camera independence, corpse cleanup, and replacement on level changes.

### Hound melee hit regions

Hounds use bone-following combat volumes for the rump, chest, head, muzzle and
four legs. `EnemyVisual.HOUND_HIT_REGIONS` stores their bounds in the GLB's rest
coordinates. Current bone poses, the model's facing correction, and scale map
these volumes into world space. Weapon reach is measured to the nearest surface
of each region. Each candidate must pass the melee aim cone and wall ray test;
one swing damages only one enemy. The navigation capsule is separate from these
combat regions. Keep the humanoid target rules and enemy attack timing intact.

```sh
godot --headless --path . --script res://tests/hound_hitbox_test.gd
godot --headless --path . --script res://tests/hound_hitbox_test.gd -- --web-profile
```

This checks real player attacks on the hound's visible body from four headings
during idle, run and bite poses, every weapon's reach, missed aim, wall blocking,
cooldowns, and corpse/reward handling.

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
