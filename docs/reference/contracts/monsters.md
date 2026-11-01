# Monster stat blocks in a fight (data/monsters → combat/monster_actions.gd, combat/ai/ai_brain.gd)

Numbers are the 2024 stat block's. These machine-readable keys sit next to the prose `text`.

## Actions

| key | meaning |
|---|---|
| `kind` | `melee`, `ranged`, `save`, `multiattack`, `spellcasting`, `special` |
| `attack`, `damage` | attack bonus and reach or range; damage entries (extra entries add dice; `if: bloodied` / `not_bloodied` picks a swarm's damage) |
| `on_hit` | riders after a hit (below) |
| `save`, `targets`, `on_fail` | a saving-throw action: who it can target (`range`, `count`, `max_size`, `in_space`, `requires`: grappled / incapacitated / restrained / willing), damage, riders on a failure |
| `area` on a save action | `{shape, size, width}`: `space`, `cone`, `line`, `emanation` and the rest (a `sphere`, `cube` or `cylinder` with `targets.range` lands round the target: a hurled boulder; a `path` is a charge: the monster goes straight at the target up to `size` feet, as wide as itself, through whoever is in the way and without Opportunity Attacks, to the farthest square it fits, and those it passed make the save); everyone in it is caught (MonsterActions.area_cells, save_victims). A creature's meta `area_bonus_ft` (an int of feet, 0 when missing or negative) grows its emanations, cones and lines, and how far it can aim them (`targets.range`), by that much, its legendary options' areas with them (MonsterActions.area_size) |
| `multiattack[].or` | alternatives for that slot (Scimitar or Pistol); the AI picks what reaches, a save action first when it has a target |
| `multiattack[].per_head` | as many of that attack as the creature has heads now (Multiple Heads) |
| `multiattack[].count` | the AI begins the Multiattack itself (`begin_multiattack`). A creature the player runs (a summon, a shaped or dominated creature, a story ally) begins it with its first listed attack: `attacks_per_action` is the total, an attack the Multiattack doesn't list is one attack, and a listed save action (a Draconic Spirit's Breath Weapon) takes the place of one attack |
| `recharge`, `uses` | Recharge X-6 rolled at the start of the monster's turn; uses per day |
| `forms` | Shape-Shift forms that can use it (the Werewolf's Bite) |
| `weapon` | a held weapon (Disarming Attack) |
| `ac_bonus` | Parry: +AC against one melee hit while holding a weapon |
| `when_hit` (a trait) | `{riders, once_per_turn (true)}`: an attack roll that hits it (a weapon's or a spell's) sends the riders at the attacker, the creature their source (a chain that shoots out: a Strength save or Grappled; MonsterActions.when_hit) |
| `do: fling` | a creature it holds (Grappled by it, up to `targets.max_size`) thrown at its nearest other foe within `targets.range`: the grapple ends, it lands in the open square nearest that foe, and both make the action's save (damage, half with `success: half`, `on_fail` riders). As one slot of a Multiattack (`or: ["fling"]`) the AI throws when it holds someone (MonsterActions.fling) |
| `do`, `cast` | special Bonus Actions: `dash_or_disengage`, `hide_in_dim`, `shape_shift`, `cast` (Divine Aid's spells) |

## Riders (`on_hit[]`, `on_fail[]`)

`{do, save, until, not_types, only_types, not_species, max_size, immune_on_success, ...}`:
`condition` (with `until`: target_turn_end, target_turn_start, source_turn_start, source_turn_end, minute, permanent;
optional `modifiers`), `grapple` (`escape_dc`, `limit`), `pull` / `push` (`feet`), `drain_max_hp` and `heal_self`
(`type`), `ability_drain` (`ability`, `dice`), `curse` (lycanthropy), `engulf` (`escape_dc`, `damage`, `conditions`), `afflict` (`id`, `levels`: levels of an affliction,
docs/contracts/afflictions.md; an aura's `riders` take it, each with its own `save`: spores that burn and then rot).

optional `modifiers`), `grapple` (`escape_dc`, `limit`, `restrain`; `until: target_turn_end` lets go at the end of the held creature's next
turn), `pull` / `push` (`feet`), `drain_max_hp` and `heal_self`
(`type`), `ability_drain` (`ability`, `dice`), `curse` (lycanthropy), `engulf` (`escape_dc`, `damage`, `conditions`).

## Traits read by code

`aura` (`radius`, `trigger: start_turn`, `save`, `condition`, `until`, `immune_on_success`, `affects`): Stench,
Festering Aura. `dreads_item` (`items`, `damage`, `riders`): at the start of its turn, if it can see a creature carrying one of
`items`, it takes the damage and the riders land on it (a likeness of a lost love). `absorb`: Lightning Absorption. `sunlight`: `sensitivity`, `weakness`, `hypersensitivity`.
Flags: `pack_tactics`, `undead_fortitude`, `incorporeal_movement`, `spider_climb`, `swarm`, `flyby`,
`pass_through_creatures`, `loathsome_limbs` (by trait id). `make validate` runs tools/data/check_implemented.py,
which fails if a trait or feature says `"implemented": "engine"` and no code reads it.

## Offered actions (`traits[].offers`)

A trait can offer an action to every other creature in the fight (combat/trait_offers.gd): it shows on their hotbar as
"<label> (<holder>)" while they are within `range` feet of the holder. `{key, label, cost, range, check, damage,
on_success}`: `key` names the `ability` event the view hears (source `feature`, by the user, the holder its target;
the trait's id when missing), `label` the trait's name when missing, `cost` `action` (default) or `bonus`, `range` 60
by default, `check` `{skill, dc}` the user's ability check, `damage` `[{amount or dice, type}]` dealt to the holder on
a success, `on_success` riders (above) landing on the holder with the user as their source (so `until:
source_turn_start` means the start of the user's next turn). The event is sent whether the check succeeds or not.
A contest instead of a set DC: `contest: {save}` makes the check's total the DC of the holder's saving throw, and the
damage and riders land when the holder fails it. `needs` (a tool kind, such as `musical_instrument`): the user must
carry one, and has Advantage on the check when proficient with the one they play. `influence: true` labels it
"Influence: <label>", a variant of the Influence action. `save: {ability, dc}`: the holder saves against that DC instead of a check (flattery
it must resist), and the offer lands when it fails; `auto: true`: no roll, it simply lands. `needs_item` (item ids): the
user must carry one of them (a memento shown, a bottle splashed), and `consumes: true` uses that one up.

## Multiple Heads

A trait's `heads` (how many it starts with), with `head_damage` (25: damage taken during one creature's turn that kills a
head, once a turn), `regrow` (2 for each head lost, at the end of its own turn, unless it took damage of a
`stops_regrowth` type since, fire by default; or `regrow_one`: one dead head back each turn, up to how many it started
with) and `regrow_heal` (20 Hit Points when they grow). No heads left is death.
A Multiattack entry with `per_head` makes that many of the attack. Events: `heads` {id, heads}. (MonsterActions.heads_*;
the MM Hydra's.) `oa_per_head`: one Opportunity Attack a round for each head beyond the first, on top of its Reaction
(Reactive Heads; MonsterActions.spare_oa). `head_names`: the heads by name; the one that dies is picked at random, regrown
heads come back in the trait's order (MonsterActions.heads_alive), and a legendary option with `requires_head` is offered
only while that head lives.

## Damage Threshold

`damage_threshold` on a stat block: less damage than that from one source does nothing (2024 DMG). A number, or
arithmetic counting the living, "5 * alive:<stat block>" (Legendary.counted: a boss whose hide hardens with each minion
still standing).

## Decoy images

A trait's `decoy_image` ({name, size, move_ft, save, while_flag, study, gone_flag, through}; DecoyImages): as initiative is
rolled, an image of the creature (`name`, default its own; `size`, default small) is put down beside it. It has no
turn and doesn't count for the fight's end; nothing harms it and no condition takes. At the start of its maker's turn
the AI sends it up to `move_ft` (60) toward the foe it wants. An attack or spell aimed at it, or an area it is caught in,
does nothing to it; while `while_flag` is set (always, when unset) the one who aimed it makes the `save` (Int DC 15):
failing, the log tells it as a miss, a spell shrugged off or a blow that may have landed; succeeding, they see through
it, and from then on it passes straight through. The Study action within 30 ft and the `study` check ({skill, dc})
unmask it, as `gone_flag` being set does (a boss phase's `flag`): it fades. The maker's stat-block actions named in `through` may be made from the image's
square when they can't reach from its own (the AI counts them as reachable from where it stands). A grapple or shove
aimed at the image is taken the same way as an attack.

## Throwing foes out

A trait's `throws_out` ({needs, reach}; FightOpenings): with its action the creature throws a foe within `reach` (5 ft)
that has one of the `needs` conditions (Paralyzed or Restrained) and stands within 5 ft of one of the fight's
`openings` out of it (docs/reference/contracts/locations.md). The foe falls the opening's drop (1d6 per 10 ft, Prone)
and is outside until a `climb` check at the start of one of its turns brings it back in. The AI throws whenever it can.

## Leaping as its turn starts

A trait's `turn_start_leap` ({`ft`: its Speed when unset, `when`: "bloodied" for only while it is Bloodied}): once at the
start of each of its turns it may move up to `ft` to an open square without provoking Opportunity Attacks, keeping its
own movement for the turn. The AI leaps beside the foe it would strike when that foe is out of its reach, or clear of
foes when its blows reach farther than 10 ft (MonsterActions.leap_ft and leap, AiBrain._leap).

## Fears

A trait's `fears` (names, stat block ids or creature types): when the creature starts its turn able to see one of them,
it is Frightened of that one until the start of its next turn (MonsterActions._fears; a creature in a shape counts as
the shape). `fear_modifiers` add to it while it lasts (Disadvantage on saves). A familiar that can't abide canines lists
the canine stat blocks.

## Things it shuns

`shuns_running_water: {damage, type, condition}`: the creature won't step or fly into deep water (unless it's already
in it); starting its turn in it, it takes the damage and gains the condition until the start of its next turn.
`shuns_item: {items, range}`: while it can see a foe within `range` ft carrying one of `items` (a mirror showing its
reflection), it has Disadvantage on D20 Tests (MonsterActions.water_blocks, shunned_in_sight).

## Spellcasting

`spellcasting: {ability, dc, attack, at_will, per_day: {"2": [...]}, levels: {spell: level}}`. Spells resolve
through SpellCaster with the stat block's numbers (MonsterActions.cast).

## AI profiles

`pack_hunter`, `brute`, `mindless`, `cowardly`, `skirmisher` (strikes, then Disengages or flies away), `swarm`,
`spellcaster` (Phantasmal Killer, Magic Missile from range, Etherealness to escape when badly hurt), `support`
(Divine Aid's Healing Word for a fallen ally), `strahd` (docs/contracts/combat.md "Bosses": legendary and lair
actions, `regenerates`, `forms`, `misty_escape`, `legendary_resistance`, `ward` and the action `summon` block).

## Conditional summon attacks

Monster extra-damage recipes may use `when.target_condition`; the attack's actual target is passed into damage selection. A rider's `unless_condition` suppresses reapplying that condition (Fungus Spirit's additional damage instead of refreshing Poisoned). Dinosaur and Plant Spirit choices derive their stat blocks from slot level and caster attack/DC. Siege damage doubles against represented structures/objects; scenery without combat durability is outside this operation.
