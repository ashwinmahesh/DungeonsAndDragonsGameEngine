# DndCoreEngine

Private core for D&D 5e (2024) games made in Godot 4.7: the rules engine, grid combat and AI, the story engine core
(state, dialogue, quests, rests, travel), the data schemas, the Compendium data (classes, subclasses, species,
backgrounds, feats, spells, items, magic items, monsters, conditions) and the test framework.

Used as a git submodule at `addons/dnd_core` by the Curse of Strahd game, which writes this repo's content from its own
tree with `python3 tools/core/extract.py --write` until it switches over (docs/plans/engine_split.md there).

- The story engine names no campaign: a game supplies a `CampaignModule` (story/campaign_module.gd) named in
  `data/campaign.json`.
- Data holds rules content of the books only; a game keeps its own entries (its monsters, items) in its own `data/`.
- Private: it holds content beyond the SRD, used under the owner's personal-use decision. Never make it public.
