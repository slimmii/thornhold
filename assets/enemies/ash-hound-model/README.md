# Ash Hound Blender model

Original low-poly geometry based on the Ash Hound concept, matching the Blackguard model's faceted materials and studio lighting. Includes charcoal hide, angular leg armor, four clawed paws, five ivory dorsal spikes, two upper fangs, tall ears, and emissive eyes.

- [ash-hound.blend](ash-hound.blend): individually named editable pieces, a 19-bone quadruped rig, packed concept reference, studio lights and camera.
- [ash-hound.glb](ash-hound.glb): one combined skinned mesh with 13 PBR materials, excluding the studio.
- [Front render](ash-hound-preview.png) and [rear render](ash-hound-back-preview.png).
- [Geometry report](model-info.json), [Blender verification](verification.json), and [Godot verification](godot-verification.json).

## Edit and pose

Open the Blender file, select **Ash_Hound_Rig**, and enter Pose Mode. The rig contains pelvis, spine, chest, neck, head, jaw, and three bones for each leg. Body and limb skin use blended weights; spikes, armor, teeth, and eyes follow their corresponding bones. The jaw pivots separately from the upper fangs.

All meshes have UVs. Materials use portable PBR colors and emissive eyes; there are no external texture dependencies. The concept is packed as **REFERENCE | Ash Hound concept**. The figure is approximately 1.76 metres high to the ear tips and 2.73 metres long.

The Blender source and GLB contain the posing rig without embedded animation clips or IK. Extreme poses may require further skin-weight adjustments. The game now loads this GLB for every Ash Hound, with idle, walk, run, bite, hit and death motion supplied by a separate [Godot animation library](../animations/README.md).

Blender coordinates are Z-up, facing -Y. Standard glTF conversion produces Y-up, facing +Z; rotate the imported model 180 degrees around Y if a consumer expects -Z forward.

## Rebuild

Run from the project root:

```sh
blender --background --factory-startup --python-exit-code 1 --python assets/enemies/ash-hound-model/build_ash_hound.py
blender --background --factory-startup --python-exit-code 1 --python assets/enemies/verify_creature_models.py -- ash-hound
```

The builder uses `assets/enemies/model_tools.py`. The Blender check reopens the source, tests head posing, checks the expected anatomy, renders the rear, and validates a fresh GLB import. `assets/enemies/verify_creature_models.gd` checks both new models in Godot.
