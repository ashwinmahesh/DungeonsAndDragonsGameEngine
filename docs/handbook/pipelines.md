# Asset and release pipelines

Written 2026-10-29 from the Curse of Strahd game: its CLAUDE.md, Makefile, art and voice docs (copied into
[reference/](../reference/README.md)), the website and wiki runbooks, and the build logs. The tools named here live in
the game repo (`tools/`, `blender/`, `.github/workflows/`), not in this engine; a new game copies the ones it needs.
No keys, account names or balances are in this document: tools read keys from the owner's environment and send them
as request headers, and nobody prints them.

Every pipeline that spends money follows the same rule: **quote first, then the owner's typed yes in the lane's own
thread, then spend**. A changed quote needs a new yes. A tool that stops at its budget limit reports to the
coordinator; it does not override.

---

## 1. Generated images (Gemini)

- **One entry point:** `tools/art/generate.sh`. It adds the style preamble (`art/prompts/style_preamble.txt`), uses
  the provider and model pinned in `art/manifest.json` (Gemini `gemini-3.1-flash-image`, owner's pick 2026-10-06),
  and appends every call to the append-only generation log. Prompt templates live in `art/prompts/`.
- **Ask for a plain flat white background.** Gemini gives opaque images; the pipeline removes the white. For portraits
  ask for "plain dark purple background, no props or scenery" (or the new game's ground colour), or it paints a scene.
- **A spend ledger** (`tools/art/gemini_budget.py`, `make art-spend`) counts every call across all worktrees, per key
  and per thread, with a stop point per key. Batch tools call its preflight before their first call and stop if the
  batch would pass the stop point.
- **Fallback:** OpenAI's image model through `tools/art/generate_openai.sh`, never a model with an announced shutdown
  date.
- **Characters come only from this pipeline** so the style stays consistent; free packs are for props, sounds, UI and
  icons.

## 2. Character sprites (Blender)

1. **Turnaround:** one generated image with 5 views in a row (front, front three-quarter, side profile facing right,
   back three-quarter, back), arms at the sides, same height, clear gaps, plain white background.
2. **`make sprite TURNAROUND=<png> ID=<id>`** cuts it into a cutout rig in Blender and renders 8 directions by 8 walk
   frames at 384 px cells. The cutter smooths before cutting (no salt-and-pepper), quantizes to the palette (keeping
   neutral greys grey; `SAT=1.3` lifts muted reds), and despeckles. `BODY=quadruped|float|hop|slither|lumber|swarm`
   picks the walk for bodies that aren't two-legged; `STATIC=1` for things that don't walk.
3. **Attacks:** add the character to `art/anim/animations.json` and run `make anims ONLY=<id> GENERATE=1`: wind-up and
   strike keyframes per view, rendered in 8 directions. Every character walks and attacks in 8 directions; a test
   checks.
4. **Creatures of the engine's data** keep their art in the engine (`tools/art/route_to_core.py` moves it there after
   `make sprite`); a game's own heroes, people and villains stay in the game.
5. **Portraits:** `make portrait SRC=<png> ID=<id>` flattens the background to one palette colour. Three to four
   expressions per named character (`<id>_<mood>.png`), every monster has one (a test checks).
6. **Busts, cutscene stills and the character creator's parts** have their own build tools and recipes
   (`tools/art/build_busts.py`, `build_cutscenes.py`, `creator_art.py`). Stills never show the heroes' faces, because
   players pick their party. Every cutscene has at least two pictures.

**Blender runs only when the owner says the Mac is idle.** Its renders take the GPU from his work.

## 3. The heroes' fuller animation (video clips)

- The six heroes have about 35 frames of animation each (idle, walk, attack, cast, flinch, fall, riding, sneaking),
  with MapleStory as the reference (owner, 2026-10-07). `make keys [ONLY=<id>]` draws their key poses.
- **Video is the source of in-between frames, not the playback format.** Short image-to-video clips are generated
  from the key poses and cut into sprite sheets by `make veo-anims` (`tools/art/veo_anims.py`). Playing video in game
  cost too much CPU.
- The clips came from Veo until it was withdrawn; since 2026-10-24 the same tool calls Gemini Omni Flash. Retakes are
  per direction (`REDO="kind_dir ..."`).
- Quote the clip count and cost first, walks and idles before the rest. The owner checks walks closely: one stride a
  second read right, and he asked for retakes when a direction looked off.

## 4. 3D models, props and the world's surfaces

- **Everything in the world that isn't a character is a 3D model** made from its 2D art in Blender (owner,
  2026-10-07), or a free CC model. Only flat things stay 2D: stains, marks, circles, puddles, flames and mist.
