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

Roles and the names looked for when the manifest names none (`FigureModels.CLIPS`): idle, walk, run (loops); attack
(`attack`, `slash`), cast, hurt, die (`die`, `death`, `fall`), talk (`talk`, `agree`, `complain_01`), greet (`greet`,
`greet_01`, `wave`). Names are matched ignoring case, a library or armature prefix and an exporter's number
(`idle.001`, `Armature|walk`, `preset:quadruped:walk`).

## What the figure does with its clips

- **Walk in place.** A clip that carries the model forward (its root bone drifting across the ground, as Tripo's walk and
  greet do) has the drift taken out once, the first time the model is used. The distance it covered is its stride: the
  walk plays at the rate that covers the ground the figure moves, within 0.6x to 2.2x (`MIN_WALK_RATE`, `MAX_WALK_RATE`).
  Faster than that, a `run` clip plays if the model has one; otherwise the feet skate. Footfalls (for footsteps) are
  where the root bone is lowest.
- **Facing.** It turns to `facing` the short way round (`TURN_RATE`), at once the first time.
- **Attack and cast** play once, `struck` at `hit` (45% of the window when none is given), `attack_finished` at the end.
  Without a clip, `attack()` returns false and the token lunges, as for a sprite without an attack sheet.
- **Hurt** recoils (a lean back from the feet, and the white flash a game's feel asks for); a hurt clip plays as well.
- **Die** plays its die clip and lies in its last frame; without one it tips over backward and lies on its back, centred
  on its square (`pose` "down"). Getting up reverses it.
- **Gestures.** `FigureTalk.opened(view, npc)` turns the one spoken to and the party's leader toward each other and plays
  the greet; `FigureTalk.spoke(view, speaker)` plays a talk clip on each line. A game calls them from its dialogue
  (DialogueUI's `spoke`). Sprites have no gestures and keep their facing.

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
- Tests make a model in code (tests/unit/test_model_figure.gd) and add it with `FigureModels.register`.
