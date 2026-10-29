# How the game plays, and how it should feel

Written 2026-10-29 from the Curse of Strahd game as it stands on main, its feature list, its build logs and the
owner's decisions. This is the play experience the engine was built for. A new game changes the world, the story
and the palette; it keeps this loop and these feel targets unless the owner decides otherwise. The reasons behind each
rule are in [game_design_principles.md](game_design_principles.md). Dates are 2026.

---

## 1. In one paragraph

A single-player, turn-based tactical party RPG of a whole published D&D adventure on the 2024 rules. The player leads
four heroes, chosen from six voiced companions or one custom hero, and controls every one of them, and every story
guest, in and out of combat. Out of a fight the party roams a lit 3D world in real time on the same 5 ft grid it
fights on, so a fight starts where it stands. Fights follow the tabletop rules with Baldur's Gate 3's interface: every
number explains itself, every reaction asks, every odd is shown before you act. Conversations are branching, voiced
and witty, and a failed persuasion is spent. A villain watches from the start and comes closer as the party defies
him. The story reshuffles each playthrough and ends in one of several endings.

## 2. The loop

1. **Arrive.** A loading card with the region's art and a tip; on loading an old save, a short "previously" recap.
   The place has its own light, weather and music for the hour.
2. **Explore.** Left-click to walk or use, right-click anyone or anything for everything you can do with it. Exits
   are signed on the board and the minimap; hidden areas stay hidden until found; traps show only when passive
   Perception beats them, otherwise a Search finds them. Turn-based exploring is there any time, to place the party
   before striking. Sneak with sight cones that show who would see you; open a fight with surprise, or be ambushed.
3. **Talk.** Large busts, a Narrator in the style of Baldur's Gate 3's, and townsfolk worth talking to (each has a
   trait, a want and a secret). Checks show who will roll and their chance before you choose; Tab picks who speaks for
   the party. A failed Persuasion, Intimidation, Deception, Performance or Insight check can't be retried and sometimes
   costs something; every conversation still has a way on.
4. **Fight where you stand.** Initiative and a turn-order strip, the full 2024 action economy at a glance, hit chances
   and damage on hover with Advantage and its reasons, area previews that show who each spell will catch and their
   chance to fail the save, a friendly-fire warning, a log where every line opens its math. Reactions always ask
   unless set to always or never. Undo a move that did nothing; the game saves at the start of every round.
5. **After the fight.** Loot, the party stash (takes loot from anywhere, gives it back only at a safe place), short
   and long rests, camp talks and banter, healing and raising the dead at temples for a price.
6. **Travel.** A painted travel map with road times, the arrival hour, a warning before travelling after dark, and
   random fights that get worse at night (they can be switched off). Weather lengthens journeys and sends townsfolk
   indoors; towns keep hours.
7. **Grow.** Levels by story milestones (one per region, so regions can be taken in any order), or by experience if
   the player picks it. Level up with every 2024 choice and a Use Recommended button; benched companions keep their
   level and go through the level-ups they missed when they rejoin; respec is offered and can be switched off.
8. **Choose.** Story flags set in one region are read in others; companions approve or disapprove and say so;
   side quests can fail; the reading at the start reshuffles where the treasures, the ally and the final battle are.
9. **End.** One of five endings with epilogue slides and the run's tally. A finished game keeps its own save and
   never writes over one the player made.

## 3. The party is the player's

- **The player controls every party member and every story guest.** AI only plays enemies and bystanders. A guest
  who must not fight (a non-combatant) keeps out of fights rather than being played by the AI.
- **Six companions with personal quests** woven into the campaign, each with art, a voice and an accent, banter and
  camp talks; up to four travel at once, swapped any time outside a fight.
- **One custom hero** from a full appearance creator, with portraits and a choice of voice.
- **Character creation** step by step with a live sheet, recommendations, and a check on what the party is missing.

## 4. How it should feel: the targets

| Target | Value | Decided |
|---|---|---|
| An ordinary fight's length | 2 to 3 rounds, 4 at most | 2026-10-24 |
| An ordinary fight's difficulty | won about 5 times in 8 by the autopilot party on Balanced | 2026-10-13 |
| How to make a fight harder | monsters at their book Hit Points, hitting harder (+1 to +3 to hit, about +30% damage), never more HP | 2026-10-23/24 |
| Bosses | planned one by one: minions, lair actions, phases; +25% damage on Balanced and harder; to-hit and save DCs grow with the party's level on Balanced (+1 to level 4, +2 at 5 to 8, +3 from 9); legendary actions only after a hero's turn; Legendary Resistance only against conditions and spells that do nothing on a success | 2026-10-19 to 10-25 |
| Every fight | finishes within 30 rounds and can be won: the test party wins it at least once in 8 seeds, unless the owner accepted it as winless for that party | standing |
| Ordinary foes | the book's line-ups at the book's Hit Points; bosses are tuned one by one (above) | 2026-10-24, 10-25 |
| Fights start spread out | so one area spell can't end a fight | 2026-10-15 |
| Movement in fights | half the earlier speed, so it looks natural | 2026-10-06 |
| Damage numbers | stay about 2.5 seconds | 2026-10-06 |
| End Turn | asks only when the Action is unused | 2026-10-06 |
| Time passing | fades to black with how long it was (not under half an hour) | 2026-10-06 |
| The screen | nothing falls off it: HUD in view, text fits its box, options never cut off; every screen has a way back (Escape) | standing |
| Numbers | every number shown is a breakdown you can hover | standing |
| Dice | a fresh seed on every new game and every load, so a reload never replays the same rolls; what the world holds is fixed per playthrough | 2026-10-07 |
| Difficulty modes | Story, Balanced, Tactician, Honour (one save slot, sharper foes, a wipe ends the run), modelled on Baldur's Gate 3's | 2026-10-07 |

## 5. Impact and readability in a fight

A freeze on heavy hits, a push-in on critical hits, slow motion on the last foe, the camera turning to a big spell,
boss name plates and health bars, 3D effects for every spell and ability (per beam for multi-beam spells), a sound for
every hit and miss, battle cries, taunts and pain sounds, a fall and a sound when anyone drops to 0. Advantage and
Disadvantage are shown on the attack with their reasons. Marks like Hunter's Mark show on the target with who placed
them.

## 6. The villain is there from the start

The villain is visible in his scenes from the first chapter, visits the party across the campaign, and a hidden measure
of his attention (his servants killed, treasures held, defiance) brings his visits, spies and the road's dangers
closer. His harassment fights run until he is beaten back. Any new game should have a presence like this: the threat
the whole story is about should be felt long before the last fight.

## 7. Extras that earned their place

- **Skirmish and Character Lab:** a party of up to four at any level from 1 to 20 against any stat blocks on any map,
  the fight's difficulty rated before it starts. It is how rules and balance get tried without playing to a place.
- **An encounter editor**, **achievements**, run stats at the end, **chapter jump-in saves** (start any chapter with a
  fitting party), and **cheat codes** for every item, for testing and fun.
- **Controller support** throughout, with a radial action menu in fights.
- **An interactive tutorial** inside the first dungeon that teaches the rules by playing them.

## 8. How the owner plays it

- He plays the **edge build** (`make run`): main plus every handed-off branch that hasn't landed yet, on its own copy
  of his saves, so he sees work before it lands.
- He reports bugs from inside the game (a key in dev builds) with a screenshot, the save and the log, and sends short
  "TODO" lines.
- He judges by playing and by captures; a capture is required for anything visual, and he signs off phases and looks
  himself.
