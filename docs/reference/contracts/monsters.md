# Monster stat blocks in a fight (data/monsters → combat/monster_actions.gd, combat/ai/ai_brain.gd)

Numbers are the 2024 stat block's. These machine-readable keys sit next to the prose `text`.

## Actions

| key | meaning |
|---|---|
| `kind` | `melee`, `ranged`, `save`, `multiattack`, `spellcasting`, `special` |
| `attack`, `damage` | attack bonus and reach or range; damage entries (extra entries add dice; `if: bloodied` / `not_bloodied` picks a swarm's damage) |
| `on_hit` | riders after a hit (below) |
| `save`, `targets`, `on_fail` | a saving-throw action: who it can target (`range`, `count`, `max_size`, `in_space`, `requires`: grappled / incapacitated / restrained / willing), damage, riders on a failure |
| `area` on a save action | `{shape, size, width}`: `space`, `cone`, `line`, `emanation` and the rest; everyone in it is caught (MonsterActions.area_cells, save_victims). A creature's meta `area_bonus_ft` (an int of feet, 0 when missing or negative) grows its emanations, cones and lines, and how far it can aim them (`targets.range`), by that much, its legendary options' areas with them (MonsterActions.area_size) |
| `multiattack[].or` | alternatives for that slot (Scimitar or Pistol); the AI picks what reaches, a save action first when it has a target |
| `multiattack[].count` | the AI begins the Multiattack itself (`begin_multiattack`). A creature the player runs (a summon, a shaped or dominated creature, a story ally) begins it with its first listed attack: `attacks_per_action` is the total, an attack the Multiattack doesn't list is one attack, and a listed save action (a Draconic Spirit's Breath Weapon) takes the place of one attack |
| `recharge`, `uses` | Recharge X-6 rolled at the start of the monster's turn; uses per day |
| `forms` | Shape-Shift forms that can use it (the Werewolf's Bite) |
| `weapon` | a held weapon (Disarming Attack) |
| `ac_bonus` | Parry: +AC against one melee hit while holding a weapon |
| `do`, `cast` | special Bonus Actions: `dash_or_disengage`, `hide_in_dim`, `shape_shift`, `cast` (Divine Aid's spells) |

## Riders (`on_hit[]`, `on_fail[]`)

`{do, save, until, not_types, only_types, not_species, max_size, immune_on_success, ...}`:
`condition` (with `until`: target_turn_end, target_turn_start, source_turn_start, source_turn_end, minute, permanent;
optional `modifiers`), `grapple` (`escape_dc`, `limit`), `pull` / `push` (`feet`), `drain_max_hp` and `heal_self`
(`type`), `ability_drain` (`ability`, `dice`), `curse` (lycanthropy), `engulf` (`escape_dc`, `damage`, `conditions`).

## Traits read by code

`aura` (`radius`, `trigger: start_turn`, `save`, `condition`, `until`, `immune_on_success`, `affects`): Stench,
Festering Aura. `absorb`: Lightning Absorption. `sunlight`: `sensitivity`, `weakness`, `hypersensitivity`.
Flags: `pack_tactics`, `undead_fortitude`, `incorporeal_movement`, `spider_climb`, `swarm`, `flyby`,
`pass_through_creatures`, `loathsome_limbs` (by trait id). `make validate` runs tools/data/check_implemented.py,
which fails if a trait or feature says `"implemented": "engine"` and no code reads it.

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
