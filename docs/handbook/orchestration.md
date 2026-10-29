# Orchestration: how the agents built the game

Written 2026-10-29 from the Curse of Strahd project: the builder's runbook, the coordinator's held-asks and resume
lists, the worktree and lane notes, the plans in the owner's vault, the website and wiki hand-offs, and the project's
memory. It is the process a new game on this engine should start with. No keys, prices or account details are in it.

"The owner" is Ashwin, the person the game is for. Dates are 2026.

---

## 1. Who does what

| Role | What it is | What it owns |
|---|---|---|
| **The owner** | The person who asks for work, plays the builds and decides | Scope, story beats, look sign-offs, spending, releases, every phase sign-off |
| **The coordinator** | One Claude in the project chat, the only one the owner talks to day to day | Starting threads, relaying hand-offs to the builder, keeping the held-asks list and the todo file, answering from the record |
| **A thread** | One Claude session for one piece of work, with a status checklist the owner can see | Its own task; it reports in its own thread |
| **A lane** | A thread that changes the game: one git worktree, one branch per task | Its branch, never main |
| **An area lane** | A standing lane for one area (combat rules, UI, quests, bosses, magic items, allies, voice, video sprites, HUD, buildings, dungeon, wiki) that takes the small asks for that area one clean branch at a time | Its area's files |
| **The builder** ("Game build") | The one thread that merges hand-offs, runs the batch's tests and pushes main | `main` of the game repo |
| **QA lanes** | Threads that play or read the game and file numbered findings | Findings lists in the vault |
| **The voice lane, the wiki lane, the website/release lane** | Standing lanes with their own runbooks | Voice clips; the spoiler wiki; the public site, downloads and releases |
| **A plan thread** | A thread on the strongest model that writes a plan and builds nothing | A plan document with packages, waves and forks |
| **Codex** | The owner's other AI tool, working through GitHub pull requests | The content it was given (the Faerûn books, the iOS port) |

The threads run Claude Code on the owner's Mac mini through Remote Control (the repo, Godot, Blender and the test slots
are all there). The coordinator and the owner see each thread's checklist and its replies.

## 2. How one ask becomes a landed change

1. **The owner asks** in the project chat, usually in one line, sometimes with a screenshot or a bug report from the
   game (F12 in dev builds writes the report, a screenshot and the save into the vault).
2. **The coordinator sorts it.** A question gets an answer from the code (file and line, and whether it was read or
   run). A small change goes to the standing area lane for it. A big ask gets a plan thread first. Anything paid,
   downloaded or irreversible waits for a typed yes (part 7).
3. **A plan, for anything big** (part 3), with forks for the owner and a recommended default for each.
4. **Lanes build** in waves, one package per hand-off, on branches cut from origin/main.
5. **The hand-off** goes to the coordinator: branch, hash, files, hook functions touched, tests run, captures,
   decisions made (part 5).
6. **The builder lands it** in the next batch: previews the merge, adds it to the edge build so the owner can play it
   before it lands, merges, runs the right test tier once for the batch, drops a red branch and lands the rest, pushes
   main (part 6).
7. **After a landing** the coordinator tells the owner what landed in plain words, tells same-area lanes to rebase,
   asks landed lanes to clean up their worktrees, asks the voice lane to quote any new lines, and asks the wiki lane to
   rebuild when content changed.

## 3. Planning: the plan-first protocol

Every ask bigger than a day of one lane gets a written plan before any code. The plans that worked best (the dungeon
expansion, the Amber Temple look, the side-quest failure plan, the story allies plan, the easter eggs plan, the boss
redesign) all had the same parts:

1. **An audit with numbers.** What exists today, counted from the code and data, not remembered: "the castle has 17
   maps", "189 fight entries set their own HP", "127 checks can fail".
2. **The rules every package follows.** The owner's standing decisions that apply, quoted with dates.
3. **Numbered packages**, each one lane can build and hand off on its own, with a size (XS a few lines; S a prop or
   check and a test; M engine work or a new system; L multi-branch or design-heavy), the files it touches, the hook
   files it needs, the tests it adds and anything paid it needs.
