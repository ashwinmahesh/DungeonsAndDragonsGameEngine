# Testing playbook: what to run, and when

Written 2026-10-29 from the Curse of Strahd game's Makefile, `tools/check.py`, `tools/run_tests.py`, the builder's
runbook and its CI notes. Commands are the game's (the tooling lives in the game repo, not here; a new game copies it,
see [new_game.md](new_game.md)). Dates are 2026.

---

## 1. The test system

- **An in-house runner, no third-party addon** (ADR 0001, [reference/adr](../reference/adr/)). It lives in this repo
  (`tests/test_runner.tscn`) and runs headless Godot. It needs five autoloads from the host (Dice, GameSettings,
  GameState, ModeController, SaveSystem), so the engine's tests run from inside a game.
- **Where tests live.** The game's `tests/unit/` and `tests/integration/`, plus this repo's `tests/unit/`. The runner
  finds both. In Curse of Strahd that was about 170 game unit files, 330 integration files and 150 engine unit files:
  about 3,700 tests.
- **Any script error fails the run**, even when every test passes: `SCRIPT ERROR`, `ERROR:`, `Parse Error`,
  `Failed loading` or a GDScript warning in the log (`tools/logcheck.sh`). A script that fails to compile can't hide
  behind a green count. ObjectDB leak warnings at exit are fine.
- **Parallel processes** (`tools/run_tests.py`): several headless Godot processes take files from one list, longest
  first, and a file longer than half a process's share goes out a test at a time. `JOBS` defaults to what the idle
  cores and free memory allow (about 1.5 GB a process), between 2 and 8.
- **Slots on a shared machine.** At most 8 test processes and 3 import editors across every checkout at once; the
  builder keeps 5 of the test slots and 1 import slot for itself (`BUILD_LANE=1`). A run past the cap waits and says
  so. The owner's play launches skip the cap.
- **Headless only.** Nothing a test or a lane runs may open a window that takes focus. Screenshots come from
  `make capture`, which draws off screen.

## 2. What to run, by moment

| Moment | Run | Notes |
|---|---|---|
| While working | `make test FILES=a.gd,b.gd` | Bare file names. A path runs the whole suite. `ONLY=substr` runs files whose name holds it |
| After adding a `class_name` | `make import`, then the tests | Godot learns class names on import |
| Before every hand-off | `make check` | The quick check (owner, 10-07): lint, a compile of every script, `make validate` when data, dialogue or the rules docs changed, and the test files the branch added or changed. Never the whole suite. `DRY=1` prints the plan and its test time |
| When the change is wide | `make check DEPTH=1` (or 2, or `all`) | Also runs the tests that use what changed, by script distance. Depth 1 was about half the suite's time on typical hand-offs, depth 2 nearly all of it |
| A change to the Makefile's test targets, `project.godot`, the test runner, or a new engine commit | `make check` runs `make ci` by itself | These reach everything |
| A change to what a save holds | Bump `GameState.SAVE_VERSION`, add a `SaveSystem.upgrade` step, then `make golden-saves` | Adds the new version's saves beside the old ones; every run loads all of them. Tell the owner before a save version bump |
| A new screen or panel | Add it to `tests/integration/test_layout.gd` | Fails on text or buttons spilling out of their boxes |
| Anything visual | `make capture SCENE=... NAME=...`, before and after | Batch shots into few runs. Check both finishes for world art |
| The builder, once per batch | The tier the batch needs (part 3) | One run for the whole batch, then bisect a failure |
| Before a release | Full `make ci` on the hash being released | The release workflow builds main's head at dispatch |

`make ci` is `make validate`, `make lint` and `make test`. On the owner's Mac mini it took 5 to 12 minutes at `JOBS=8`
and up to an hour at `JOBS=4` beside other runs. Start a long run detached (its own session, a log with start and exit
lines) so a restart of the agent's session can't kill it.

## 3. The builder's tiers

Choose by the riskiest branch in the batch.

| Tier | For | Runs |
|---|---|---|
| **Quick path** | Audio, art, data-only, docs, wiki, tools | `make validate`, `make check`, the data checks, and the area's tests (voice: `test_voice_over`, `test_audio`, `test_data_integrity`, `test_scripts_compile`) |
| **Small code** | A fix in exploration, dialogue, quests, UI, cutscenes | The quick path plus the phase exit playthroughs, story continuity, side quests, side-quest bosses, night visitors and cutscenes (and voice-over for voiced dialogue), plus the tests that overlap the change |
| **Full CI** | Combat, targeting, enemy AI, the rules engine, the encounter or combat view, a new engine commit | `make ci` |
| **No tests** | Sprite and video animation branches that only add art | Merge, then check every image is an LFS pointer with its object present |

## 4. What the guards catch

