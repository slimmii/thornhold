# In-game skeletal animations

The game loads the three rigged GLBs through `scripts/enemy_visual.gd`. The models and animation libraries are explicit preloaded dependencies so Godot includes them in game exports. Each enemy has a separate AnimationPlayer using the corresponding shared animation library in this folder. Blender exports face +Z; the visual wrapper rotates them to the game's -Z steering convention and applies the intended creature scale.

Each library contains **idle**, **walk**, **run**, **attack**, **hit**, and **death** clips. Walk and run playback rates follow the enemy's actual movement speed. All bone axes come from the imported skeleton's rest transforms. The clips animate the skeleton; gameplay movement stays on CharacterBody3D.

| Enemy | Attack length | Damage impact | Death clip |
| --- | ---: | ---: | ---: |
| Blackguard | 0.82 s | 0.30 s | 1.05 s |
| Ash Hound | 0.66 s | 0.23 s | 0.90 s |
| Horned Sentinel | 1.08 s | 0.46 s | 1.20 s |

At high difficulty, attack playback speeds up if needed to fit the reduced attack interval. Damage uses the same scaled impact time, rechecks range, facing and walls, and happens once per attack. Taking a hit or dying cancels a pending strike. Pause, armory, completion and player death freeze both the animation and combat clocks. Defeated enemies finish their death clip, remain briefly, then shrink away and are removed.

The `.res` files are native Godot AnimationLibrary resources. They are separate from the editable Blender models and GLB exports, which retain their original rest poses. Open a library in Godot to inspect its clips. `scripts/enemy_animation_factory.gd` is the reproducible animation source.

## Rebuild after changing the rigs or clips

From the project root:

```sh
godot --headless --path . --script res://tools/build_enemy_animations.gd
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/enemy_animation_test.gd
```

The game consumes the GLBs directly. Automatic Blender-file import is disabled in `project.godot`, so Godot does not launch Blender or import the presentation studio when scanning the source artwork. Regenerate a GLB with its Blender build script before rebuilding these libraries if the mesh or skeleton changed.

The recorded [in-game animation preview](../../../screenshots/enemy-animations.mp4) shows all six clips on the three enemies.

To capture a new preview, run `tests/enemy_animation_visual.gd` with a rendered Godot window. It stages actual game-spawned enemies in the castle courtyard and writes `screenshots/enemies-in-game.png`. Pass `-- --frames=/absolute/directory` to capture idle, walking, running, attack, hit and death frames for video QA.
