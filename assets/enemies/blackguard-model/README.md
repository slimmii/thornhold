# Blackguard Blender model

Original low-poly geometry rebuilt from the generated Blackguard concept: charcoal steel plate, bronze trim, burgundy tabard, glowing ember eyes, sword and kite shield.

- **blackguard.blend** — editable source with individually named armor pieces, an 18-bone posing rig, packed concept reference, materials, studio lights and camera.
- **blackguard.glb** — one combined skinned mesh for import into Godot or another glTF-compatible application. The studio is excluded.
- **blackguard-preview.png** — front three-quarter render.
- **blackguard-back-preview.png** — rear three-quarter inspection render.
- **model-info.json** — geometry counts and dimensions.
- **verification.json** — Blender reopen, posing and GLB round-trip verification.
- **godot-verification.json** — successful Godot 4.7.2 import: one mesh, 18 bones and 15 material surfaces.

## Edit and pose

Open `blackguard.blend` in Blender. Expand **BLACKGUARD | Character** for the individual parts. Select **Blackguard_Rig**, enter Pose Mode, and rotate the anatomical bones. `weapon.R` and `shield.L` control the equipment relative to each hand. The reference is packed as **REFERENCE | Blackguard concept** in the Image Editor.

This is a rigid armor rig in a relaxed guard pose. It has no animation clips or IK controls. Large poses may require adjusting overlapping armor and cloth pieces. All meshes have UV coordinates; the appearance uses portable PBR material colors, metallic/roughness values, and emissive eyes.

The figure is approximately 2.31 metres tall. Blender uses Z up, facing -Y; standard GLB conversion uses Y up, facing +Z. The game's visual wrapper rotates it to face -Z and loads this GLB for every Blackguard. Idle, walk, run, attack, hit and death clips are supplied as a separate [Godot animation library](../animations/README.md); the Blender source and GLB retain their rest poses.

## Rebuild and verify

Run from the project root with Blender on your PATH:

```sh
blender --background --factory-startup --python-exit-code 1 --python assets/enemies/blackguard-model/build_blackguard.py
blender --background --factory-startup --python-exit-code 1 --python assets/enemies/blackguard-model/verify_blackguard.py
```

The build script regenerates the model, GLB, front render and geometry report. The verification script reopens the Blender file, checks that posing moves the helmet, renders the back, and imports the GLB into a fresh scene to validate the mesh, rig, UVs, weights, triangle count and bounds.
