# The HD-2D look: what the engine draws, what a game brings, and how to retheme it

Written 2026-10-29 from the Curse of Strahd game (game main `ef29e6278`, engine `6777c47`), its art and UI docs, the
owner's feedback in the build logs, and the performance pass. The technique docs this summarises are copied into
[reference/art/](../reference/art/) and [reference/ui/](../reference/ui/).

**Short answer for a new game:** the renderer is in the engine. Every script and shader that makes the look (the lit
3D world, the 8-direction sprites with their ink outline, the atmosphere, weather, plants, ground, water, see-through
walls, the screen pass, the menu kit) lives in this repo under `world/look/`, `shaders/` and `ui/`. What makes it
*Barovia* is data and art that stay in the game: the colour lists, the moods, the plant sets, the vistas, the props
catalog, the travel map and three set pieces. A new game with a different palette and a different vibe keeps the
engine as it is and writes its own versions of those files. Three of them are loaded by fixed path today, so they
must exist before the engine will even compile (see "Hard requirements" below).

---

## 1. What the look is

- **2D characters in a 3D world.** Characters and monsters are hand-drawn 2D sprites, rendered in 8 directions,
  standing as billboards in a fully 3D world of low-poly models, lit surfaces, plants, water and weather. Square
  Enix's HD-2D (Octopath Traveler) is the reference, pushed gothic for Barovia (owner, 2026-10-07).
- **Characters keep an ink line; the world does not.** Each sprite gets an ink outline of about 1.4 screen pixels
  and is drawn sharp. The world is lit like painted 3D with no outlines of its own. The contrast is what makes the
  characters read.
- **Two finishes, same art.** *Modern* (the default since 2026-10-07): filmic tone mapping, bloom on flames and
  lanterns, soft shadows from the nearest lights, contact shadows, a thin haze, smooth mist and cloud shadows, a
  depth blur toward the screen's edges with the middle sharp. *Classic*: every world pixel snapped to the palette,
  light in two or three hard bands. Classic is frozen as it was on 2026-10-07: new work keeps it working, not
  current. A new game can drop Classic from its settings if it never wants it; the engine still supports it.
- **Camera and scale** (ADR 0004): one world unit is one 5 ft square, a Medium character is about 1.2 units tall,
  the camera looks down at 40 degrees, starts at a 45 degree heading and turns in 90 degree steps. That is why
  sprites need 8 directions. Real-world sizes: a person is 6 ft and props are sized to match.
- **UI is not part of the world.** Menus and the HUD draw on CanvasLayers, so the screen pass and the palette never
  touch them. They have their own colour list.

## 2. Engine or game: where each piece lives

### In the engine (this repo), reusable as is

| Piece | Where | What it does |
|---|---|---|
| `Look` | `world/look/look.gd` | The one place that builds the look: cel materials, the screen pass, colour by name, the Modern/Classic switch (publishes `look_soft`) |
| `Atmosphere`, `AtmosphereLand`, `AtmosphereWeather` | `world/look/atmosphere*.gd` | A place's mood: sun and sky by time of day, mist, cloud shadows, colour grade, water, the land past the map's edge, rain, snow, leaves, wisps, smoke, embers, lit windows, lightning |
| `DirectionalSprite`, `HeroLook`, `SpriteReflection` | `world/look/` | 8-direction sprites, hero looks, reflections in wet floors |
| Sprite shader | `shaders/world/sprite_crisp.gdshader` | 4x4 supersampling of the full sheet per screen pixel plus the ink outline; sheets import without mipmaps |
| World shaders | `shaders/world/lit*.gdshader*`, `weather_surface.gdshaderinc`, `cel*.gdshader*` | Surfaces lit like painted 3D (highlights, relief, roughness, reflections on polished floors), wet and snowy ground, the Classic cel bands |
| Screen pass | `shaders/post/screen_pass.gdshader` | Mist, the Mists' wall, cloud shadows, ground patches, grade, vignette, edge blur, outlines, the Classic palette snap |
| Land and scenery builders | `flora.gd`, `woods.gd`, `ground_relief.gd`, `ground_cover.gd`, `shores.gd`, `crags.gd`, `caves.gd`, `cliff_face.gd`, `waterfall.gd`, `vista.gd`, `mist_bank.gd`, `sun_shafts.gd`, `light_curtain.gd` | Trees and undergrowth, shaped ground, banks, rock, water, falls, distant scenery cards, light shafts |
| Buildings and rooms | `building_kit.gd`, `town_builder.gd`, `interior_walls.gd`, `fortress_tower.gd`, `ruin.gd`, `drystone.gd`, `stairs.gd`, `tent_walls.gd`, `furnish.gd`, `set_dressing.gd`, `model_piece.gd`, `prop_view.gd` | Towns from a kit of walls, roofs and yards; rooms furnished like their owner's home; props from the catalog as 3D models or billboards |
| Readability helpers | `see_through.gd`, `place_dissolve.gd`, `foreground_framing.gd`, `found_outline.gd`, `hover_glow.gd`, `touch_outline.gd`, `trap_glow.gd` | Walls and trees fade between camera and party, found things outline, hover glows, traps glow once found |
| Graphics presets | `world/look/graphics.gd` | Low, Medium, High: anti-aliasing, shadow maps, how many lamps cast shadows |
| Effects | `shaders/fx/*`, `world/combat/fx/`, `art/vfx/` | Spell and ability effects (beams, blasts, columns, rings, smoke, auras, area outlines) |
| Generic art | `art/textures/`, `art/models/` (about 330 `.glb`), `art/sprites/` and `art/portraits/` (monsters), `art/icons/`, `art/ui/`, fonts | Shared by any game; a game overrides a file by putting one at the same path in its own `art/` (`ArtPaths`) |
| Menu kit | `ui/common/ui_kit.gd`, `ui_parts.gd` | Every screen's frames, buttons, bars, tooltips and shapes ("shapes, not squares") |
| Hooks | `world/look/campaign_look.gd` (`CampaignLook`) | Where a game adds its own set pieces; the base class builds none |

