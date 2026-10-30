# A new game on the engine: what the engine gives you and what the game must bring

Written 2026-10-29 from the Curse of Strahd game (github.com/ashwinmahesh/CurseOfStrahd, main `ef29e6278`, core
`6777c47`), its `docs/plans/engine_split.md`, the core scope audit of 2026-10-26 and the core's own code. Read
[../README.md](../README.md) first for where everything else is.

The rule that decides where a file belongs (owner, 2026-10-26): **anything that is not specifically one campaign, and
that another D&D game could reuse, belongs in the core**: HUDs and screens, spell and item icons, visual and sound
effects, shaders, the camera, the look. A new game should only need its own characters, voice recordings, quests, maps,
palette and mood.

## 1. What the core holds today

| Part | Folder | Notes |
|---|---|---|
| Rules engine | `rules/` | Pure library: no nodes, scenes, autoloads or UI. Takes a `DiceRoller` argument. `Compendium` (`rules/data/compendium.gd`) loads the data. |
| Combat and AI | `combat/` | Grid, `Encounter`, spells, features, reactions, monster actions, difficulty (`combat/difficulty.gd`), the AI (`combat/ai/`). Pure logic, runs headless. |
| Story engine core | `story/` | State, dialogue file and runner, conditions, quest log, narrator, banter, schedule, services, crime, rests, camp, captives, approval, check aids, field items, weather, travel, treasure, XP, `CampaignModule`. |
| Autoload plumbing | `core/` | Dice, GameState, SaveSystem (with upgrade steps), GameSettings, ModeController, SceneRouter, EventBus, Audio, VoiceOver, Achievements, BugReports, ErrorWatch, PatchLoader, input actions, `ArtPaths`. |
| UI | `ui/` | Every HUD and screen: combat HUD, explore HUD, character sheet, creation, level up, inventory, shops, journal, saves, settings, dialogue UI, the d20, cutscene player, travel screen, tutorial pieces. `UiKit` and `UiParts` are the kit. |
| World | `world/` | The board (`world/combat/arena_board.gd`), tokens, combat view, spell effects, exploration, the camera rig, and the whole HD-2D look in `world/look/` (see [../design/hd2d_look.md](../design/hd2d_look.md)). |
| Shaders | `shaders/` | Cel and lit world shaders, the crisp sprite shader, the screen pass, atmosphere (water, foliage, vistas), effects, UI. |
| Skirmish | `skirmish/` | The Character Lab and the any-map, any-level fight mode. |
| Schemas and data | `data/` | About 1,600 rules entries of the books: classes, subclasses, species, backgrounds, feats, spells, items, magic items, monsters, conditions, plus the schemas. |
| Generic assets | `art/` | Fonts, controller prompts, 21 sound-effect packs, the spell/item/feature icons and their game-icons.net sources, effect definitions, generic textures, props, 3D models and object kinds (Git LFS since 2026-10-28), every core monster's sprites and portraits, generic summons. |
| Tests | `tests/` | The in-house runner (`tests/test_runner.tscn`), `TestCase`, support helpers and about 150 unit test files. |

**Not in the core** (each game keeps or copies its own):

- **All build tooling.** The Makefile, `tools/` (test runner wrapper `run_tests.py`, `check.py`, `lint_gd.sh`,
  `logcheck.sh`, `godot_slot.sh`, `import.sh`, `lane.sh`, the edge build, the Godot wrapper and `nofocus.m`, data
  validators and lints, capture scenes, the perf probe, the wiki generator, release and iOS tooling, the git pre-push
  hook) and `blender/`. The game's tools find the core by its path (`tools/data/dataroots.py`).
- **The art, voice and image pipelines** (`tools/art`, `tools/audio`, `blender/`), their manifests and ledgers.
- **CI workflows** (`.github/workflows/release.yml`, `mac-dmg.yml`, `ios.yml`).
- **The guard test** that keeps campaign names out of the engine (`tests/unit/test_engine_names.gd` and its baseline
  in `tests/fixtures/engine_campaign_baseline.json`).
- **The campaign**: its module and look scripts, locations, NPCs, quests, dialogue, cutscenes, the reshuffle (Tarokka
  in Strahd), endings, music and its mood mapping, voices, heroes' and NPCs' art, busts, portraits, the palette,
  atmosphere moods, plants, vistas, the travel map art.
- **The engine's own documentation of record** until now: ADRs, contracts, rules coverage and deviations, UI and art
  guides were written in the game repo. A snapshot is in [../reference/](../reference/README.md).

## 2. How a game uses the core

- The core is a git submodule at `addons/dnd_core` (`.gitmodules` url
  `https://github.com/ashwinmahesh/DungeonsAndDragonsGameEngine.git`). Its files keep their folders, so the engine is
  `res://addons/dnd_core/rules`, `.../combat`, `.../story`, the data `res://addons/dnd_core/data/<folder>`, the test
  runner `res://addons/dnd_core/tests/test_runner.tscn`.
