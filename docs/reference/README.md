# Reference: the engine's decisions, contracts and guides

A snapshot of the Curse of Strahd game's docs that describe this engine, copied on 2026-10-29 from game main
`ef29e6278` (github.com/ashwinmahesh/CurseOfStrahd, `docs/`). They were written while the engine still lived inside
the game, so:

- Paths like `rules/...`, `combat/...`, `ui/...`, `world/...` are this repo's folders (in a game they sit under
  `res://addons/dnd_core/`). Paths like `data/locations/`, `narrative/`, `tools/`, `art/palette/` and the Makefile
  targets are the game's.
- Examples name Barovia's people and places. Read them as worked examples of the rule.
- Links that leave this folder (to `docs/tasks/`, `docs/regions/`, the vault, other plans) point at the game repo.
- The game's copies are the ones kept current. When an engine decision changes, update the game's doc and refresh this
  copy, or move the doc here for good and delete the game's.

One edit was made on copying: a voice account's balance was removed from `plans/npc_depth_and_quests.md`.

## Decisions (ADRs)

| | |
|---|---|
| [0001](adr/0001-test-framework.md) | In-house headless test runner instead of GUT or gdUnit4 |
| [0002](adr/0002-dice.md) | All rolls go through DiceRoller |
| [0003](adr/0003-rules-engine-contract.md) | The rules engine is a pure library of creatures, modifiers and effects |
| [0004](adr/0004-world-scale.md) | One world unit is one 5 ft square; the camera |
| [0005](adr/0005-data-loading.md) | Rules data is JSON loaded through the Compendium |
| [0006](adr/0006-choices-and-breakdowns.md) | A build is a record of keyed choices; every number is a Breakdown |
| [0007](adr/0007-combat-grid-and-encounter.md) | The combat grid and the Encounter |
| [0008](adr/0008-story-and-dialogue.md) | Story state, dialogue files and the Narrator |
| [0009](adr/0009-locations-as-grid-maps.md) | Locations are grid maps; exploration and combat share them |
| [0010](adr/0010-campaign-spine.md) | The campaign spine: the reading, travel, guests and shops |
| [0011](adr/0011-regions-treasures-and-gifts.md) | Region packages, treasure spots, allies and dark gifts |
| [0012](adr/0012-magic-items.md) | Magic items |
| [0013](adr/0013-voice-over.md) | Voice-over |
| [0014](adr/0014-castle-strahd-and-endings.md) | The final dungeon, the villain and the endings |

## Contracts: what data the engine reads

[modifiers](contracts/modifiers.md) (the stat vocabulary) · [combat](contracts/combat.md) ·
[spells](contracts/spells.md) (spell recipes) · [monsters](contracts/monsters.md) · [magic_items](contracts/magic_items.md) ·
[dialogue](contracts/dialogue.md) (the dialogue and Narrator format) · [locations](contracts/locations.md) (maps, NPCs,
quests, flags) · [campaign](contracts/campaign.md) (the reading, travel, encounters, shops, guests) ·
[schedule](contracts/schedule.md) (things on a clock) · [events](contracts/events.md) (EventBus signals)

## Art: the look and how it is made

[style_bible](art/style_bible.md) · [atmosphere](art/atmosphere.md) · [textures](art/textures.md) ·
[plants](art/plants.md) · [set_dressing](art/set_dressing.md) · [building_kit](art/building_kit.md) ·
[interiors](art/interiors.md) · [models](art/models.md) · [decals](art/decals.md) ·
[spell_effects](art/spell_effects.md) · [animation](art/animation.md) · [creator](art/creator.md).
The overview for a new game is [design/hd2d_look.md](../design/hd2d_look.md).

## UI: every screen

[look](ui/look.md) (the menu kit and its rules) · [character_creation](ui/character_creation.md) ·
[level_up](ui/level_up.md) · [inventory](ui/inventory.md) · [party_management](ui/party_management.md) ·
[combat_view](ui/combat_view.md) · [d20_roll](ui/d20_roll.md) · [check_aid_prompt](ui/check_aid_prompt.md) ·
[busts](ui/busts.md) · [cutscenes](ui/cutscenes.md) · [loading_cards](ui/loading_cards.md) ·
[rules_cards](ui/rules_cards.md) · [saves](ui/saves.md) · [settings](ui/settings.md) · [controller](ui/controller.md) ·
[travel_map](ui/travel_map.md) · [skirmish](ui/skirmish.md) · [run_stats](ui/run_stats.md)

The wireframes the owner approved for the four core flows (creation, level up, inventory, party) and the combat view
are in [ui/wireframes/](ui/wireframes/), linked from those pages.

## Rules

[coverage](rules/coverage.md) (every 2024 PHB rule and its status) · [deviations](rules/deviations.md) (every
departure and house rule, with dates) · [data_sources](rules/data_sources.md) · [reference_party](rules/reference_party.md)
(hand-worked sheets, levels 1 to 11) · [stealth](rules/stealth.md) · [content/faerun_arcana](content/faerun_arcana.md) (the
Faerûn and Arcana Unleashed content pack)

## Systems designed as plans

[difficulty](plans/difficulty.md) (the four modes and the boss rules) · [xp_mode](plans/xp_mode.md) (XP levelling and
its simulator) · [boss_redesign](plans/boss_redesign.md) · [engine_split](plans/engine_split.md) (how this repo was cut
out of the game) · [ui_polish](plans/ui_polish.md) · [captives](plans/captives.md) (spare or capture) ·
[npc_depth_and_quests](plans/npc_depth_and_quests.md) (trait, want and secret; side-quest variety; comedy and failure;
its [roster](plans/npc_depth_roster.md)) ·
[overworld_stealth](design/overworld_stealth.md)

## Story systems, as built

[approval](story/approval.md) (companion approval, romances, Inspiration for playing in character) ·
[world_checks](story/world_checks.md) (every skill has uses in the world) · [camp](story/camp.md) (long rests on the
place's own map) · [fight_tuning](story/fight_tuning.md) and [boss_fights](story/boss_fights.md) (how fights were
tuned and then rolled back to the book's numbers)