| Guard | What it catches |
|---|---|
| `make validate` | Data against its schemas, cross-file references (every id a file names exists), implemented-vs-declared checks, and the rules docs against the data |
| `make lint` | The engine's `rules/`, `combat/` and `story/` compiled standalone: an autoload reference there fails, keeping them pure |
| `test_scripts_compile` | Every script in the project compiles with the autoloads present |
| `test_data_integrity` | Data the game reads at run time is whole |
| `test_engine_names` (game repo) | An engine file gaining a campaign name; its baseline only shrinks |
| `test_layout` | Text or buttons that spill out of any screen, at the sizes the game supports |
| `test_golden_saves` | Every save from every old version still loads |
| Phase exit tests, the story bot, `test_storyqa_continuity` | The campaign walked through the real scenes to each ending; a broken door, path or conversation |
| `test_story_fights`, `test_side_quest_bosses`, `test_scaled_*`, `test_fight_spread` | Every fight played by an autopilot party over fixed seeds (part 5); fights start spread out |
| `test_spell_sweep` | Every combat spell changes the fight (a spell that does nothing is a bug) |
| `test_strahd_presence`, `test_tutorial_session` | UI flows that block each other: loot windows, rest screens, camps |
| Flag, dialogue, stuck-quest and failed-roll lints | A flag read but never set, set but never read, or not registered; a conversation without its exit; a quest that can't finish; a quest that dead-ends when every roll fails |
| `test_directional_sprite`, `test_icons`, `test_cutscenes`, `test_set_dressing` | Every sprite in 8 directions; every icon credited; every cutscene at least two pictures; every prop has its art |
| `test_atmosphere`, `test_region_looks`, `test_indoor_looks` | Moods name palette colours and known weather; every region and indoor place keeps a look of its own |
| `test_voice_over` | Every voiced line has its clip (needs the LFS clips present) |

## 5. Fight series and balance

- **A fight series** (`FightSeriesCase` in the game's `tests/support/`) plays one fight on seeds 1 to 8 with the four
  pregens on `PartyAutopilot` (core `tests/support/party_autopilot.gd`), and prints a line per fight: "X/8 won, the
  average rounds, the party members dropped per fight". The series are deterministic: when a count moves, something
  real changed (AI, flanking, weather, a rule).
- **What a series asserts**, and these do hold a push: every fight finishes within 30 rounds (a "timeout" outcome
  fails); every fight is won at least once in 8 (the "can be won" guard; a fight the owner accepted as winless for that
  party sets `winless_ok` and says why); every creature's Hit Points stay in range. Fights a conversation starts set
  `speakers_step_aside`, so the speakers move off the squares the fight needs, as the real conversation does.
- **The autopilot's three levels**: plain, sharp (the default: smite, Spirit Guardians, Fireball on two) and full
  ability (adds heals, Lay on Hands, Sacred Weapon, Bless, Hunter's Mark, Conjure Barrage and more). The fights in
  `BOSS_FIGHTS` always play at full ability. For a run, `AUTOPILOT_SHARP=0` plays plain, `AUTOPILOT_FULL=1` plays
  full ability everywhere, and `AUTOPILOT_OFF=radiance,cone,...` switches single parts of full play off to measure
  what each adds. What each level does and why is in
  [design/game_design_principles.md](../design/game_design_principles.md) section 3.7.
- **Eight seeds are noisy**: one or two wins either way means nothing. Use 16 seeds before reporting a number that
  decides anything.
- **`test_fight_stalls`** keeps fights from stalling: a foe with no way to the party gives up after two turns (a
  legendary one never does), hidden foes and heroes get searched for, and no foe plans around an area action a wall
  blocks.
- **Targets the owner set:** ordinary fights won about 5 times in 8 (10-13), last 2 to 3 rounds and 4 at most
  (10-24); bosses were held at 3 in 8 (10-14) until difficulty moved to "hit harder, not more HP" (10-23/24). Both
  rollbacks (Hit Points 10-24 and 10-26, line-ups 10-25) left the stored counts stale; nothing is re-measured unless
  the owner asks (10-25).
- **Fight outcomes don't hold a push** (10-19). When a rule change moves a win rate, the expectation follows the
  measured value and the change is reported. What does hold a push: a crash, a script error, or a fight that can't
  end.
- **Report the "X/8 won" lines** to the coordinator when anyone tunes balance. `make balance` plays one fight 20 times
  per difficulty mode; `make xp-sim` prints the party's level at every story gate under XP levelling.
- **Tune against a real party**: the reference party (`reference/rules/reference_party.md`) and, read-only, the
  owner's own save.
- **The bots are path-sensitive.** Never move an existing walkable square, spawn point, exit or fight start; extend a
  map, don't redraw it.

## 6. Reading a red run

- **Rerun the failing file alone before blaming a branch.** Past flakes: a ground-relief timing check, the screen pulse
  under heavy load, a wall-clock assertion, an exit sign's triangulation, a narrator portrait race. Each was guarded or
  fixed; a new one goes on the list.
- **"Stopped during <file> (exit code 0)" with no failure is a silent hang** until the runner's `--quit-after`
  (about 12 minutes). The cause seen: a test left the SceneTree paused, and the next test's effect timers never fired.
  Tests must leave the tree as they found it.
- **Find the branch** by building each suspect alone on main and running the file.
- **Compare with main.** Keep a list of tests already red on main (in late October six were: interiors, portrait
  grounds, vistas, battle objects, skirmish, visual lights; a lane fixed them on its own branch). A red that main
  shares is not the branch's.
- **Never weaken a test to make it pass.** Changing what a test expects needs the owner's yes when it changes what the
  test protects (he approved two such edits by name on 10-28: the skirmish every-map test skipping maps too small for
  its line-up, and a painted-light count from 17 to 18).

## 7. Where tests run

- **On the build machine.** Cloud containers were measured on 10-07: 4 cores and 16 GB, the first import about two
  hours (a thousand texture sheets compressing on one core), `make ci` no faster than the loaded Mac, one sprite test
  out of memory at 6.7 GB, and the voice test failing without the LFS clips an anonymous clone lacks. Don't move tests
  to the cloud unless something changes.
- **Importing is the slow part.** A lane clones the main checkout's import cache; a full import with under 20 GB free
  is refused. Textures import two to three times faster with a hidden editor window than headless.
- **Engine changes run both suites.** Commit in the submodule, run the engine's tests and the game's `make check`
  (which picks up the engine's changed tests), and expect `make ci` for the submodule bump.
