# Thornhold enemy artwork

Three individual 3D-style character renders generated with the built-in image_gen tool.

These PNG images are concept artwork. The game uses the rigged GLB models listed below, with skeletal animations from `assets/enemies/animations/`.

Character designs originated from `CastleArt.knight()`, `CastleArt.monster()`, and the three variants in `scripts/enemy.gd`. The current game loads the rebuilt models through `scripts/enemy_visual.gd`.

## Images

- [Blackguard](blackguard.png)
- [Ash Hound](ash-hound.png)
- [Horned Sentinel](horned-sentinel.png)

## Editable 3D models

The Blackguard was also rebuilt as editable Blender geometry with a posing rig. See the [model guide](blackguard-model/README.md), [Blender file](blackguard-model/blackguard.blend), and [Godot-compatible GLB](blackguard-model/blackguard.glb).

The other two enemies have matching editable geometry, posing rigs and GLB exports:

| Enemy | Blender source | Game export | Guide |
| --- | --- | --- | --- |
| Ash Hound | [Blender](ash-hound-model/ash-hound.blend) | [GLB](ash-hound-model/ash-hound.glb) | [Details](ash-hound-model/README.md) |
| Horned Sentinel | [Blender](horned-sentinel-model/horned-sentinel.blend) | [GLB](horned-sentinel-model/horned-sentinel.glb) | [Details](horned-sentinel-model/README.md) |

All three models are connected to gameplay. See [in-game animations](animations/README.md) for their clips, impact timing, and rebuild commands.

## Final generation prompts

### Blackguard

```text
Use case: stylized-concept
Asset type: individual enemy character render for the existing 3D medieval maze game Thornhold — The Emerald Gate.
Primary request: Generate one polished 3D-rendered image of the enemy described below.
Style/medium: stylized low-poly 3D game art with deliberate broad polygon facets, chunky readable forms, subtly beveled edges, convincing physically based materials, and restrained surface wear. Menacing medieval fantasy, visually cohesive with a simple low-poly stone fortress game. Preserve a clear game-ready silhouette; avoid hyperrealistic anatomy or cartoon facial expressions.
Scene/backdrop: genuinely transparent background with an alpha channel, isolated character, no scenery, no pedestal, no ground plane, no cast shadow outside the subject.
Composition/framing: square image, one complete full-body character in a front three-quarter view; face clearly visible; comfortable empty margin around every extremity and weapon; all feet, ears, horns, and weapons entirely within frame. Centered, occupying roughly 80% of the canvas.
Lighting/mood: soft neutral key light from upper left, gentle cool teal rim light, enough fill to read dark materials clearly, subtle orange-red emission from eyes. Consistent collectible-character studio lighting, clearly volumetric.
Constraints: one character only, no text, no labels, no logo, no watermark, no UI, no inset views, no collage. Render the character itself as a real three-dimensional object, not a flat illustration.
Subject: BLACKGUARD — a sinister stocky medieval knight, human proportions, wearing fully enclosed charcoal blue-gray plate armor (#454e5d) with muted aged bronze trim (#978568). Angular barrel-shaped great helm, narrow dark horizontal eye slit with exactly two small glowing ember-red eyes; a bronze vertical nasal bar. Broad layered shoulder plates, armored gauntlets, straight greaves and thick dark steel boots. A narrow dark burgundy cloth panel (#672f40) hangs down the front of the breastplate. He holds a straight single-handed medieval sword with a simple crossguard and a compact thick six-sided kite-like shield with a deep burgundy face (#512b38), bronze rim and simple vertical bronze central strip. Sword held low and slightly outward, shield ready, a calm threatening guard stance. No horns, no exposed face, no spikes or cape. Materials: dark brushed metal, worn bronze edges, matte burgundy cloth and painted shield; modest detail rather than dense ornament.
```

### Ash Hound