- **Free models** (Sketchfab and similar) need a CC0 or CC BY licence, the owner's typed yes before download, the
  download kept untouched with its licence in `art/sourced/<pack>/`, and a credit line. A walking hut, a dragon skull
  and a skeleton came this way.
- `make prop SRC=<png> ID=<id> HEIGHT=<units>` and `make props` make billboard and modelled props; the props catalog
  (`art/sprites/props/catalog.json`) names each by `model` or id, and set dressing places them. A new model needs its
  art in the catalog (a test checks). Real-world sizes.
- **Characters and creatures as 3D figures** (rigged models with named clips, e.g. from Tripo Studio): a game lists them
  in `art/figures/manifest.json` and they replace the art id's sprite wherever it is drawn; anything without one keeps
  its sprite. See [the figures reference](../reference/art/figures.md).
- `make textures`, `make plants`, `make vistas`, decals, surfaces: each from a recipe JSON in `tools/art/`. Modern
  surfaces are smooth `<surface>_hd.png` tiles with their own light response.
- **Large binaries go to Git LFS** when added or changed: in the game, new or changed images under the generated,
  sprite, portrait, creator and texture folders, voice mp3s and sourced sound clips; in this engine (since 2026-10-28)
  textures, prop sprites and `.glb` models. Older files stay plain blobs: **never `git lfs migrate` or
  `git add --renormalize`** (it rewrites history or re-uploads thousands of files). Stage only files you changed; an
  old image whose timestamp moved shows as modified, and `make lfs-quiet` clears that. A public repo's LFS storage and
  bandwidth are billed to its owner, so keep the engine's LFS to what must be there.

## 5. UI art and icons

- **Menu ornaments and icons** are drawn as black silhouettes, turned into white shapes with alpha (`make ui_art`), and
  tinted by the game with palette colours, so they stay sharp at any size and recolour with the palette.
- **Spell and item icons** are game-icons.net silhouettes (CC BY 3.0) picked per key in `art/icons.json` as
  `<silhouette>@<tint>` (spells tinted by flavour, items in their natural colours) and framed by `make icons`. A spell
  or item's data `icon` names its key, else its id is the key. Credit every artist in `art/credits.json` (a test
  checks). The icon catalog and sources are in this engine; a game adds its own overlay for its own items.
- **Fonts** ship with the game so every platform looks the same (three SIL OFL faces in Curse of Strahd: a medieval
  book hand for titles, an engraved capital face for captions, a book serif for big numbers; body text in the plain
  default font for reading).

## 6. Voice (ElevenLabs)

The full decision is ADR 0013 ([reference/adr/0013-voice-over.md](../reference/adr/0013-voice-over.md)).

- **One entry point:** `make voice [SPEAKER="..."] [LIMIT=n] [DRY=1] [MAX_USD=n]`. `DRY=1` prints what it would make
  and the quote.
- **Casting is pinned** in `audio/voice/casting.json`: the model, format and voice per speaker. Each line is delivered
  on `eleven_v3` with the speaker's accent tag and its own direction (mood, pace) from `audio/voice/directions.json`
  (owner, 2026-10-08), because the older model flattened accents. The Narrator stays on `eleven_v4` without tags to
  match his original recordings.
- **A clip is keyed by its text:** `audio/voice/<speaker>/<sha1(text)[:16]>.mp3`. Editing a voiced line silences it
  until it is voiced again, so add lines rather than edit voiced ones, and quote the re-record when an edit is needed.
  Lines with a `{name}`, option lines and book text are never voiced.
- **New voices are cast in rooms:** a page of designed options for one character, the owner picks one by letter.
  Voices he accepted stay; changes happen only on his request. Children use library voices (designed voices must be
  adults).
- **Accents are part of the world.** Barovians, the Vistani and the villain had a strong Eastern European accent;
  outsiders kept their own. Write each main character a voice bible (`docs/voice/<id>.md` in the game).
- **The manifest and the clips must pair** one to one (the builder checks); see the conflict recipes in
  [orchestration.md](orchestration.md).

## 7. Dialogue writing (Gemini through the ai-bridge)

- **New or rewritten dialogue is drafted by Gemini** through the owner's ai-bridge service (an HTTP API on his own
  machine, on his own subscriptions), never with an API key (owner, 2026-10-18). Read the bridge's skill file first.
  Don't start or restart the bridge: if it isn't up, say so.
