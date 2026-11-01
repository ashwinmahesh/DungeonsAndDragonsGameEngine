# Afflictions (data/afflictions → rules/model/afflictions.gd)

A lasting sickness, rot or curse with levels, held per creature (heroes and monsters alike). A campaign defines each
in its own `data/afflictions/<id>.json`; the engine ships none. A creature's level of one is an Effect (source kind
`affliction`, source id the affliction's id, `data.level`, never ending on its own), so it is saved and loaded with the
creature's effects and needs no save change. Its modifiers are rebuilt whenever the level changes.

| key | meaning |
|---|---|
| `id`, `name`, `summary` | as everywhere; the effect is named "<name> <level>" |
| `max_level` | the highest level (0 or missing: no limit) |
| `modifiers` | modifiers (modifiers.md) while afflicted; `per_level: n` makes the value n times the level (`{"stat": "save", "ability": "con", "per_level": -1}`) |
| `thresholds` | `[{at, modifiers, halve_hp}]`: modifiers added while the level is `at` or more; `halve_hp` halves the current Hit Points (to at least 1) when the level first reaches `at` (with `hp_max_percent` 50 for the maximum, which comes back below it) |
| `long_rest` | the recovery after a Long Rest (LongRest's benefits): `save {ability, dc}`, levels removed on `success` and on `failure` (an int, `mod:<ability>` or `half_mod:<ability>`), at least `min`. Without `save`, `success` is removed every rest. A rest that drops a threshold restores the whole maximum |
| `cures` | `[{spells: [ids] or ends: <condition>, remove: n or "all"}]`: a spell in `spells`, or one whose `end_condition` ends (or, with a choice, was aimed at) `ends`, removes levels, once a casting, whether or not the creature had that condition (SpellEffects._end_condition) |
| `symptoms` | `{when, save: {ability, dc}, table: [{id, name, summary, conditions, modifiers}]}`: where `when` holds (the story checks it; `afflict` does), each level gained brings, after a failed `save` (or always without one), a symptom from the table the creature hasn't got, picked by DiceRoller; its conditions and modifiers join the affliction's effect. They stack, and any reduction of the level clears them all (`Afflictions.roll_symptom`, `symptoms_of`) |
| `symptoms.table[].on_initiative` | `{save {ability, dc}, flag ("confused"), rounds (10)}`: as Initiative is rolled, a failed save puts the creature under that flag for the fight (`confused`: it acts as Confusion makes it; EncounterTurns) |
| `symptoms.table[].on_hurt` | `{dice, type}`: each time the creature takes damage it takes that much more, once a blow (EncounterDamage) |
| `blocked_by` | a condition id: a creature immune to it can't gain levels. Missing: nothing keeps it out (poison immunity doesn't, unless the definition names `poisoned`) |

API (static, pure): `Afflictions.level_of(cr, id)`, `of(cr)` ({id: level}), `set_level(cr, id, level)`, `add(cr, id, n)`,
`clear(cr, id)`, `cure_by_spell(cr, spell_id, conditions)`, `after_long_rest(cr, dice)` (the lines for the rest screen).

In the story: `afflict <id> <+n|-n|clear> [party]` (docs/reference/contracts/dialogue.md) gains, loses or clears levels
for the hero in the conversation or every living hero, with a notice; the condition `affliction.<id> >= n` reads the
highest level among the living heroes (bare: anyone has it). The temple's Lesser Restoration (story/services.gd) serves
a hero it would ease (`Afflictions.eased_by`), aiming at the poison when nothing else is to end.

Shown: `Afflictions.shown(cr)` ({id, name, level, summary, label}) puts a "<name> <level>" pill on the exploration party
cards and the party screen, and a row on the character sheet whose rules card lists what it does at this level; the sheet's
effects list shows the effect itself.

Not yet (later branches): delayed onset, daily saves at a set hour, Exhaustion that can't be removed while
afflicted, Hit Point maximum lost per Long Rest.
