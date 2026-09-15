# Horned Sentinel Blender model

Original low-poly geometry based on the Horned Sentinel concept, matching the Blackguard model's faceted materials and studio lighting. Includes a broad stone-brown physique, two curved ivory horns, charcoal iron pauldrons and boots, a slotted jaw guard, glowing eyes, and a long-handled axe.

- [horned-sentinel.blend](horned-sentinel.blend): individually named editable pieces, a 19-bone humanoid rig, packed concept reference, studio lights and camera.
- [horned-sentinel.glb](horned-sentinel.glb): one combined skinned mesh with 15 PBR materials, excluding the studio.
- [Front render](horned-sentinel-preview.png) and [rear render](horned-sentinel-back-preview.png).
- [Geometry report](model-info.json), [Blender verification](verification.json), and [Godot verification](godot-verification.json).

## Edit and pose

Open the Blender file, select **Horned_Sentinel_Rig**, and enter Pose Mode. The rig includes pelvis, spine, chest, neck, head, arms, hands, legs, feet, and **weapon.R** for the axe. Body and limb skin use blended weights; horns, armor, and weapon components use rigid weights. Individual fingers follow the hand bones.

All meshes have UVs. Materials use portable PBR colors and emissive eyes; there are no external texture dependencies. The concept is packed as **REFERENCE | Horned Sentinel concept**. The figure is approximately 3.36 metres high to the horn tips.

The Blender source and GLB contain the posing rig without embedded animation clips or IK. Extreme poses may require further skin-weight or armor adjustments. The game now loads this GLB for every Sentinel, with idle, walk, run, axe attack, hit and death motion supplied by a separate [Godot animation library](../animations/README.md).

Blender coordinates are Z-up, facing -Y. Standard glTF conversion produces Y-up, facing +Z; rotate the imported model 180 degrees around Y if a consumer expects -Z forward.

## Rebuild

Run from the project root:

```sh
blender --background --factory-startup --python-exit-code 1 --python assets/enemies/horned-sentinel-model/build_horned_sentinel.py
blender --background --factory-startup --python-exit-code 1 --python assets/enemies/verify_creature_models.py -- horned-sentinel
```

The builder uses `assets/enemies/model_tools.py`. The Blender check reopens the source, tests head posing, checks the expected anatomy, renders the rear, and validates a fresh GLB import. `assets/enemies/verify_creature_models.gd` checks both new models in Godot.