- **Autoloads** are the core's scripts, named in the game's `project.godot`. Curse of Strahd's list, in this order:

  ```
  PatchLoader="*res://addons/dnd_core/core/patch_loader.gd"
  ErrorWatch="*res://addons/dnd_core/core/error_watch.gd"
  EventBus="*res://addons/dnd_core/core/event_bus.gd"
  Dice="*res://addons/dnd_core/core/dice.gd"
  GameState="*res://addons/dnd_core/core/game_state.gd"
  SaveSystem="*res://addons/dnd_core/core/save_system.gd"
  SceneRouter="*res://addons/dnd_core/core/scene_router.gd"
  ModeController="*res://addons/dnd_core/core/mode_controller.gd"
  Audio="*res://addons/dnd_core/core/audio.gd"
  UiFeel="*res://addons/dnd_core/ui/common/ui_feel.gd"
  ```

  PatchLoader must stay first: it loads a release patch before anything else reads a script.
- **Shader globals** the look needs in `project.godot` `[shader_globals]`: `look_soft`, `world_wet`, `world_snow`,
  `world_time`, `world_sky`, `see_window`, `see_window_eye`. Copy the block from Curse of Strahd's `project.godot`.
- **Rendering settings** Curse of Strahd uses (copy them): Forward+ on desktop and Mobile on iOS, MSAA 2x and screen
  space AA, soft shadow filter quality 4, an 8192 positional shadow atlas (2048 on iOS), 3D scale 0.75 on iOS, and
  `textures/canvas_textures/default_texture_filter=0`.
- **Two data roots.** `Compendium.shared()` loads `addons/dnd_core/data` and then `res://data`; a game entry replaces a
  core entry with the same id. `Compendium.data_files(folder)` lists a folder across both. Python tools use
  `tools/data/dataroots.py`.
- **Two art roots.** `ArtPaths.of(rel)` looks in the game first (`res://<rel>`), then the core; a game replaces a core
  picture by putting one at the same path. `ArtPaths.json(rel)` merges a core table with the game's, key by key (the
  effects, creature looks, texture, prop and model manifests).
- **The campaign plugs in through `data/campaign.json`:**

  ```json
  {
    "module": "res://story/<your>_campaign.gd",
    "look": "res://world/look/<your>_look.gd",
    "bug_reports": {"vault": "Documents/<your vault folder>", "env": "<YOUR>_BUG_REPORTS"}
  }
  ```

  The same file holds the campaign's settings (level cap, calendar, reading, travel map art, weather file, arena fight,
  title): see [../reference/contracts/campaign.md](../reference/contracts/campaign.md). Read it through
  `Campaign.config()`, never with a reader of your own.
  `CampaignModule` (`story/campaign_module.gd`) is the story engine's hook: the reshuffle reading (`reading draw|read|give`
  dialogue statements), the villain's attention and visits, field oracles, endings, the parley before a final battle,
  treasure spots, fight barks, scouting spells, achievements. Its base class does nothing, so a game that overrides
  nothing still runs. `CampaignLook` (`world/look/campaign_look.gd`) is the world builder's hook for set pieces a
  campaign owns (Strahd's castle walls, the Amber Temple's amber, the faceless god); its base builds none.
- **Tests.** The core's runner runs the game's `tests/unit` and `tests/integration` and the core's own `tests/unit`.
  The runner needs the host's autoloads, so the core's tests only run inside a game.

## 3. The host contract: files the core reads from the game

Paths are `res://` in the game. **Hard** means the core preloads it, so the game does not compile without it.