4. **Waves** of at most three lanes that touch different files, ordered so engine pieces land before content.
5. **Costs**: every paid step quoted, nothing spent in the plan.
6. **Forks**: each real choice for the owner as a short question with options and a recommended default.
   "Defaults I picked" lists every smaller call the plan made, so the owner can overrule any one by number.
7. **Build order**: numbered steps written for the lane that will build it.

The owner answers the forks in a line ("start implementing all in sonnet 5.5 extra", "everything marked Gap, the walled
stair is a yes"). A fork with no cost is built on the recommended default and says so, rather than waiting. A plan
lives in the vault (or the project folder) and in the repo's `docs/plans/` once it is built.

The game itself was planned the same way: one plan (`Game_Plan.md` in the vault) with pillars, scope, the technical
foundation, the systems, agent roles, and milestones Phase 0 to Phase 7, each with an exit that a test proves and the
owner signs off. Build logs went into the vault after each phase, written for the owner: what was built, choices made
along the way, his feedback and what was done about it, what was not done and why, and notes for the next agent.

## 4. Models and effort

### What the owner decided, in order

| Date | Decision |
|---|---|
| 10-06 | Phase 1 was restarted from Phase 0's sign-off in extra effort mode, after a first attempt was set aside on a branch |
| 10-14 | Build and deployment threads (the builder, releases) run on Sonnet 5.5 at medium effort |
| 10-18 | "Opus plans, Sonnet lanes build": plans on Opus 5.5; the lanes that build them on Sonnet 5.5 at extra effort ("Implement using Sonnet 5.5 Extra", 03:22; "start implementing all in sonnet 5.5 extra", 19:07) |
| 10-21 | The standing policy: plans and hard work on the stronger model when the owner asks for it; lanes on the faster model at high effort; the builder on the smallest model that does the job; the model and effort are passed on every lane start |
| 10-24 | A thread started on the wrong model is restarted on the right one when its work begins (the magic items thread, started on Opus, restarted on Sonnet) |
| 10-28/29 | Opus 5.5 at extra-high for the promo trailer and for this knowledge audit ("Use opus 5.5 extra"); the audit thread that had started on the default model was stopped and replaced |

"Extra" in the owner's words is the extra-high effort level (`xhigh` in Claude Code), one below max.

### The policy to start a new game with

| Work | Model | Effort |
|---|---|---|
| Plans, audits, design documents, look plans, hard debugging, anything the owner names | Opus 5.5 | extra-high |
| Lanes building a plan's packages, rules and combat code, content | Sonnet 5.5 | high, or extra-high when the owner says so |
| The builder: merge, test, push; releases and deploys | Sonnet 5.5 (or a smaller model if it proves enough) | medium |
| Small data, voice or wiki-only lanes | Sonnet 5.5 | medium or high |
| Reviews of Codex pull requests (diff and checks only) | Sonnet 5.5 | high |

- **Say the model and effort in every lane start.** A lane that starts without them gets the default, which may not be
  what the owner chose.
- **The owner's word beats the table.** When he asks for a model for a task, that task runs on it.
- **Subagents and multi-agent workflows only when asked** (or when a skill or the CLAUDE.md says so): they cost
  tokens fast. Where they paid off: six helpers checked 105 quest walkthroughs' fight numbers against the data in
  about twelve minutes for the wiki.
- **Usage runs out.** On 10-20 the weekly quota ran out and every lane except the builder was paused. Part 8 is how
  nothing the owner asked for was lost.

## 5. Lanes

- **One lane, one thread, one worktree, one branch per task.** A lane never pushes or merges main and never writes in
  the main checkout. A pre-push hook (`make hooks`) refuses a push of main unless `STRAHD_PUSH_MAIN=1`, which only the
  builder sets: worktrees share refs, and once a lane's `git push origin main` moved GitHub main to the builder's
  unfinished batch.
- **Fewer lanes** (owner, 10-19): small asks go to the standing area lane for their area, not to a new thread each.
- **Making a lane is nearly free.** `make lane NAME=<name> BRANCH=<branch>` makes a worktree whose files and Godot
  import cache are APFS clones of the main checkout's, so it costs only the files it changes (10-08, after about 33
  worktrees, each with a private copy of the art and the import cache, filled the disk to zero). `SSD=1` puts it on an external drive's disk image, cloned
  from a seed that is refreshed only when it has drifted. Warm "spare" worktrees with a finished import can be claimed
  by checking out a branch and released with `git checkout --detach origin/main; git clean -fd` (no `-x`, so the
  import cache survives). `make lane-done NAME=<name>` removes a lane once its branch is merged and clean.