- **Keep the brief and the raw reply** beside the plan (`docs/plans/gemini_<batch>/` in the game), then edit the draft
  into the game's own dialogue format (ADR 0008, [reference/contracts/dialogue.md](../reference/contracts/dialogue.md))
  and run the dialogue lint.
- **Rules for every line** (principles part 6): the Narrator's voice rules, every conversation keeps its exit, failed
  social checks are spent and sometimes cost something, witty townsfolk, the villain's chosen tone.

## 8. Music and sound

- **Existing free-licence recordings, not generated ones** (owner, 2026-10-06): CC0, public domain, CC BY. Music and
  sound packs may be downloaded without asking each time (2026-10-07); everything is credited on the Credits screen and
  in the licences doc.
- **Moods, not tracks:** `art/audio.json` maps each place, fight kind and scene to a mood, and each mood to a rotation
  of tracks. Audit the moods against the scenes they play under (the castle once had a lively tavern song).
- Encode very large `.wav` sources to `.mp3` before committing (a 91 MB wav became 8 MB).
- The 21 sound-effect packs, the effects data and the fonts are in this engine.

## 9. The spoiler wiki

- `make wiki` (`tools/wiki/build_wiki.py`) writes the whole wiki from the game data into the vault's `Wiki/` folder:
  places, people, quests with walkthroughs, fights with their numbers, items with cheat codes, bestiary, rules pages.
  Generated blocks sit between `%% auto %%` markers; hand-written prose outside them is kept. A link manifest keeps
  links working when pages are renamed.
- `make wiki-shots` takes its screenshots through the off-screen capture scene.
- Rebuild after content lands; test the generator without touching the vault with `--out <scratch> --no-images`.
- The web copy lives under `/wiki/` on the public site, redeployed after each rebuild under a standing yes. **Spoilers
  stay inside `/wiki/`**; the rest of the site and the release notes are spoiler-free.

## 10. Releases and the site

- **The site** is a static repo on GitHub Pages behind Cloudflare; pushing its main publishes. Every page carries the
  fan-content notice and the creator credit.
- **The release workflow** (`release.yml`, dispatched with a version and `upload=true`; `upload=false` is a dry run)
  exports the game on Linux, signs the Mac app, signs the Windows exe, builds cumulative patches from each earlier
  version, uploads to object storage and tags `v<version>`. A macOS job makes the DMG, notarizes and staples it. About
  45 to 60 minutes. It builds main's head at dispatch, so main is held there until dispatch.
- **Check before switching the site:** the log shows the DMG as a notarized Developer ID build, each file answers 200
  (add a query string to the URL: the CDN caches a 404 asked before the upload), and each patch's checksum matches.
  Then switch the download buttons, `llms.txt` and the release notes, and publish `latest.json`, which the update
  scripts read to pick the patch whose base matches the install.
- **A `project.godot` change means a full download** (about 4.4 GB), with no patches. Batch such changes into one
  release.
- **After the engine split** the workflow must check out the engine submodule and fetch its LFS objects; the first
  1.0.11 run failed on that (2026-10-28) before anything was published.
- A notarization network blip ("The network connection was lost" while stapling) is fixed by re-running only the
  failed job. A run can be cancelled with nothing public while it is still packaging.
- Releases and site deploys need the owner's typed go line in the release thread (orchestration part 7).

## 11. iPhone and iPad

- The iOS port was built by Codex as a pull request on the game and a branch of this engine; the platform notes are in
  [platforms/ios.md](../platforms/ios.md). Signing material lives in the repo's Actions secrets; uploads to TestFlight
  are manual, and nothing submits for review or publishes without the owner.

## 12. Generated documents

- `make cheat-codes` rewrites the vault's cheat codes page from the item data (the codes come from the engine's
  `story/cheat_codes.gd`); `make magic-prices` writes the magic items' prices (Sane Magical Prices) and
  `make validate` checks them; `make xp-sim` prints the party's level at every story gate under XP levelling.

## 13. The promo trailer

The 2026-10-28 plan (on Opus 5.5 at extra-high) is a good template: real gameplay in the first 3 to 5 seconds and no
logos first; the genre clear within 15 to 30 seconds; three acts cut on the music's marks, shots of 1.5 to 4 seconds
getting faster toward the climax; 60 to 90 seconds; at least 80% real gameplay; the same party in every shot, close
enough to see their animation; the music at full level with the voice placed in its quiet passages; short captions over
gameplay. Shoot with the off-screen capture tools and storyboard every beat with a reference frame before cutting.
