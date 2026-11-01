class_name Afflictions
extends RefCounted
## Afflictions: a lasting sickness or rot with levels, held per creature (docs/reference/contracts/afflictions.md). A
## campaign defines each in data/afflictions/<id>.json; a creature's level of it is an Effect (source kind
## `affliction`, never ending on its own) whose modifiers follow the level, so it is saved with the creature's
## effects. Pure rules: no nodes; every roll takes a DiceRoller.
##
## A definition: {id, name, summary, max_level (0: no limit), modifiers: [modifier with `per_level`: value times the
## level, or a flat value while afflicted], thresholds: [{at, modifiers, halve_hp}], long_rest: {save: {ability, dc},
## success, failure, min} (levels removed: an int, "mod:<ability>" or "half_mod:<ability>"), cures: [{spells: [ids] or
## ends: <condition>, remove: n or "all"}], blocked_by: <condition> (a creature immune to it can't be afflicted;
## nothing blocks it when missing)}.

const SOURCE := &"affliction"


## The definition of affliction `id` (the campaign's data), or {}.
static func definition(id: String) -> Dictionary:
	return Compendium.shared().get_entry("afflictions", id)


## The effect holding `cr`'s level of `id`, or null.
static func effect_of(cr: Creature, id: String) -> Effect:
	for fx in cr.effects:
		if fx.source_kind == SOURCE and fx.source_id == id:
			return fx
	return null


## `cr`'s level of affliction `id` (0 when it has none).
static func level_of(cr: Creature, id: String) -> int:
	var fx := effect_of(cr, id)
	return int(fx.data.get("level", 0)) if fx != null else 0


## Every affliction `cr` has: {id: level}.
static func of(cr: Creature) -> Dictionary:
	var out := {}
	for fx in cr.effects:
		if fx.source_kind == SOURCE:
			out[fx.source_id] = int(fx.data.get("level", 0))
	return out


## Sets `cr`'s level of `id` to `level` (0 removes it). `def`: the definition, when the caller has it (else the data's).
## Reaching a threshold that halves Hit Points halves the current ones too (to at least 1); dropping back below it
## lifts the threshold's modifiers. Returns the new level.
static func set_level(cr: Creature, id: String, level: int, def: Dictionary = {}) -> int:
	if def.is_empty():
		def = definition(id)
	var top := int(def.get("max_level", 0))
	var new_level := maxi(0, mini(level, top) if top > 0 else level)
	var old_level := level_of(cr, id)
	if new_level > old_level and def.has("blocked_by") and cr.is_condition_immune(StringName(str(def["blocked_by"]))):
		return old_level
	var old := effect_of(cr, id)
	if old != null:
		cr.remove_effect(old)
	if new_level <= 0:
		cr.log_event({"type": "affliction", "creature": cr.id, "affliction": id, "level": 0})
		return 0
	var name := str(def.get("name", id.capitalize()))
	var fx := Effect.new("%s %d" % [name, new_level], SOURCE, id)
	fx.ends = Effect.Ends.NEVER
	fx.data = {"affliction": id, "level": new_level}
	for raw: Variant in def.get("modifiers", []):
		fx.modifiers.append(_scaled(raw as Dictionary, new_level, name))
	for raw: Variant in def.get("thresholds", []):
		var th := raw as Dictionary
		if new_level >= int(th.get("at", 0)):
			for md: Variant in th.get("modifiers", []):
				fx.modifiers.append(_scaled(md as Dictionary, new_level, name))
	cr.add_effect(fx)
	for raw: Variant in def.get("thresholds", []):
		var th := raw as Dictionary
		var at := int(th.get("at", 0))
		if bool(th.get("halve_hp", false)) and old_level < at and new_level >= at:
			cr.hp = maxi(1, floori(cr.hp / 2.0))
	cr.hp = mini(cr.hp, cr.max_hp())
	cr.log_event({"type": "affliction", "creature": cr.id, "affliction": id, "level": new_level})
	return new_level


## Adds `n` levels of `id` to `cr` (a negative `n` removes them). Returns the new level.
static func add(cr: Creature, id: String, n: int = 1, def: Dictionary = {}) -> int:
	return set_level(cr, id, level_of(cr, id) + n, def)


## Removes every level of `id` from `cr`.
static func clear(cr: Creature, id: String) -> void:
	set_level(cr, id, 0)


