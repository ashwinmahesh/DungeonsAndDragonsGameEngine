# Gotchas we ran into

Written 2026-10-29 from the Curse of Strahd build logs, the builder's runbook, the QA findings lists, the engine split
hand-offs and the release threads. Each entry is what happened and what to do instead. Grouped by where it bites.
Dates are 2026.

---

## Godot

- **A new `class_name` is unknown until an import.** Run `make import` (or `make check`, which imports) before the
  tests, or every file that uses it fails to compile.
- **Godot writes files you didn't ask for.** It creates a `.uid` beside every script; commit them with the script.
  An untracked `.uid` that a branch also adds makes `git merge` fail with an empty conflict list. Godot's `.import`
  files are git-ignored, so new art's `.import` files must be force-added. The editor rewrites `project.godot` on exit
  (the hidden-window import puts it back).
- **Imports are slow and big.** A first import of the full game took about two hours on 4 cores and wrote an 8 GB
  cache. Clone an existing cache instead (lanes do), refuse a full import with under 20 GB free, and after an external
  drive drops, look for a stale `.godot/import.lock` and a modified `project.godot` in every checkout.
- **Never let a Godot window take focus** on the owner's machine (2026-10-06). Tests run headless; screenshots draw
  off screen; any other windowed run goes through a wrapper that stops Godot activating itself.
- **A paused SceneTree hangs the next test.** A test that leaves the tree paused stops the next test's effect timers,
  and the run sits silent until its timeout. Leave the tree as you found it.
- **Mipmaps blur sprites.** A 384 px sheet drawn at about 110 px used a pre-shrunk mipmap and every outline went soft.
  Import character sheets without mipmaps and supersample in the shader.
- **See-through edges off means a black box.** A tree that came back from fading drew a black square behind it because
  its alpha path was switched off too early.
- **Video memory only grows** if every character's sheets stay loaded (about 21 MB a monster, 75 to 90 MB a hero).
  Empty the sheet cache between places.
- **Per-target loops explode.** The AI asked every creature for its modifiers 750,000 times in one fight, freezing
  each enemy turn for up to a second. Read once per turn; check sight lines only on the squares a line crosses.
- **`make test FILES=` takes bare file names.** A path silently runs the whole suite.

## Git, worktrees and LFS

- **Worktrees share refs and the stash.** A `git push origin main` from a lane's worktree once pushed the builder's
  unfinished batch. Hence the pre-push hook and the rule that only the builder pushes main. Never touch `stash@{0}`.
- **Never switch branches in a checkout someone else is running tests in** (a two-hour run was lost), and never move a
  branch ref under a checkout that has it checked out (the index stays on the old tree and a commit there reverts the
  landing).
- **Never rewrite history**: no reset of main, no force-push, no `git lfs migrate`, no bulk `--renormalize`.
- **Phantom modified files.** Old images and clips whose timestamp moved show as modified and would be uploaded to LFS
  if staged. Stage only what you changed; `make lfs-quiet` clears the noise. A `git mv` of an old plain-blob clip keeps
  it plain and it shows as modified everywhere; re-normalise only those paths.
- **Push LFS objects before the branch**, and check each new image is a pointer with its object present.
- **Every worktree with a private copy of the art and the import cache** costs about 13 GB; 33 of them filled the disk
  to zero on 2026-10-08, and a git repack on the full disk left 8.5 GB of half-written packs. Make lanes as clones, and
  remove them when merged.
- **Lanes cut from local main** by default. When local main is ahead of GitHub main (the builder holding a batch),
  cut from origin/main.
- **Squash merges** make the lane cleanup tool refuse (it checks the branch is merged). Check the content is on main,
  then remove the worktree and branches by hand.
- **Never `pkill` by pattern** on a shared machine. Find the run's own process tree by its working directory.
- **The shell is zsh on macOS.** `$h:t` and `$cur:a` are modifiers, so write `${h}:path`; split words with `${=VAR}`;
  there is no `timeout`.

## Data and content

- **Placeholders that ship.** A Phase 5 exit condition left as `"when": "false"` blocked the road to the final castle
  until the owner hit it more than two weeks later; three more exits were the same. Search for literal `false` conditions before a release, and give every
  placeholder a task.
- **Unreachable versions.** A fight version after one with no `when`, or with the same `when` as an earlier one, never
  plays. A quick scan finds them.
- **Things found only by luck.** Several quest items and hidden finds could only be found by a lucky roll or a random
  encounter. Every quest must be finishable with every roll failed (there is a lint for it now).
- **Writing to the player's real files.** The volume sliders wrote the owner's own settings file, even from tests.
  Tests and lanes use their own settings and save folders; never touch the owner's.
- **A finished game overwrote the owner's manual save** (the ending wrote its state over the current slot). An ending
  now writes its own slot. Anything that writes a save must never write over one the player made.