- **Cut from origin/main.** `make lane` cuts from local main; when the builder is building detached on GitHub main
  (part 6), lanes must cut from origin/main.
- **Hook files** are the shared files every area touches: the story state, dialogue runner, main menu, combat view and
  HUD, game root, location view, explore HUD, encounter, `project.godot`, the Makefile and CLAUDE.md. One branch per
  hook file per batch, unless the edits are in different functions and the coordinator says so. Only the coordinator
  or the builder edits the Makefile and CLAUDE.md; lanes write `docs/rules/deviations.md` and `docs/plans/` instead.
- **Conflicts:** ask the lane for a clean branch on current main rather than resolving it for them.
- **A shared Mac has limits.** At most 3 Godot import editors and 8 headless test processes across all lanes (24 GB of
  memory; a dozen editors at 1.8 GB each once sent it to load 82 and 20 GB of swap). The builder keeps slots 4 to 8 of
  the test slots and slot 3 of the import slots for itself, so lane tests can never starve a batch. A run past the cap
  waits and says so. No Godot window may take focus from the owner; tests run headless and screenshots draw off
  screen. Blender only when the owner says the Mac is idle. Stop lanes if the disk runs low.
- **Clean up.** A done lane removes its worktree and scratch files and deletes its own merged branches.

## 6. The hand-off and the builder

### The hand-off a lane sends

```
<Package name> hand-off
Branch <name>, hash <full hash>, <n> commits on origin/main <hash> (fetched <date>). Lane <folder>. Nothing pushed.
Author on every commit: the owner only, no co-author lines.

What it builds: <plain words, one bullet per visible change>
Files: <list>; hook functions touched: <file:function>, or none
Checks: make check green (<n> tests, <time>); the tests this change is about: <files, results>;
  fight series that moved: <name X/8 -> Y/8>, or none
Captures: <paths, before and after>
Saves: SAVE_VERSION unchanged, or bumped with an upgrade step and new golden saves
Lines that need voicing: <count, speakers>, or none
Departures from the rules: written in docs/rules/deviations.md, or none
Decisions I made (say if you want any different): <numbered>
Left out: <what and why>
```

### The builder's batch routine

1. **Preview each hand-off as it arrives**, touching nothing: check it is not stacked on a branch that must never land,
   list its commits, dry-merge it over the batch so far with `git merge-tree --write-tree --name-only`, and queue it.
   Add it to the edge build (`make edge-add BRANCH=<branch>`) so the owner can play it before it lands.
2. **Merge in the coordinator's order**, `git merge --no-ff` with a message in plain words naming the branch and hash.
   List the incoming range's commit trailers first and tell the coordinator about any co-author or tool line; never
   rewrite another branch's history to remove one (the owner kept two once, 10-16).
3. **Quick checks after merging:** the data checks, the cheat-code check, the voice manifest and clip pairing, and for
   art that every new image under the LFS paths is a pointer with its object present.
4. **The test tier the batch needs** (see [testing.md](testing.md)), run detached so a session restart can't kill it,
   logged to a file with start and exit lines. A `SCRIPT ERROR` or `ERROR` line fails a run even when every test
   passes.
