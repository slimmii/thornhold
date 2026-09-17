# Thornhold — The Emerald Gate

A playable, single-player 3D medieval maze game made in Godot. You are a knight trapped in a ruined fortress. Find the emerald portal while blackguards, ash hounds, and horned sentinels hunt you. Collect gold, buy increasingly long-reaching weapons, and survive the journey.

## Play

Open `project.godot` in **Godot 4.4 or later**, then press **F5**. Tested with **Godot 4.7.2 on macOS / Apple M2**, using the Compatibility renderer. The project requires no plugins or downloaded asset packs.

On this Mac, double-click **Play Thornhold.command**, or run:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/slimmii/Git/similon-maze
```

Press **Enter** or click **Enter the labyrinth**. Your mouse is captured during play; **Esc** releases it and pauses the game.

In the web version, click **Resume your journey** after pausing or switching tabs.
Use **Return to the maze** or **B** to leave the armory. The game waits for mouse
capture before resuming; if the browser declines, the menu stays available to
click again. Escape keeps the web game paused so the pointer stays free.

| Control | Action |
| --- | --- |
| W A S D | Move relative to where you look |
| Mouse | Look around |
| Left mouse / hold | Attack / repeat attacks |
| Right mouse / hold | Raise shield; frontal hits deal 80% less damage and consume stamina |
| Shift / hold | Sprint; consumes stamina and makes you easier to hear |
| Space | Jump |
| B | Open / close the armory; pauses the hunt |
| 1–4 in armory | Purchase that upgrade if available |
| M | Toggle the exploration map |
| Enter on completion | Continue to the next level |
| Enter after death | Retry the current level with your gear and gold |
| Esc | Open the pause menu; click Resume to continue on the web |
| F11 | Toggle fullscreen |
| F3 | Toggle FPS display |

## Web releases

Export a release with **Python 3.11+**, curl, and **Godot 4.7.2**:

```sh
python3 tools/build_web.py
```

The script downloads matching export templates once and creates
`builds/thornhold-vercel.zip`. See [Vercel deployment](web/DEPLOY.md) for publishing
the extracted static files. The web game runs in desktop browsers with WebGL 2
and WebAssembly; no special cross-origin isolation headers are needed.

For an automatic itch.io build and upload with Butler:

```sh
python3 tools/deploy_itch.py --login
python3 tools/deploy_itch.py --target your-name/thornhold --version 1.0.0
```

Add `--dry-run` to build and inspect the upload without publishing. Butler is
installed automatically if needed. See [itch.io deployment](web/ITCH.md) for
the one-time HTML5 settings, environment variables, and unattended CI usage.
Deployment checks: `python3 tests/itch_deploy_test.py`.

## Web performance

The web build uses **Sharp (100%)** at full viewport resolution, with a sharp
full-resolution HUD and no multisampling. Rendering at 100% avoids the 3D
upscaling step. There is no graphics-mode switch.
The FPS display starts enabled; **F3** toggles it.

The game uses flat comic colors with basic Minecraft-inspired block lighting.
Daylight reaches open areas, cover is darker, and torches cast steady warm light
that spreads through open space and loses brightness with distance. Solid walls
block its path. Light levels are baked once per level and stay fixed as you move.
Enemies, weapons, and pickups share the same lighting.

This uses a small light map with no dynamic lights, shadow maps, fog, bloom,
metallic reflections, or moving dark-edge effects. All torches remain active.
The portal keeps its opaque diamond design and emerald pennant.
Enemies and courtyard statues have small, soft ground shadows. These simple
ellipses share one batch of 30 triangles and stay attached to the objects as you
move; they do not need real-time shadow rendering.

The castle uses spatially grouped masonry so offscreen sections can be culled.
Distant enemy poses update less often while movement, AI, and combat keep their
normal update rate. Distant pickup models are hidden beyond 28 m.
Weapons and shields keep their screen size while fitting inside the player's
wall clearance. Wall collisions cover stone overhangs.

Rebuild with `python3 tools/build_web.py` after changing game code, then serve it
with `python3 tools/serve_web.py --skip-build`. Compare FPS in the same maze and
view after reloading. Headless tests validate behavior and rendering workload;
they do not measure browser FPS.

## Gold and upgrades

Walk close to a spinning coin to collect **3 gold**. The first two coins in the entrance courtyard pay for your stick. Open the armory with **B**. Buy weapons in order: each purchase increases your accumulated reach and damage and equips the new weapon. Your gear and unspent gold carry across every level and retry in the current journey.

| Weapon | Cost | Reach | Damage |
| --- | ---: | ---: | ---: |
| Iron gauntlets | Starting equipment | 1.65 m | 12 |
| Ashwood stick | 6 gold | 2.5 m | 26 |
| Knight's sword | 15 gold | 3.3 m | 42 |
| Warden's spear | 27 gold | 4.7 m | 58 |
| Royal halberd | 42 gold | 6.2 m | 85 |

Blackguards drop 5 gold, ash hounds 4, and sentinels 12. Crimson tonics restore 35 health; they remain on the ground while you are at full health. All pickups are automatic.

## Finding the exit

The emerald diamond on your compass points toward the portal. An emerald pennant rises above the castle walls. The map reveals connected corridors as you explore, and marks the portal's location. Follow the actual passages to get there: attacks and movement cannot pass through walls.

Monsters patrol until they see or hear you. They follow the maze's passage graph, remember your last position, and return to patrolling if they lose your trail. Sprinting helps you escape but attracts attention. Raise your shield while facing an attacker or buy a longer weapon to keep enemies away.

Blackguards, ash hounds and horned sentinels use the rigged low-poly models in `assets/enemies/`. They breathe while idle, walk on patrol, run when chasing, and react to hits and death. Sword swings, bites and axe strikes have a visible windup; damage lands at the impact, so stepping away, moving behind a wall, or interrupting an enemy can stop the blow. Opening the armory or pausing freezes their animations as well as combat.

The exit is in a distant reachable cell. Enter the portal to complete the level, then choose **Enter level 2** (or press **Enter**) to continue. Each level generates a different maze. Your equipped weapon, all purchased upgrades, and unspent gold carry forward; health and stamina refill. The level number appears in the HUD, and the completion screen previews the next hunt.

**Retry level** preserves the current level, maze layout, equipment, and coins, including after death. Only **New journey · reset progress** starts over at level 1 with no gold or upgrades. Inventory and level progression last for the current game session. Your best single-level escape time is saved locally in Godot's `user://record.cfg`.

