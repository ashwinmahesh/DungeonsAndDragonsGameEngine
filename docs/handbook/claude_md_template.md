# A CLAUDE.md for a new game on this engine

The agent rules file at the root of a game repo is what every thread reads first, so it carries the rules that must
never be relearned. This template is Curse of Strahd's CLAUDE.md (game main `ef29e6278`, 2026-10-29) with its
campaign facts taken out. Copy the block below into the new game's `CLAUDE.md`, replace every `<...>`, and delete
any line whose tool the new game hasn't copied yet. Keep it under about 200 lines: it is read on every turn.
Longer guidance belongs in docs and is linked from here.

---

```markdown
# <Game title> — agent rules
Godot 4.7.2 (typed GDScript) · Blender 5.2 · <OS and machine the owner builds on>
Plan: <path to the plan in the owner's vault> (status updates are fine; scope changes go through the project's
coordinator)
Build logs for the owner: <vault folder> ("Build Log NN - <title>.md")
Bug reports from the owner (F12 or the pause menu in dev builds): <vault folder>/Bug Reports/<date>T<time>-<title>/
with report.md (front matter `status: open`), screenshot.png, save.json
Decisions: docs/adr/ · Tasks: docs/tasks/ · Rules coverage: docs/rules/coverage.md
Engine handbook: addons/dnd_core/docs/README.md (process, testing, pipelines, gotchas, the look)

## Commands (add new ones to the Makefile)
make run (the edge build) | run-main | test [ONLY=substr FILES=a.gd,b.gd JOBS=n] | golden-saves | validate | lint |
check [DRY=1] [DEPTH=n] | ci | capture [SCENE=… NAME=… FRAMES=…] | smoke [SCENE=… FRAMES=n] | lfs-quiet | palette |
art-spend | voice [SPEAKER=… DRY=1 MAX_USD=n] | sprite TURNAROUND=<png> ID=<id> | anims [ONLY=…] [GENERATE=1] |
portrait SRC=<png> ID=<id> | textures | prop SRC=<png> ID=<id> HEIGHT=<units> | props | ui_art | icons
The engine is the git submodule addons/dnd_core (public repo DungeonsAndDragonsGameEngine): after a fresh clone or a
lane, `git submodule update --init`; to change it, edit and commit inside addons/dnd_core, push the engine first, then
commit the new submodule commit here (its path shows as the change).

## Godot windows (the owner works on this machine)
- Never open a Godot window that can take focus or cover the owner's work. Checks without pixels run headless
  (`make test`, `make smoke`); screenshots only through `make capture`, which draws off screen. Batch screenshots.
- Any other windowed Godot run goes through `tools/godot` (it stops Godot activating itself).
- At most <3> import editors and <8> headless test processes run at once across all lanes (tools/godot_slot.sh,
  tools/run_tests.py). The build lane keeps part of that for itself (`BUILD_LANE=1`, only the build thread sets it).
  A run past the cap waits its turn and says so; it isn't stuck.
- `make run` is for the owner to play: run it only when asked.

## Code
- Static types everywhere; `untyped_declaration` is an error.
- The engine's `rules/`, `combat/` and story engine are pure libraries: no nodes, scenes, autoloads or UI. They take
  a DiceRoller argument. Scenes and the HUD only show combat and send it commands.
- Every die roll goes through DiceRoller (Dice.roller in game code). Cosmetic randomness uses its own RNG.
- The player controls every party member and guest; AI only drives enemies and neutrals.
- Scenes are built in code; .tscn files are thin roots. 1 world unit = one 5 ft square.
- After adding a class_name, `make import` before `make test`.
- A change to what a save holds bumps `GameState.SAVE_VERSION` and adds a `SaveSystem.upgrade` step; then
  `make golden-saves` adds the new version's saves beside the old ones in tests/saves, which every test run loads.
- Campaign facts reach the engine through `Campaign.module()` (this game's module is named in data/campaign.json) and
  set pieces through `CampaignLook`; per-creature or per-campaign facts go in data or the module, never in the
  engine's files. tests/unit/test_engine_names.gd fails when an engine file gains a campaign name.
- A lane's folder: `make lane NAME=<name> BRANCH=<branch>` (clones of the main checkout's files and import cache);
  `make lane-done NAME=<name>` once merged. Never write into the main checkout, and clean up your own folders.

## Rules engine
- Data is read through `Compendium.shared()` (the engine's data root and this game's; a game entry replaces the
  engine's of the same id). Modifiers follow the engine's modifiers contract: add a stat to the contract and the
  engine together, never only in data. Every number the UI shows is a `Breakdown`.
- A character is its `build` (keyed choices); `refresh()` derives the rest. The UI never computes rules.
- Rules source: <the rule books in use and the licence decision>. Rule deviations go in docs/rules/deviations.md; a
  rule is "done" only when coverage.md says so. `make validate` checks both docs against the data.
- Data `text` and `summary` are our own words, never copied.

## Art
- Colours only from art/palette/palette.json, plus art/palette/ui_palette.json for menus (via Look); run
  `make palette` after editing the lists.
- Images: <image model> via tools/art/generate.sh only; provider and model pinned in art/manifest.json. Ask for a
  plain flat white background; the pipeline removes it. Every call is counted in the spend ledger; a tool that stops
  at its limit reports to the coordinator instead of overriding.
- Asset packs from the internet: CC0 or clearly free licences only, kept untouched with their licence in
  art/sourced/<pack>/, listed in the licences doc, each download after the owner's typed yes. Credit every artist.
- Characters come from the image pipeline so the style stays consistent. Every character sprite walks and attacks in
  8 directions (a test checks).
- Set dressing comes from the props catalog; never fall back to plain boxes for new content.
- UI draws on CanvasLayers so the palette pass never touches it.
- Git LFS for new or changed images, voice and sound clips under <paths>. Never `git lfs migrate` or
  `git add --renormalize`; stage only files you changed (`make lfs-quiet` clears timestamp noise).

## Voice and dialogue
- Spoken lines: <voice service> via `make voice` only; model, format and each speaker's voice pinned in
  audio/voice/casting.json, each line's delivery in audio/voice/directions.json. A clip is keyed by its text, so
  editing a voiced line silences it until it is voiced again.
- New or rewritten dialogue is drafted by <model> through the owner's ai-bridge (read its skill file), never with an
  API key; don't start or restart the bridge. Keep the brief and the raw reply in docs/plans/.
- Every Narrator line follows the Narrator's rules (second person, present tense, one or two sentences, no game terms,
  no unearned facts; the engine's docs/design/narration.md) and the game's own voice guide for its persona.

## Keys and the owner's files
- Never ask for, store or echo a key. Tools read keys from the owner's environment and send them as headers.
- Never touch the owner's saves or settings; read a save read-only when a lane needs it.

## Done means
- Hand off with `make check` green and a clean log: lint, a compile of every script, make validate when data,
  dialogue or the rules docs changed, and the test files you added or changed, never the whole suite. Run the tests
  your change is about with `make test FILES=...` while you work. The build thread runs the full suite once per batch.
- A new screen or panel goes into tests/integration/test_layout.gd.
- Never push main: push your own branch, if anything. Only the build thread pushes main, with STRAHD_PUSH_MAIN=1 (or
  the new game's variable); the pre-push hook `make hooks` installs refuses anyone else.
- Commits: the owner is the only author. No co-author, session or "generated with" lines, in any commit.
- A capture for anything visual. Never weaken tests to pass. Never mark an owner sign-off as passed.
```

---

## Why each section is there

- **Godot windows** exist because the owner works on the machine the agents use; a window that steals focus
  interrupts him, and too many Godot processes swapped a 24 GB Mac to a standstill.
- **Code** is the engine's architecture in eight lines; breaking any of them breaks headless tests or old saves.
- **Rules engine** keeps the rules explainable and the departures written down.
- **Art** and **Voice and dialogue** keep one style, keep spending visible and approved, and keep licences clean.
- **Done means** is what the builder relies on to batch hand-offs safely.

See [orchestration.md](orchestration.md) for the process these rules serve and [testing.md](testing.md) for the
checks.