5. **If green, push:** check the remote is an ancestor, scan the diff for anything shaped like a key, push the LFS
   objects first, then main with `STRAHD_PUSH_MAIN=1`. Then refresh the generated files (cheat codes), update the
   checklist's "main at" line, and send the coordinator the hash, test count and time, LFS count and branches.
6. **If red:** rerun the failing files alone (`make test FILES=a.gd,b.gd` takes bare file names; a path runs
   everything). Find the branch, if needed by building each suspect alone on GitHub main. A small reconciling or
   test-only fix may go in as its own commit, said to the coordinator. Otherwise send the branch back with the exact
   FAIL lines and a one-line rerun command, and land the rest. The standing rule: drop the red branch, land the others.
7. **Quick path:** an audio, docs, wiki or tools-only branch on a green main gets validate, `make check` and the tests
   for its area, then a push.
8. **Releases hold main.** When a hash is the release, main stays there until the release is dispatched, because the
   release workflow builds main's head at dispatch. No tags unless asked.

### What the builder never does

- **Never resets or rewrites main**, local or remote, or anyone's branch. If a branch merged into local main turns red,
  build the batch without it detached on GitHub main, push that, and when the fix lands merge GitHub main back into
  local main with a merge commit.
- **Never moves a branch under a checkout without checking.** Once someone ran `git checkout main` in the main checkout
  and an `update-ref` of main left its index on the old tree: `git status` showed the landing reversed, and a commit
  there would have reverted it. Look at the checkout's HEAD first; if it is on main, follow the ref move with a
  `git read-tree -u -m <old> <new>` after checking the index equals the old tree.
- **Never switches branches in a worktree while a test run uses it** (one two-hour run was lost that way), and never
  `pkill`s by pattern: find the run's own process tree by its working directory and stop that.
- **Never merges the branches on the never-merge list** (old paused work kept for reference) and never touches the
  shared `stash@{0}`.

### Conflict recipes that came up again and again

- **Append-only logs** (the art and voice generation logs, one JSON object per line): keep both sides, check every
  line parses and the count is base plus ours plus theirs.
- **Rules and UI docs** (deviations, coverage, `docs/ui/*.md`): keep both rows; where both edited one row keep the
  newer wording once.
- **The voice manifest:** take the union, check for duplicate keys, then pair-check that every entry has its clip and
  every clip its entry. Keep the voice JSON files sorted with indent 1, or the respelling tool refuses them.
