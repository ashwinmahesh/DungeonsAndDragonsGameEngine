# DungeonsAndDragonsGameEngine — agent rules

The engine core for D&D 2024 games in Godot 4.7.2 (typed GDScript). It is used as the git submodule
`addons/dnd_core` of a game (first Curse of Strahd), so every path in a game is `res://addons/dnd_core/...`.
Start with docs/README.md: it lists the handbook (how a new game starts, how the work runs, testing, pipelines,
gotchas, the look) and the reference docs.

## Where you work
- Edit the engine inside a game's checkout (`<game>/addons/dnd_core`), where its tests can run: the test runner
  needs the host game's autoloads (Dice, GameSettings, GameState, ModeController, SaveSystem and the rest).
- Commit here first, push the engine, then commit the new submodule commit in the game. Run the engine's tests and
  the game's `make check` (the game's tooling runs both; a new engine commit makes it run the full suite).
- The game's tools (Makefile, tools/, blender/, CI) are in the game repo, not here.

## What belongs here
- Anything a different D&D game could reuse: rules, combat, the story engine core, the data of the rule books, UI,
  world and look code, shaders, effects, icons, fonts, sound effects, generic textures, models and monster art.
- Nothing that names a campaign. Campaign facts reach the engine through `CampaignModule` (story/) and set pieces
  through `CampaignLook` (world/look/), both named in the game's `data/campaign.json`; per-creature or per-campaign
  facts are data. The game's guard test fails when an engine file gains a campaign name.

## Code
- Static types everywhere; `untyped_declaration` is an error.
- `rules/`, `combat/` and the story engine are pure libraries: no nodes, scenes, autoloads or UI. They take a
  DiceRoller argument and compile standalone (the game's `make lint`).
- Every die roll goes through DiceRoller. The player controls every party member and guest; AI only drives enemies
  and neutrals. 1 world unit = one 5 ft square.
- Modifiers follow docs/reference/contracts/modifiers.md: add a stat to the contract and the engine together. Every
  number the UI shows is a `Breakdown`.
- A change to what a save holds is the host's `GameState.SAVE_VERSION` bump plus an upgrade step and new golden saves.
- A change that moves `res://` paths or project settings costs players a full download: batch it into a planned
  release, with the owner's typed yes.

## Data and licences
- Code is MIT (LICENSE). The data holds rules mechanics of the books under the fan-project notice in NOTICE.md; text
  and summaries are our own words, never copied.
- New textures, prop sprites and `.glb` models go through Git LFS (.gitattributes); never `git lfs migrate` or
  `git add --renormalize`. Keep heavy campaign art, voice and music out of this repo.

## Commits
- The owner is the only author. No co-author, session or "generated with" lines in any commit, merge or fixup; use
  the repository's configured identity.
- No secrets, keys or paid-account details in anything committed: this repo is public.