### In the game, never in the engine

| Piece | Curse of Strahd's file | A new game writes |
|---|---|---|
| World colours | `art/palette/palette.json`, `palette.png` (the strip the shaders read), `palette.gpl`, built by `tools/art/build_palette.py` | Its own list and strip |
| Menu colours | `art/palette/ui_palette.json` (crimson, black, aged gilt) | Its own values under the same key names |
| Moods | `art/atmosphere/moods.json` | Its own moods per place, region and theme |
| Plants | `art/plants/flora.json` and the plant cards | Its own plant sets per region |
| Vistas | `art/vistas/` (the castle on its crag, the mountains, the lake) | Its own skyline cards |
| Props catalog | `art/sprites/props/catalog.json` plus Barovia-only props | Its own catalog entries (the engine's models can be reused by id) |
| Travel map | `art/ui/map/barovia.png` | Its own map art |
| Set pieces | `world/look/strahd_look.gd` (the `CampaignLook` for this game), `castle_builder.gd`, `castle_model.gd`, `amber_*.gd`, `faceless_god.gd` and the amber, void and title shaders | Its own, or none |
| Characters | Hero and NPC sprites, portraits, busts, cutscene pictures, the creator's parts | Its own, from the same pipeline |
| Title screen | `shaders/ui/title_mist.gdshader`, `title_wind.gdshader`, the title art and music | Its own |

### Hard requirements a new game must meet first

Three engine files preload game art by fixed path, so the engine will not compile in a host that lacks them (listed
in [handbook/new_game.md](../handbook/new_game.md) part 3):

- `res://art/palette/palette.png` (preloaded by `Look`): the palette strip.
- `res://art/plants/cards.png`: the plant card sheet.
- `res://art/ui/map/barovia.png`: the travel map (the name is a leftover; a new game can put its own map at that path
  until the engine reads it from data).

`art/palette/palette.json` and `ui_palette.json` are read by name at run time: every colour name the engine asks for
must exist in them, or `Look.color` asserts. The safest start is to copy Curse of Strahd's two files, keep every key,
and change the values.

## 3. How a frame is built

1. **The board.** `ArenaBoard` builds floors, walls, raised ground and stairs from the location's map rows, with lit
   materials and the region's ground (`ground_swap`, `ground_tint`).
2. **Set dressing.** Props, containers, doors and lights come from the props catalog by `model` or id: real 3D
   models where the art has one, billboards for flat things. Towns come from the building kit. Never plain boxes.
3. **Land.** Flora, shaped ground, banks and rock on the walkable map, then the land past the edge (`surround`) and
   the vista cards on the horizon.
4. **Atmosphere.** The mood for the place and the hour: key and ambient light, sky, haze, mist, cloud shadows, weather
   pieces, wet or snowy ground, flame tint. A mood can be `like` another and change only what differs.
5. **Characters.** Billboards drawn through `sprite_crisp` after the screen pass, at full screen resolution, so they
   stay sharp in both finishes.
6. **Screen pass.** Mist, grade, vignette, edge blur and outlines (and the palette snap in Classic).
7. **UI** on CanvasLayers, untouched by all of the above.

The shaders read seven global uniforms the host declares in `project.godot` (`look_soft`, `world_wet`, `world_snow`,
`world_time`, `world_sky`, `see_window`, `see_window_eye`); the engine sets them at run time.

## 4. Retheming for a new world: the recipe

Do these in order. Each step has a capture to check it.

1. **Pick target frames before building anything.** Generate or paint three to five frames of the new world at the
   game camera's angle (day, dusk, night, an interior, a fight) and get the owner's pick. Curse of Strahd chose
   between two directions (A: effects; B: tone) and took "A's effects in B's tone" (2026-10-07). Everything after this
   is measured against those frames.
2. **Write the colour list.** About 50 named colours in ramps (near-black that is never pure black, the signature
   hues, skin, stone, earth, foliage, fire). Copy `tools/art/build_palette.py` from the game repo, replace its list,
   run it to make `palette.json`, `palette.png` and `palette.gpl`. Nothing in the game may invent a colour after
   this: art, moods and UI all name palette colours (tests check moods).
3. **Write the menu colours** in `ui_palette.json`, keeping the key names (`ui_black`, `ui_oxblood`, `ui_wine`,
   `gilt_dark`, `gilt`, `gilt_light`, the `arch_*` set). A sea-and-brass world would put teal where the oxblood is
   and brass where the gilt is; the menu kit draws the same shapes in the new colours. Menu ornaments and icons are
   white silhouettes tinted by the game, so they recolour for free.
4. **Write a colour script** for the regions before their moods: each region gets a signature (its light, its shade,
   its ground, its weather) and no two neighbours share one. Curse of Strahd's came after the owner's "every place
   doesn't look the same" (2026-10-12) and is in `reference/art/atmosphere.md` as the list of region looks.
5. **Write the moods** (`art/atmosphere/moods.json`): a base outdoor and indoor mood, then one per region and theme,
   then per place only where a place should feel different. Match order: a place's id, the longest id prefix, its
   region (`"<region>"` outdoors, `"<region>/indoors"`), its map theme, then `outdoors` or `indoors`. A mood holds
   light per time of day, mist, clouds, grade, water, weather kinds and the land around the map, plus a `modern`
   block for the Modern finish (`tone`, `ground_tint`, `ground_swap`, `lying_wet`, `lying_snow`, `flame_tint`,
   `surround`). Give every indoor place a look too; none should sit on the bare `indoors` mood.
6. **Make the surfaces.** Tileable textures per surface (`make textures`, smooth `<surface>_hd.png` tiles for
   Modern), each with how it takes the light (roughness, relief, polish). The engine's `art/textures/` are
   Barovia-leaning stone, wood, mud and snow; reuse what fits and add your own sets.
7. **Plants, vistas and props.** Plant sets per region (`art/plants/flora.json`), vista cards for the horizon, and the
   props catalog. Reuse the engine's 330 models by id where they fit; new ones come from 2D art turned into models,
   or free CC models.
8. **Characters last, through one pipeline**, so the style holds: a 5-view turnaround on a plain white background
   with the game's own style preamble, cut into 8 directions, then the attack and the fuller hero set (see
   [handbook/pipelines.md](../handbook/pipelines.md)). Change the preamble's tone words for the new world (Curse of
   Strahd's says gothic horror as a 1990s Saturday-morning cartoon, bold ink, flat cel shading, big silhouettes).
