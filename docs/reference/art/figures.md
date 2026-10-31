# 3D figures for characters and creatures

A character or creature can be drawn as a rigged 3D model instead of its 8-direction sprite. Anything without a model
keeps its sprite, so a game moves to 3D one figure at a time, and a game with no models sees nothing change.

## How it fits in

- `world/look/figure_models.gd` (`FigureModels`) reads `art/figures/manifest.json` (the core's, with the game's merged
  over it, as every art manifest). An art id with an entry whose file exists has a model.
- `DirectionalSprite.frames_for(art_id)` hands such an id blank stand-in frames carrying the art id; `DirectionalSprite.create`
  turns them into a `ModelFigure` (`world/look/model_figure.gd`). Every caller that draws a figure (CombatToken for the
  party, people, foes and guests; FieldView; the gray-box room) gets the model with no change of its own.
- `ModelFigure` extends `DirectionalSprite`, so it answers to the same things: `facing`, `moving`, `pose`, `walk_speed`,
  `set_step_time`, `attack`, `cast`, `hurt`, `die`, `recoil`, `gesture`, and the `struck`, `attack_finished` and `footfall`
  signals. Its own sprite draws nothing (no render layers); the model is its child, `ModelFigure > Turn > Posture > model`.
- A pregen whose id has a model wears it as its own art (`CombatToken.art_for`); a person wears the model named by their
  `sprite`. Heights come from `art/creature_looks.json` as for sprites (`CombatToken.height_for`), else the entry's `height`.

## The manifest

```json
{
  "defaults": {"clips": {"attack": {"clip": "slash", "from": 1.25, "to": 2.85, "hit": 2.12, "speed": 1.3}}},
  "figures": {
    "rook": {"file": "art/figures/rook.glb", "scale": 1.0, "lift": 0.0, "turn": 0.0, "clips": {"talk": ["agree"]}}
  }
}
```

- `file`: the model (a GLB, or any scene with a Skeleton3D, its meshes and an AnimationPlayer).
- `scale`: times the height the figure is drawn at (the model is fitted so its feet are on the ground and its top at that
  height). `lift` raises it (world units). `turn` turns it (degrees) to face +z, south, the way a figure faces the camera.
- `clips`: role to clip, where a model's names aren't the usual ones. A name, a list (played in turn), or
  `{"clip", "from", "to", "hit", "speed"}`: part of a long clip, the moment the blow lands, how fast it plays.
- `defaults`: under every figure of the manifest (its `clips` merged role by role), for models made the same way.

For creatures, and figures whose models are still to come:

- `sprite`: the art id of the 8-direction sprite worn while the model's file isn't there (`FigureModels.stand_in`,
  `DirectionalSprite.frames_for`). A game lists a figure before its model arrives, and it switches to 3D the moment the
  file lands. One step only: a stand-in that has a stand-in of its own isn't followed.
- `base`: another figure's art id. The entry is laid over that one's (file, clips, scale, height, everything it doesn't
  say itself), so one rigged body can be worn by several creatures. A `base` entry has its model when its base does.
- `albedo`: a texture painted on every textured surface in place of the model's own: with `base`, a dressing of the
  shared body. It must be a retexture of the same mesh and UVs (Tripo's retexture of a rigged model keeps both).
- `bones`: `{"Head": 1.18}`, bones grown or shrunk on top of every clip (`FigureBones`, a SkeletonModifier3D), so a
  body shared by a grown-up and a child can still differ in build. Names ignore case and a rig's prefix (`Head` finds
  `mixamorig_Head`).
- `ghost`: `{"wash", "colour", "glow", "see_through", "rim", "pulse"}`, each 0 to 1 (`ModelFigure.set_ghost_look`):
  washed toward `colour` (a palette name; the silver of an Echo Knight's echo without one), its own light, the share of
  it the world shows through, a glow along its edges in its colour (its ink darkens to that colour too), and how far
  its glow throbs. A ghost seen through is blended softly: a depth pass of its own (`figure_depth.gdshader`) at the
  figures' render priority, then its surfaces and ink one priority later, so only its nearest surface shows (never its
  far arm through its chest) and its line fades less than its body. Fades stay the screen-door dither.