- **A renamed word in voiced text** (a companion's name spelled two ways): run the respell tool after merging any branch
  cut before the rename; it moves the clips to their new keys.
- **Old plain-blob files** that show as modified after a move: re-normalise only those paths, never in bulk.
- **An untracked Godot `.uid`** that the branch also adds makes `git merge` fail with an empty conflict list: check it
  is the same uid, delete the untracked one, merge again. Never report a merge done without checking `git log -1`.

## 7. Approvals and talking to the owner

### What needs his yes, and what kind

- **If the owner asked for a step, that is his approval** for the whole ask. Ask at most once.
- **A typed yes in the lane's own thread** for anything paid (image, video and voice generation, quoted first), any
  download or install, any release or site deploy, a push to main that the Mac's permission check blocks, reading a
  credential, deleting branches, and any change to `project.godot` or the save format. A yes relayed by the coordinator
  is the decision, not the approval: the Mac's permission checks deny a push or a dispatch without the owner's own line
  in that thread ("Out-of-Place Publication", "Auto-Mode Bypass"), and the right response is to ask him for the line or
  give him the command to run himself, never to work around the check.
- **Write the exact go line for him** when a step is big, covering everything it does, and ask him to type it. The
  1.0.11 release line read: "Go: release 1.0.11 from game main as a full download, with the core engine cutover and
  the project.godot autoload paths moved to res://addons/dnd_core/ — build, upload to downloads, tag v1.0.11". A
  changed price needs a fresh yes.
- **"Just take action, stop asking me"** (owner, 10-28) became a standing yes for the wrap-up work, except generating
  new external assets. When he says this, drive the work to the end and post one summary.
- **Never ask for, store or echo a key.** Tools read keys from his environment and send them as headers.
- **Never mark an owner sign-off as passed**, and never touch his real saves or settings; read a save read-only when a
  lane needs to tune against his party.

### How to talk to him

- He skims. Lead with the answer or the decision he has to make, in full sentences, in plain words, no jargon.
- Decisions go on a card with two to four options and a recommended one; keep working on the recommendation while he
  decides, unless the step can't be undone.
- Keep each thread's checklist current; that is the progress report. Reply only with a result, a blocker or a
  question.
- Answers come from the code, with file and line, and say when something was read and not run.
- "TODO - ..." messages from him go into the todo file (`Todos/Next week.md`): done, in progress or not started, each
  with its lane and commit, his screenshots beside it.
- Bug reports from inside the game: reproduce first, then fix, then say what caused it.
- Build logs for him go in the vault, one per phase or feature, with pictures.

## 8. Pausing and resuming

When usage runs out or the owner pauses work:

- **Keep a held-asks list** (`Coordinator/Held asks while paused.md`): every ask he makes while paused, under the
  thread or area it belongs to, verbatim where it matters, with the message id so the lane can read it. Tell him each
  one is held.
- **On resume, write resume packages** (`Coordinator/Resume packages.md`): the held asks and the todo file grouped by
  area, sized S/M/L, tagged [DECISION] (blocked on his call), [YES] (blocked on a typed yes), [DUP] (same as another
  item) or [TODO]; a hook-file map so lanes in one wave never share a hook file; and a recommended start order in
  waves. Progression bugs and anything that lost his data go first.
- **Resume per area on his word**, one batched message per lane with his message ids attached. Don't message lanes
  between resumes except with his direct questions.
- **End of project:** a short list of what must land before he calls it complete, driven without asking, then one
  wrap-up message.

## 9. QA

- **QA lanes play or read, then file numbered findings** in the vault (functional bugs, storyline bugs, UI bugs, wiki
  walkthrough findings), closed in rounds. The next number is written at the top so two lanes never reuse one.
- **Probe tests settle "what does the game actually do"**: a scratch test in the lane that prints the engine's answer,
  run once, deleted, never committed.
- **Bots play the game.** The phase exit tests and the story bot walk the campaign to each ending through the real
  scenes; the fight series play every fight with an autopilot party. A bot that gets stuck is a bug report.
- **Reproduce before fixing**, and say what caused it.

## 10. Codex and pull requests

- The owner's other AI tool works on the GitHub copy through pull requests. Its PRs are taken as tested by him: review
  the diff and the PR's checks only, never run tests or import the project for a review.
- Reviews post from his account, so only COMMENT reviews work; end each with the attribution footer.
- Merge on GitHub once every comment is addressed; then the builder merges GitHub main into its main before the next
  push and runs the tests.
- Content that arrives before it fully works is gated in data (`"playable": false` per entry) and turned on per entry.
- When a PR pins an engine commit on a branch, fast-forward the engine's main to that commit first, or the next
  submodule bump drops it.

## 11. Where knowledge lives

| Kind | Where |
|---|---|
| Engine decisions, contracts, rules coverage and deviations | The repos' `docs/` (this engine's [reference/](../reference/README.md) is a snapshot) |
| Agent rules for a repo | `CLAUDE.md` at its root (see [claude_md_template.md](claude_md_template.md)) |
| Design principles and dated decisions | [design/game_design_principles.md](../design/game_design_principles.md) |
| Plans, build logs, QA findings, runbooks, the wiki | The owner's Obsidian vault, one folder per game |
| Hand-offs, held asks, resume packages, the todo file, audits | The project's shared folder |
| Facts a later thread would otherwise ask the owner again | Project memory, one file per subject |

Write a thing down where the next agent will look for it, in the turn you learn it.