9. **Portraits and busts** on one plain ground colour from the palette (Curse of Strahd used `ash_violet` for every
   set), three-quarter view, lit from the side or below.
10. **Set pieces** through your own `CampaignLook` subclass, named under `"look"` in `data/campaign.json`, only for the
    few places the generic builders can't make.

Capture each step in both finishes (`make capture` with the polish, look, land and region capture scenes; the
atmosphere preview gives a place at each hour with frame times).

## 5. What the owner taught us about reading the screen

Each of these came from the owner looking at a capture and saying something was wrong. They hold for any world.

- **No grain, no dither.** The first pass drew the world on a grid of double pixels with a checker dither before the
  palette snap. It read as grain. The pass now runs at full resolution with no dither (2026-10-06).
- **Sharp characters.** Sprites looked blurry because the GPU drew a pre-shrunk mipmap (a 384 px sheet shown at about
  110 px). Sheets now import without mipmaps and the sprite shader supersamples the full sheet. Speckle on the sheets
  was cut from 20% to 8% by smoothing before cutting and despeckling after.
- **Ink on characters, none on the world** (2026-10-07). Outlines on everything made the world look like a cartoon
  backdrop and the characters lost their pop.
- **HD surfaces may leave the palette** in Modern; the palette's hues stay, the snap goes.
- **A light depth blur at the far edges**, strongest in the corners, middle sharp, with Off and reach in Settings
  (2026-10-08, 10-09). A heavy blur hid the fight.
