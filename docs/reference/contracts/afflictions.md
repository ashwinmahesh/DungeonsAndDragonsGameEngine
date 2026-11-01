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
| `blocked_by` | a condition id: a creature immune to it can't gain levels. Missing: nothing keeps it out (poison immunity doesn't, unless the definition names `poisoned`) |

API (static, pure): `Afflictions.level_of(cr, id)`, `of(cr)` ({id: level}), `set_level(cr, id, level)`, `add(cr, id, n)`,
`clear(cr, id)`, `cure_by_spell(cr, spell_id, conditions)`, `after_long_rest(cr, dice)` (the lines for the rest screen).

Not yet (later branches): story statements and conditions that read and change a level, the party frames and sheet, a
symptom table on gaining a level, delayed onset, daily saves at a set hour, Exhaustion that can't be removed while
afflicted, Hit Point maximum lost per Long Rest.