```text
Use case: stylized-concept
Asset type: individual enemy character render for the existing 3D medieval maze game Thornhold — The Emerald Gate.
Primary request: Generate one polished 3D-rendered image of the enemy described below.
Style/medium: stylized low-poly 3D game art with deliberate broad polygon facets, chunky readable forms, subtly beveled edges, convincing physically based materials, and restrained surface wear. Menacing medieval fantasy, visually cohesive with a simple low-poly stone fortress game. Preserve a clear game-ready silhouette; avoid hyperrealistic anatomy or cartoon facial expressions.
Scene/backdrop: genuinely transparent background with an alpha channel, isolated character, no scenery, no pedestal, no ground plane, no cast shadow outside the subject.
Composition/framing: square image, one complete full-body character in a front three-quarter view; face clearly visible; comfortable empty margin around every extremity and weapon; all feet, ears, horns, and weapons entirely within frame. Centered, occupying roughly 80% of the canvas.
Lighting/mood: soft neutral key light from upper left, gentle cool teal rim light, enough fill to read dark materials clearly, subtle orange-red emission from eyes. Consistent collectible-character studio lighting, clearly volumetric.
Constraints: one character only, no text, no labels, no logo, no watermark, no UI, no inset views, no collage. Render the character itself as a real three-dimensional object, not a flat illustration.
Subject: ASH HOUND — a lean hostile quadruped beast, part wolf and part armored hellhound, low-slung long body with dark ash blue-gray skin (#333a4b), short angular block-like muzzle and two tall pointed ears. Exactly four sturdy legs with charcoal purple-black armor-like lower surfaces (#3a3039), broad paws, muscular shoulders, and a slightly crouched stalking posture. Exactly two glowing orange-red eyes (#ff7850). Two clearly visible pale aged-ivory fangs jut down from the upper jaw. A single row of exactly five short conical bone spikes (#cbbb8c) runs along the top of its back, from behind the neck toward the rump. Compact angular head, sturdy jaw, mostly closed mouth with visible fangs, no horns. No prominent tail. It is alert with head turned enough toward the camera to reveal the muzzle, eyes and fangs; three-quarter view also makes the long torso and row of back spikes visible. Materials: faceted rough charcoal hide, dark armor-like limbs, matte old ivory spikes and fangs. No rider, no collar, no flames or smoke, no extra limbs, no gore, no furry realistic dog.
```

### Horned Sentinel

```text
Use case: stylized-concept
Asset type: individual enemy character render for the existing 3D medieval maze game Thornhold — The Emerald Gate.
Primary request: Generate one polished 3D-rendered image of the enemy described below.
Style/medium: stylized low-poly 3D game art with deliberate broad polygon facets, chunky readable forms, subtly beveled edges, convincing physically based materials, and restrained surface wear. Menacing medieval fantasy, visually cohesive with a simple low-poly stone fortress game. Preserve a clear game-ready silhouette; avoid hyperrealistic anatomy or cartoon facial expressions.
Scene/backdrop: genuinely transparent background with an alpha channel, isolated character, no scenery, no pedestal, no ground plane, no cast shadow outside the subject.
Composition/framing: square image, one complete full-body character in a front three-quarter view; face clearly visible; comfortable empty margin around every extremity and weapon; all feet, ears, horns, and weapons entirely within frame. Centered, occupying roughly 80% of the canvas.
Lighting/mood: soft neutral key light from upper left, gentle cool teal rim light, enough fill to read dark materials clearly, subtle orange-red emission from eyes. Consistent collectible-character studio lighting, clearly volumetric.
Constraints: one character only, no text, no labels, no logo, no watermark, no UI, no inset views, no collage. Render the character itself as a real three-dimensional object, not a flat illustration.
Subject: HORNED SENTINEL — a towering broad-shouldered humanoid ogre guardian with a huge heavy torso, thick arms, sturdy short legs, and muted reddish stone-brown skin (#674a48). Squared brutal head and jaw, two small glowing orange-red eyes (#ff7850), dark armored lower jaw guard. Exactly two long tapered aged-ivory horns (#cbbb8c), one on each side of its head, angle upward and outward. Massive charcoal purple-black shoulder pauldrons (#3a3039), a broad dark armored waist belt, heavy dark boots; exposed thick arms and chest show simple muscular faceted forms. Holds one long wooden-handled axe vertically beside the body, with one heavy broad angular steel blade near the top. Wooden shaft (#77604b), worn cool steel axe blade (#879398); no extra weapon. Imposing planted guard stance, slightly hunched forward, distinct giant-like proportions. Materials: rough warm stone-like hide, dark iron pauldrons and belt, old ivory horns, worn steel and brown wood. No wings, no cape, no skull decorations, no shield, no extra horns.
```