## A modifier of a definition with its `per_level` worked out for `level`.
static func _scaled(md: Dictionary, level: int, name: String) -> Modifier:
	var d := md.duplicate(true)
	if d.has("per_level"):
		d["value"] = int(d["per_level"]) * level
		d.erase("per_level")
	return Modifier.make(d, name, SOURCE)


## Whether a spell `spell_id` ending `conditions` would ease any affliction `cr` has (cure_by_spell without the cure).
static func eased_by(cr: Creature, spell_id: String, conditions: Array) -> bool:
	for id: String in of(cr).keys():
		for raw: Variant in definition(id).get("cures", []):
			var cure := raw as Dictionary
			if spell_id in (cure.get("spells", []) as Array) or (cure.has("ends") and str(cure["ends"]) in conditions):
				return true
	return false


## What the UI shows for `cr`'s afflictions, in the order they came: [{id, name, level, summary, label ("<name> <level>")}].
static func shown(cr: Creature) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fx in cr.effects:
		if fx.source_kind != SOURCE:
			continue
		var def := definition(fx.source_id)
		var name := str(def.get("name", fx.source_id.capitalize()))
		var level := int(fx.data.get("level", 0))
		out.append({"id": fx.source_id, "name": name, "level": level, "summary": str(def.get("summary", "")),
			"label": "%s %d" % [name, level]})
	return out


## The highest level of `id` among `creatures` (0 when none has it).
static func highest(creatures: Array, id: String) -> int:
	var top := 0
	for c: Variant in creatures:
		if c is Creature and not (c as Creature).dead:
			top = maxi(top, level_of(c as Creature, id))
	return top


## A spell `spell_id` landing on `cr` that ends `conditions` (the ones it ended or could end): each affliction's cures
## that match it remove their levels. Returns a line per affliction eased ("" none).
static func cure_by_spell(cr: Creature, spell_id: String, conditions: Array) -> Array[String]:
	var lines: Array[String] = []
	for id: String in of(cr).keys():
		var def := definition(id)
		var remove := 0
		for raw: Variant in def.get("cures", []):
			var cure := raw as Dictionary
			var hit := spell_id in (cure.get("spells", []) as Array) or (cure.has("ends") and str(cure["ends"]) in conditions)
			if not hit:
				continue
			var n := 1 << 30 if str(cure.get("remove", 1)) == "all" else int(cure.get("remove", 1))
			remove = maxi(remove, n)
		if remove <= 0:
			continue
		var before := level_of(cr, id)
		var after := set_level(cr, id, before - remove, def)
		lines.append(_eased(cr, def, id, before, after))
	return lines


## After a Long Rest: each affliction's recovery save (long_rest), removing levels by its result. A threshold left
## behind gives back its Hit Points (the rest restores them all). Returns a line per affliction.
static func after_long_rest(cr: Creature, dice: DiceRoller) -> Array[String]:
	var lines: Array[String] = []
	if cr.dead:
		return lines
	for id: String in of(cr).keys():
		var def := definition(id)
		var rest := def.get("long_rest", {}) as Dictionary
		if rest.is_empty():
			continue
		var before := level_of(cr, id)
		var remove := 0
		var said := ""
		if rest.has("save"):
			var sv := rest["save"] as Dictionary
			var ab := StringName(str(sv.get("ability", "con")))
			var t := cr.roll_save(dice, ab, int(sv.get("dc", 10)), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab],
				str(def.get("name", id)), cr.name])
			remove = _amount(cr, rest.get("success" if t.success else "failure", 0))
			said = " (%s)" % t.describe()
		else:
			remove = _amount(cr, rest.get("success", 0))
		remove = maxi(remove, int(rest.get("min", 0)))
		if remove <= 0:
			continue
		var after := set_level(cr, id, before - remove, def)
		cr.hp = cr.max_hp()
		lines.append(_eased(cr, def, id, before, after) + said)
	return lines


## A number of levels: an int, "mod:<ability>" (the ability modifier) or "half_mod:<ability>" (half of it, rounded down).
static func _amount(cr: Creature, v: Variant) -> int:
	var s := str(v)
	if s.begins_with("mod:"):
		return cr.ability_mod(StringName(s.substr(4)))
	if s.begins_with("half_mod:"):
		return floori(cr.ability_mod(StringName(s.substr(9))) / 2.0)
	return int(v)


static func _eased(cr: Creature, def: Dictionary, id: String, before: int, after: int) -> String:
	var name := str(def.get("name", id.capitalize()))
	if after <= 0:
		return "%s is free of the %s." % [cr.name, name]
	return "%s's %s eases from level %d to %d." % [cr.name, name, before, after]
