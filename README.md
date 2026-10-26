# DungeonsAndDragonsGameEngine

Core for D&D 5e (2024) games made in Godot 4.7: the rules engine, grid combat and AI, the story engine core
(state, dialogue, quests, rests, travel), the data schemas, the Compendium data (classes, subclasses, species,
backgrounds, feats, spells, items, magic items, monsters, conditions) and the test framework.

Used as a git submodule at `addons/dnd_core` by the Curse of Strahd game (docs/plans/engine_split.md there). The files
keep their folders (`rules/`, `combat/`, `story/`, `data/`, `tests/`), so inside a game they are at
`res://addons/dnd_core/...`. The core is edited in that checkout and committed here; the game then records the new commit.

- The host game provides the autoloads the engine and the test runner use (Dice, GameSettings, GameState, ModeController,
  SaveSystem, EventBus, Audio ...), its own `data/` (locations, NPCs, quests and the rest of its content, beside the core's
  rules data) and `data/campaign.json`.
- `Compendium` reads two data roots: the core's own `data/` and the game's (a game entry replaces a core entry with its id).
- The runner, `tests/test_runner.tscn`, runs the game's tests and the core's own unit tests (`tests/unit`).
- The story engine names no campaign: a game supplies a `CampaignModule` (story/campaign_module.gd) named in
  `data/campaign.json`.
- Data holds rules content of the books only; a game keeps its own entries (its monsters, items) in its own `data/`.
- Licence: the code is MIT (LICENSE). The data also holds mechanics from Wizards of the Coast books beyond the SRD, which
  the MIT license does not cover; see NOTICE.md for the SRD 5.2.1 attribution (CC BY 4.0) and the fan-project notice.
- The design principles (`docs/design/game_design_principles.md`) are the reference for games built on the engine.