- `shader`: a game's own spatial shader for the figure's surfaces in place of `lit_figure` (the hook for a look the
  engine doesn't draw). It includes `figure.gdshaderinc` and takes the uniforms `ModelFigure.surface_material` sets.

Roles and the names looked for when the manifest names none (`FigureModels.CLIPS`): idle, walk, run (loops); attack
(`attack`, `slash`), cast, hurt, die (`die`, `death`, `fall`), talk (`talk`, `agree`, `complain_01`), greet (`greet`,
`greet_01`, `wave`). Names are matched ignoring case, a library or armature prefix and an exporter's number
(`idle.001`, `Armature|walk`, `preset:quadruped:walk`).

A role a model has no clip for borrows another's (`FigureModels.FALLBACKS`): a model rigged with only a walk (Tripo's
"Other" rig on a crawler or a hound) idles on its walk at 0.3x, a stir in place, rather than standing in its bind pose.
The rest fall back as below: run to the walk sped up, attack to the token's lunge, hurt to the recoil, die to the
tip-over, talk and greet to nothing.

## What the figure does with its clips

- **Walk in place.** A clip that carries the model forward (its root bone drifting across the ground, as Tripo's walk and
  greet do) has the drift taken out once, the first time the model is used. The distance it covered is its stride: the
  walk plays at the rate that covers the ground the figure moves, within 0.6x to 2.2x (`MIN_WALK_RATE`, `MAX_WALK_RATE`).
  Faster than that (`RUN_FROM`), a `run` clip plays if the model has one, paced to the ground by its own stride; otherwise
  the feet skate. A sneaking figure (`pose` "sneak") always walks. A looping clip that carries the model is also centred
  on the root bone's rest, so a run that starts mid-stride (Tripo's starts half a square on) runs over its own square.
  Footfalls (for footsteps) are where the root bone is lowest.
- **Facing.** It turns to `facing` the short way round (`TURN_RATE`), at once the first time.
- **Attack and cast** play once, `struck` at `hit` (45% of the window when none is given), `attack_finished` at the end.
  Without a clip, `attack()` returns false and the token lunges, as for a sprite without an attack sheet.
- **Hurt** plays its hurt clip with the white flash a game's feel asks for; without one (or while it swings) it recoils,
  a lean back from the feet, with the flash.
- **Die** plays its die clip and lies in its last frame. The clip's root is held over the square (a fall that slides the
  body off to one side, as Tripo's does, lies across the square instead). Without one it tips over backward and lies on
  its back, centred on its square (`pose` "down"); getting up reverses it. A figure whose die clip looks worse than the
  tip-over names none: `"clips": {"die": []}`.
- **Gestures.** `FigureTalk.opened(view, npc)` turns the one spoken to and the party's leader toward each other and plays
  the greet; `FigureTalk.spoke(view, speaker)` plays a talk clip on each line. A game calls them from its dialogue
  (DialogueUI's `spoke`). Sprites have no gestures and keep their facing.

## Layers: gear and clothes on the figure

A figure can wear parts on its own skeleton, so what a hero holds and wears shows and moves with every clip. The
manifest's `parts` names them; a figure entry's `layers` lists the parts it always wears, and `ModelFigure.wear(ids)`
puts on what it wears now (taking off what it no longer does). `worn_parts()` lists them.

```json
{
  "parts": {
    "lantern": {"file": "art/props/lantern.glb", "bone": "RightHand", "size": 0.2, "grip": [0, 0.88, 0], "turn": [180, 0, 0]},
    "long_cloak": {"file": "art/figures/layers/long_cloak.glb", "hides": ["body_back"]}
  },
  "gear": {"hooded_lantern": "lantern", "torch": "torch"},
  "figures": {"silas": {"file": "art/figures/silas.glb", "gear": ["main_hand", "off_hand"], "layers": ["long_cloak"],
    "sockets": {"RightHand": {"offset": [0, 0.02, 0], "turn": [0, 0, 10]}}}}
}
```

- **A rigid piece** has a `bone`: it is held there (a `BoneAttachment3D` on the figure's skeleton). `size` is its longest
  side as a share of the figure's height, `grip` the point held (in the piece's own units; its middle when none is
  given), `offset` (figure heights) and `turn` (degrees about x, y, z) place it on the bone. A figure entry's `sockets`
  gives a bone a frame of its own first (where this model's palm is), so one part sits right on different bodies.
  `"upright": true` keeps the piece standing the way the figure stands while it follows the bone (a lantern hangs, a
  torch is held up): a hand's roll differs from rig to rig and clip to clip (Tripo's Mixamo rigs agree only on the
  fingers' direction), so a piece that should stay level is placed this way.
- **A skinned layer** has no `bone`: its skinned meshes move onto the figure's skeleton and bind to it bone by bone by
  name, so it plays every clip the figure plays. Bones match ignoring an exporter's prefix and case (`RightHand`,
  `mixamorig:RightHand`, `mixamorig_RightHand`: `FigureModels.bone`). A layer fits the body it was weighted on: make
  layers on the body they are worn over, in that body's rest pose, and export them with the armature (a mesh exported
  without one loses its bind names).