- **Walls never collapse; blockers fade** (2026-10-17). Near walls cut away toward the camera indoors; trees and
  walls between the camera and the party dissolve. A tree that came back from fading once drew a black box behind it
  because its see-through edges were switched off; keep the alpha path on until the fade has finished.
- **Every place its own look** (2026-10-12): two places in a row that look the same read as a bug to the owner.
- **Draw the land, then lay the grid over it** (2026-10-19): natural outlines on the side the party can't stand on,
  built things straight, the grid an overlay. Square-edged lakes and cliffs read as placeholder.
- **Exits obvious, hidden areas hidden** until found, on the board, the map and the minimap.
- **Nothing overlapping**, floors and walls varied, real-world sizes. A prop at the wrong scale is the first thing
  the owner notices.
- **Weather on the surfaces**, not only in the air: wet cobbles with puddle reflections, settled snow, footprints.
- **A capture for anything visual**, before and after, in both finishes. The owner signs off on pictures, not on
  descriptions.

## 6. What it costs to draw

Measured 2026-10-07 on the owner's Mac mini (Apple Silicon, 24 GB) under heavy load, High preset, 1920x1080:

| Effect | Saves when off (Vallaki by day, about 20 ms a frame with everything on) |
|---|---|
| Half resolution | 11.8 ms |
| Sun shadows (draw calls halve) | 4.5 ms |
| The screen pass | 3.7 ms |
| All lamps | 3.6 ms |
| MSAA 4x | 2.3 ms |
| SSIL, lamp shadows, depth of field | 1.4 to 1.8 ms each |
| SSR, glow, fog, SMAA, SSAO | under 1 ms each |

- **Video memory grows with characters.** Each monster or NPC's sheets are about 21 MB, each hero with the full HD set
  75 to 90 MB, and sheets stayed loaded until quit (1.15 GB on the first place, 1.84 GB after twelve). Empty the
  sprite sheet cache between places.
- **Place loads** are mostly the 3D dressing: model pieces up to 220 ms, normal maps made at run time up to 290 ms on
  a first visit, trees 90 to 170 ms. Preload the next place where you can.
- **Big fights** froze on every enemy turn until the AI read each creature's modifiers once per turn instead of
  750,000 times, and sight lines checked only the squares they cross. Watch any per-square, per-target loop.
- **Importing textures** is two to three times faster with a hidden editor window (GPU compression) than headless;
  the game's `make import` does that.
- Every engine `project.godot` change costs players a full download (about 4.4 GB for Curse of Strahd). Batch them.

## 7. Where to read more

- [reference/art/style_bible.md](../reference/art/style_bible.md): palette rules, line and shading, proportions,
  prompting, art QA, what is banned.
- [reference/art/atmosphere.md](../reference/art/atmosphere.md): moods, regions, indoor looks, edges and shadows,
  rules for new places.
- [reference/art/textures.md](../reference/art/textures.md), [plants.md](../reference/art/plants.md),
  [set_dressing.md](../reference/art/set_dressing.md), [building_kit.md](../reference/art/building_kit.md),
  [interiors.md](../reference/art/interiors.md), [models.md](../reference/art/models.md),
  [decals.md](../reference/art/decals.md), [spell_effects.md](../reference/art/spell_effects.md),
  [animation.md](../reference/art/animation.md), [creator.md](../reference/art/creator.md).
- [reference/ui/look.md](../reference/ui/look.md): the menu kit and its rules of thumb.
- [game_design_principles.md](game_design_principles.md) parts 1.4 and 5.