- **Economy leaks.** Half-price scrolls resold for endless gold; ammunition priced 20 times over; a sold attuned item
  kept its slot forever; cursed items escaped their curse by being stashed or sold. Every buy and sell path needs a
  test.
- **Big creatures and walls.** Bigger shapes stood in walls and on neighbours; a big creature's teleport landed half in
  a wall; a cut-short move left a mover in an ally's square. Check every footprint, not the origin square.
- **Reload edge cases.** Reloading a round-start save replayed the first turn; a road fight vanished on load; Continue
  did nothing when the newest save came from a newer build.
- **Everyone at 0 HP outside a fight** was a softlock: no game over and nothing to click. Decide early what happens
  when the whole party is down outside a fight, and test it.
- **Names spelled two ways.** A companion's name was spelled two ways across data, dialogue and voice keys; renaming it
  needed a tool that moves every voiced clip to its new key. Fix spellings early, in a glossary.

## Rules and combat

- **Read the whole spell.** Thunderwave pushed one creature at a time front to back, so a pack blocked itself (push
  farthest first). Spiritual Weapon was a tinted square instead of a weapon on the field, and was wrongly treated as
  Concentration. A sweep test now checks every combat spell changes the fight.
- **Reactions must ask.** Absorb Elements, Counterspell, Shield and the rest were sometimes spent automatically or
  never offered (a Counterspell from a ring never prompted; a monster's Fireball offered no Counterspell). Route every
  reaction through one pipeline that checks who can react and asks.
- **Invisible creatures leak information** if they leave the turn order, can be clicked there, or a blocked move names
  them. Keep them as a dimmed card nobody can click; refuse the move without naming anyone.
- **Enemy area spells** must not catch their own side, and an enemy shouldn't walk away from an adjacent hero into an
  Opportunity Attack when it could just fight.
- **"Boss" needs a definition.** A boss damage bonus keyed to "legendary actions or CR 5+" caught minor vampires.
  An explicit flag on the fight entry is the fix.
- **More HP is not more fun.** Raising monster HP to make fights harder made them long; the owner rolled every monster
  back to its book HP and made them hit harder instead (2026-10-24). Added minions in book fights went the same way
  (back to the book's line-ups, 2026-10-25).
- **Write rulings down.** Flying without altitude, identical monsters sharing an initiative roll, the day being bright
  but not sunlight for vampires: each is a ruling a DM would make. Put every one in the deviations doc the day it is
  made.

## Art and sound

- **Gemini can't make transparency** and adds scenery behind portraits unless told not to. Ask for a flat white
  background (or a named plain colour for portraits) and remove it in the pipeline.
- **Grain from the post pass.** A double-size pixel grid and an ordered dither read as grain; the owner noticed at
  once. Full resolution, no dither.
- **Art that doesn't match the text.** A character written as a man was drawn as a woman, twice; the owner treats
  that as a bug (2026-10-23). Check every portrait and sprite against the character's data.
- **Size reads first.** A creeping hut drawn too small took four commits to settle (a new sprite from a model, a
  revert, the drawn art scaled up, the model standing before the fight). Agree scale with a capture before making art.
- **The right music for the moment.** A lively tavern song played in the villain's castle; audit moods against the
  scenes they play under.
- **Editing a voiced line silences it** (clips are keyed by the text). Add new lines instead, or quote the re-record.

## Releases and machines

- **The release workflow must know about the engine.** After the split, the first 1.0.11 run failed because the
  workflow didn't check out the submodule or fetch its LFS objects.
- **The CDN caches a 404** for a URL asked before its upload; always check a download with a query string.
- **Apple's notary service drops connections** now and then; re-run only the failed job.
- **Any `project.godot` change is a full download** for every player (about 4.4 GB). Batch them.
- **The Mac's permission checks deny pushes and dispatches** that the owner hasn't typed in that thread
  ("Out-of-Place Publication", "Auto-Mode Bypass"). Don't work around them: ask for the line, or give the owner the
  command to run.
- **Cloud containers aren't faster** for this kind of project (measured 2026-10-07), lack the LFS clips on anonymous
  clones, and can't reach the Mac's worktrees. Run tests and Godot on the Mac.
- **The Mac runs hot.** Load 10 to 30 was normal and near 100 at peaks with many lanes; full CI still passed, just
  slower. Caps on test and import processes, and a reserved share for the builder, kept it usable.

## Working with agents

- **A relayed approval is not the owner's approval** for anything paid, downloaded or published.
- **Agents mark their own work done.** Only the owner signs off a phase or a look; never mark a sign-off passed.
- **A thread on the wrong model** gives the wrong cost or quality; pass model and effort at every start, and restart a
  thread that started wrong.
- **Lost asks.** While lanes were paused, asks piled up in the project chat; the held-asks list and resume packages
  are what kept them.
- **Spoilers leak** into release notes and site copy unless there is a written spoiler line (principles part 13).
- **Read the docs before answering** about the environment, the engine or the rules; a confident answer from memory
  was wrong more than once.