| File | Hard? | What it is |
|---|---|---|
| `art/palette/palette.png` | hard | The palette strip the screen pass and Classic snap use (`Look`). Built by `make palette` from `palette.json`. |
| `art/palette/palette.json`, `art/palette/ui_palette.json` | read at start | Every world colour by name, and the menu-only colours. `Look.color(name)` asserts the name exists. |
| `art/plants/cards.png` | hard | The plant card atlas (`Flora`). Also `art/plants/cards.json`, `flora.json`, `manifest.json`. |
| the travel map's painting | yes | `travel_map` in `data/campaign.json` (default `art/ui/map/barovia.png`, the first game's). |
| `data/campaign.json` | yes | Module, look, bug report folder; optional settings read through `Campaign.config()`: `camera.pitch` (degrees down, default 40), `camera.free_turn` (any heading, default quarter turns), `finishes` (default Modern and Classic), `toon` (the Toon finish's settings), `ground_roll` (rolling open ground, default none). |
| `data/campaign.json`: the story's settings | no | The level cap, calendar, reading, travel map, land name, weather file, arena fight and title ([../reference/contracts/campaign.md](../reference/contracts/campaign.md)); each defaults to the first game's. |
| `art/atmosphere/moods.json` | yes | Every place's mood: light by time of day, mist, grade, water, weather, ground tints ([../reference/art/atmosphere.md](../reference/art/atmosphere.md)). |
| `art/vistas/vistas.json` | yes | What shows past the map edge when the camera tilts up. |
| `art/sprites/props/catalog.json` | yes | Set dressing: props, containers, doors, exits by model or id. |
| `art/ui/title_backdrop.png` | soft | Title and skirmish backdrop. |
| `art/sprites/villager/walk.tres` | soft | The gray-box fallback walker. |
| `art/portraits/`, `art/busts/`, `art/cutscenes/`, `art/creator/`, `art/sprites/lying/` | soft | The game's people and pictures (looked up through `ArtPaths`). |
| the reading's deck and card art | soft | `reading.deck` (a data folder) and `reading.art` in `data/campaign.json` (`ReadingDeck`). |
| the weather file | yes | `weather` in `data/campaign.json` (default `data/weather/barovia.json`): climates per region (`story/weather.gd`). |
| `data/progression/xp.json`, `data/progression/chapters.json` | yes | XP awards; the save screen's chapter list. |
| `data/treasure/levels.json` | yes | Treasure by place and level. |
| `data/ai/profiles.json` | yes | AI behaviour profiles, boss wanted items. |
| `data/camp/night_visitors.json`, `data/schedule/` (optional), `data/loading/cards.json`, `data/glossary/terms.json`, `data/busts/facing.json`, `data/achievements/`, `data/cutscenes/` | yes | Camp visitors, townsfolk routines, loading tips, the glossary, bust facing, achievements, cutscenes. |
| `narrative/` | yes | Every `.dialogue` file; `narrative/combat/barks.json` (battle cries) and `bosses.json` (who counts as a boss). |
| `audio/voice/` | soft | Voice clips by speaker and text hash ([../reference/adr/0013-voice-over.md](../reference/adr/0013-voice-over.md)). |
| `scenes/main_menu.tscn`, `scenes/game.tscn`, `scenes/combat/arena.tscn`, `scenes/skirmish.tscn` | yes | Thin scene roots the router changes to. |
| `tests/saves/` | for tests | Golden saves every test run loads. |

## 4. What is still Curse of Strahd's in the core

Fixed on 2026-10-30 (the second game's engine wave 0): the travel map's painting, the land's name, the weather file,
the main travel file, the arena's fight, the reading's deck, card art and reader, and the error report's title are
campaign settings (section 2), each defaulting to the first game's; the level cap and the calendar are settings too;
the touch controls name no game class (anything exploring with a `view` works), a game may have no `data/schedule/`,
and `vistas.json` needs no `castle` or `lake`; `LongRest.STRAHD` and `waits_on_strahd` are `VISIT` and
`waits_on_visit` (the old names stay as aliases); the engine's own tests no longer need the first game's content. The
user data folder stays in `project.godot` (`config/name`, `custom_user_dir_name`): Godot reads it before any script.

1. **Campaign names left in engine code**: the guard baseline counts about 115 code lines in 40 files that still name
   Strahd's people or places (comments are skipped), for example `combat/ai/boss_brain.gd`, `story/story_state.gd`,
   `story/story_conditions.gd`, `rules/data/compendium.gd`, `combat/item_powers.gd` (the relics). Most are behaviour
   for Curse of Strahd items or entries that sit behind data; a new game that never uses those ids is not affected,
   but each one is a place where the engine knows a campaign. Copy the guard test into the new game with its own
   baseline from day one, so the count can only fall.
2. **Implicit assumptions** the audit flagged and did not check: a party of four, the 5 ft grid. If the new game
   differs, audit these first. (The level cap and the calendar are settings now.)

## 5. Starting the new game, step by step

1. **Make the repo** on GitHub (the owner creates it), with Git LFS on (`git lfs install`) and a `.gitattributes` that
   puts new images, voice clips and sound clips in LFS from the first commit.
2. **Add the core**: `git submodule add https://github.com/ashwinmahesh/DungeonsAndDragonsGameEngine.git addons/dnd_core`,
   then `git submodule update --init` in every clone and lane. A fresh submodule has no Git LFS filter: run
   `git lfs install --local` inside `addons/dnd_core`, then `git lfs pull` there, or its models and textures stay
   pointer files. A lane script that makes worktrees must do the same for each lane's core (or borrow the main
   checkout's LFS objects), or a new lane's engine art is pointers.
3. **Copy the tooling** from Curse of Strahd and rename `strahd` in it: `Makefile`, `tools/run_tests.py`,
   `tools/check.py`, `tools/lint_gd.sh`, `tools/logcheck.sh`, `tools/godot_slot.sh`, `tools/import.sh`, `tools/godot`
   and `tools/macos/nofocus.m`, `tools/lane.sh`, `tools/edge/`, `tools/lfs_quiet.sh`, `tools/git/pre-push` (`make hooks`),
   `tools/data/` (validators and lints), `tools/capture/capture.tscn` and the preview scenes you need, `tools/perf/`,
   `tools/art/` and `blender/` (the image, sprite, texture, prop and icon pipelines), `tools/audio/` (voice),
   `tools/wiki/` if you want a wiki, `tools/release/` and the workflows when you ship. Copy the guard test too.
4. **Write `project.godot`** with the autoloads, shader globals and rendering settings of section 2.
5. **Write the campaign plug**: `data/campaign.json`, a `CampaignModule` subclass (start empty), a `CampaignLook`
   subclass (start empty).
6. **Bring the host files** of section 3: a palette (`art/palette/palette.json` and `ui_palette.json`, then
   `make palette`), moods, plant sets, vistas, the props catalog, the travel map art, the scene roots. Start from
   Curse of Strahd's files and change them: this is where the new world's colours and air live (see
   [../design/hd2d_look.md](../design/hd2d_look.md) section 4).
7. **Write `CLAUDE.md`** from [claude_md_template.md](claude_md_template.md), and keep the design principles and this
   handbook as the agents' reading list.
8. **Prove it boots**: `make smoke` (headless boot), then a gray-box room with a placeholder party, then the first
   fight on the arena. Phase 0 of Curse of Strahd ended exactly there.
9. **Set the guards on day one** ([testing.md](testing.md)): layout test, golden saves, flag and dialogue lints,
   fight series with bands, the fight-spread test, failed-roll and stuck-quest lints, portraits for every monster,
   eight directions for every sprite, the guard test.

## 6. Changing the engine from a game

- Edit inside `addons/dnd_core`, commit there (the owner is the only author), and then commit the new submodule
  commit in the game (its path shows as the change). Curse of Strahd's commit messages read "...: the submodule moves
  to the core commit, with the tests".
- **Order matters when pushing**: push the core commit to the core's main first, then the game commit that records it.
  A game commit that points at a core commit nobody pushed breaks every other clone.
- A core change is an engine change for **every** game on it. Before pushing a behaviour change, run the core's unit
  tests and each game's own suite (the fight series move when rules move). A rule that only one game wants goes in
  that game's data or module, or behind a setting that defaults to today's behaviour.
- Per-creature or per-campaign facts go in data or the module, never in `rules/`, `combat/` or the story engine files.
  A new stat goes into the modifiers contract and the engine together, never only in data
  ([../reference/contracts/modifiers.md](../reference/contracts/modifiers.md)).
- Engine departures from the rules are engine-wide: they are written down in the deviations table
  ([../reference/rules/deviations.md](../reference/rules/deviations.md) is today's snapshot).
- A change to what a save holds bumps `GameState.SAVE_VERSION` and adds a `SaveSystem.upgrade` step; every game's
  golden saves must still load. Tell the owner before any save version bump.
- A creature's art: a creature from the core's data keeps its sprites and portraits in the core
  (`tools/art/route_to_core.py` moves them after `make sprite`, `make anims` or `make portrait`); a game's own heroes,
  NPCs and villains keep theirs in the game.

## 7. Licensing

- The core's code is MIT (`LICENSE`). Its data holds mechanics from Wizards of the Coast books beyond the SRD, which
  the MIT license does not cover; `NOTICE.md` has the SRD 5.2.1 attribution (CC BY 4.0) and the fan-project notice. The
  owner made the repo public on 2026-10-26 knowing that (his option C, against the advice to publish SRD-only data).
- Curse of Strahd's original art and dialogue are CC BY 4.0 (its `LICENSE-CONTENT.md`); voices, third-party music,
  sounds, icons and fonts keep their own licences ([../assets/THIRD_PARTY.md](../assets/THIRD_PARTY.md)).
- **CC BY credits travel with the file**: icons (game-icons.net, CC BY 3.0, per-author credits), sound packs (CC BY
  3.0/4.0, OGA-BY) and fonts (OFL licence files must ship). The Credits screen reads them.
- **Generated assets' terms for public redistribution were never checked** (Gemini images, Veo/Gemini video,
  ElevenLabs voices and sounds). Keep generated character art, voices and music out of the public core.
- **Public repos still bill Git LFS** storage and bandwidth to the owner's account. Heavy campaign art stays out of
  the core; the core's own heavy kit is in LFS.
- A new world built on SRD-only rules and original lore avoids the Wizards of the Coast question for its own content.