## Escalating enemies

Every completed level raises enemy health and damage by 22% and 13% of their original values. Their movement speed, hearing, sight, memory, and reaction times also improve. Movement improvements taper so sprinting remains faster than every enemy.

- **Level 1:** patrol, detect nearby movement, chase, and attack.
- **Level 2:** patrol without immediately doubling back when another route exists, and search side passages after losing your trail.
- **Level 3:** call nearby allies to the last reported sighting. Calls travel a limited number of connected passages, so a wall can prevent a nearby enemy from hearing them.
- **Level 4 onward:** some hunters aim for the next open passage based on movement they actually saw, while others pursue directly. Searching and tracking continue improving in later levels.

Enemies use their senses and remembered sightings. Searching and interception do not reveal your current position after you escape their detection range.

## Project structure

- `scenes/main.tscn`: entry scene.
- `scripts/game.gd`: journey and level state, inventory carryover, spawning, progression, input bindings, environment, and records.
- `scripts/maze.gd`: seeded maze generation, passage routing, batched masonry, castle construction, and exit portal.
- `scripts/player.gd`: first-person controls, sprint, jump, shield, and melee.
- `scripts/enemy.gd`: three monster variants, level scaling, patrol/chase/search behavior, ally alerts, interception, timed attacks, and rewards.
- `scripts/enemy_visual.gd`: rigged GLB models, facing and scale, blended animation playback, and movement-based playback speed.
- `scripts/enemy_animation_factory.gd`: reproducible idle, walk, run, attack, hit and death animation clips.
- `assets/enemies/`: editable Blender sources, game GLBs, concept artwork, and native Godot animation libraries.
- `scripts/art.gd`: original procedural low-poly castle, knight statues, weapons, and shared comic materials.
- `scripts/hud.gd`: title screen, HUD, compass, exploration map, armory, pause, and results.
- `scripts/pickup.gd`: coins and healing tonics.
- `scripts/sound.gd`: synthesized effects and an ambient drone.
- `scripts/block_lighting.gd`: static sky and torch light propagation on a small grid.
- `assets/shaders/comic.gdshader`: fixed three-tone materials sampling the block light map.
- `assets/shaders/portal.gdshader`: opaque emerald diamond portal design.

The scene builds at runtime. Press F5 to see the castle; the editor's static viewport only contains the entry node. Stone and floor geometry use MultiMeshes, with flat comic shading throughout the scene. Enemy models load from the included GLBs; their Blender sources and concept references are included for editing. Godot's automatic Blender import is disabled because the game uses GLBs. The remaining geometry, UI illustrations, and sounds are generated by this project. Fonts use installed system fonts with fallbacks; typography may vary between operating systems.

## Verification

Run the gameplay tests:

```sh
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/progression_test.gd
godot --headless --path . --script res://tests/enemy_animation_test.gd
```

The smoke suite checks 20 maze seeds for connected paths and reciprocal walls, then tests actual physics movement, jumping, wall collision, corner-following enemy pursuit, coin pickup, purchase order and funds, extended melee reach, attack occlusion, shield damage, healing, pause, death, portal victory, and replay. The progression suite completes multiple levels and verifies inventory and weapon-model carryover, difficulty growth, search behavior, ally alert limits, interception, keyboard/button transitions, retries, and explicit resets. The animation suite checks all three imported rigs, real bone motion, animation selection, windup and impact timing, pause, dodging, wall occlusion, interrupted strikes, shield blocking, death rewards and corpse cleanup.

See `assets/enemies/animations/README.md` for rebuilding the animation libraries and capturing the in-game animation preview.

Render the title, armory, map, monster, portal, completion screen, and second-level carryover for visual inspection:

```sh
godot --path . --resolution 1440x900 --script res://tests/visual_check.gd
```

PNG captures are written to `screenshots/`. Visual tests stage encounters and funds for inspection; they do not change normal starting equipment or save escape records. The game also supports `-- --autostart` and `-- --capture=/absolute/path.png` for quick visual checks.