- **`hides`** names the figure's own meshes the part covers (`"*"` for all of them), so a body under a coat doesn't
  poke through. Split a body into region meshes for that.
- Layers go through the figure's material, ink and state (fade, flash, glow, ghost) like its own meshes.

**Gear.** `FigureModels.gear_for(art_id, character)` turns what a character has in the slots their figure's entry
lists under `gear` (`main_hand`, `off_hand`, `armor`, `cloak`, `head`...) into parts: the item's own `look`, else the
manifest's `gear` for its id, else for the mundane item under a magic one. Parts are made for the right hand; one in
the off hand is mirrored (`FigureModels.mirrored`, the id with `@off`). A figure whose entry lists no `gear` slots
shows none, since its model has its things drawn on. `CombatToken` dresses a character's figure when it is made and
again whenever what they have on changes, whatever changed it.

## Bodies: made heroes as figures

A game whose heroes are 3D names the body a made hero wears under the manifest's `bodies`: species id (`"*"` for any)
to gender (`"*"` for any) to a figure id, the species' own before `"*"`. `FigureModels.body_for(species, gender)` reads
it; `HeroLook.figure_for(appearance, species)` asks it for a look.

```json
"bodies": {"*": {"female": "hero_body_female", "male": "hero_body_male"}, "curseborn": {"male": "curseborn_man"}},
"figures": {"hero_body_female": {"base": "some_figure", "albedo": "art/figures/clay.png"}}
```

- `HeroLook.register` (called by `CombatToken.art_for` for every made hero) registers the hero's own art id as a figure
  laid over that body (`base`), so their token, the gray-box room and anything else that draws them draws the body, at
  the height `HeroLook.height_units` gives (the catalog's `species_heights` and height pick), wearing their gear when
  the body's entry lists `gear` slots. A look with no body keeps the paper doll.
- The creator's Appearance step (`AppearancePanel`, `HeroPreview`) shows the body on a turntable in a viewport of its
  own: it turns slowly, can be dragged round, and stands, walks, runs, swings, casts and greets with its own clips,
  wearing the hero's starting gear (`FigureModels.gear_for` on the builder's preview). Genders are offered where a
  body exists; the picks only the paper doll draws (builds, heads, hair, beards, outfits, skin and hair colours) are
  left out, and a tab with nothing to pick isn't shown.
- A game with figures still keeps an `art/creator/catalog.json` for the rest of the look: genders, heights,
  `species_heights`, portraits, voices and the defaults.

## The look

`shaders/world/lit_figure.gdshader` and its ink pass `figure_ink.gdshader` light a figure the way the 2D figures are lit:
light wrapped round the body, no light past a cap, a floor so it reads in the dark, a rim from lights behind it. Like the
sprites it draws after the screen pass (`DirectionalSprite.RENDER_PRIORITY`), so the place's mist, grade and depth blur
stay on the world and the figure stays clear; it is fully opaque and writes depth, so figures hide each other as solid
things. A figure's own state (its fade, tint, flash, glow and ghostliness) is per instance; materials are shared by every
copy of a model. Fades are a screen-door dither, so a fading figure keeps its depth and outline.

A game tunes it under `data/campaign.json` "figures" (`Look.figure_settings`): `floor`, `light_cap`, `rim`, `ink` (outline
pixels at 1080 lines, 0 for none), `ink_colour`; and in the Toon finish `bands` (0 soft, 2 lit and shade, 3 and a dark
core), `band_lit`, `band_dark`, `band_mid`, `band_edge`, `flatten` with `flatten_mip`, and `vivid`.

## Gotchas

- An exporter's texture is often 4K or 8K. A figure fills a few hundred pixels: keep the game's copy at 2K.
- A capture window draws slowly; shoot an action when its clip reaches a time, not after a count of frames.
- Picking (`SpritePick`) tests a column down the figure's middle and its meshes.
- Tests make a model in code (tests/unit/test_model_figure.gd) and add it with `FigureModels.register`; parts with
  `FigureModels.register_part` (tests/unit/test_figure_layers.gd).
