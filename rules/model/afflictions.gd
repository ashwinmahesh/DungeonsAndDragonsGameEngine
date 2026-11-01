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
	# Symptoms (rolled on gaining a level, roll_symptom) stay while the level holds or grows, and all go on any reduction.
	var symptoms: Array = (old.data.get("symptoms", []) as Array).duplicate() if old != null and new_level >= old_level else []
	# What the clock keeps on it (AfflictionClock): dormant_until, successes, held, max_hp_lost.
	var kept := {}
	if old != null:
		for k: String in ["dormant_until", "successes", "held", "max_hp_lost", "suppress_hours", "suppressed_until", "dead_seen"]:
			if old.data.has(k):
				kept[k] = old.data[k]
	if old != null:
		cr.remove_effect(old)
	if new_level <= 0:
		cr.log_event({"type": "affliction", "creature": cr.id, "affliction": id, "level": 0})
		return 0
	var name := str(def.get("name", id.capitalize()))
	var fx := Effect.new("%s %d" % [name, new_level], SOURCE, id)
	fx.ends = Effect.Ends.NEVER
	fx.data = {"affliction": id, "level": new_level, "symptoms": symptoms}
	fx.data.merge(kept)
	# Hit Points lost for good to it (`long_rest.max_hp_loss`), while it lasts.
	if int(kept.get("max_hp_lost", 0)) > 0:
		fx.modifiers.append(Modifier.make({"stat": "hp_max", "value": -int(kept["max_hp_lost"])}, name, SOURCE))
	# Asleep (`onset_hours` not yet passed) or held down by a spell (`suppressed_by`): none of what it does, for now.
	var dormant := int(kept.get("dormant_until", -1)) >= 0 or int(kept.get("suppress_hours", 0)) > 0 \
		or int(kept.get("suppressed_until", -1)) >= 0
	# Exhaustion it won't let go of (`exhaustion_lock`): a Long Rest takes none away while it lasts.
	if bool(def.get("exhaustion_lock", false)) and not dormant:
		fx.modifiers.append(Modifier.make({"stat": "flag", "value": "exhaustion_locked"}, name, SOURCE))
	for raw: Variant in ([] if dormant else def.get("modifiers", [])):
		fx.modifiers.append(_scaled(raw as Dictionary, new_level, name))
	for raw: Variant in ([] if dormant else def.get("thresholds", [])):
		var th := raw as Dictionary
		if new_level >= int(th.get("at", 0)):
			for md: Variant in th.get("modifiers", []):
				fx.modifiers.append(_scaled(md as Dictionary, new_level, name))
	for sid: Variant in symptoms:
		var sym := symptom(def, str(sid))
		for md: Variant in sym.get("modifiers", []):
			fx.modifiers.append(_scaled(md as Dictionary, new_level, str(sym.get("name", name))))
		for cond: Variant in sym.get("conditions", []):
			fx.conditions.append(StringName(str(cond)))
	cr.add_effect(fx)
	for raw: Variant in def.get("thresholds", []):
		var th := raw as Dictionary
		var at := int(th.get("at", 0))
		if bool(th.get("halve_hp", false)) and old_level < at and new_level >= at:
			cr.hp = maxi(1, floori(cr.hp / 2.0))
	cr.hp = mini(cr.hp, cr.max_hp())
	cr.log_event({"type": "affliction", "creature": cr.id, "affliction": id, "level": new_level})
	return new_level


## Symptom `sid` of a definition's `symptoms.table`, or {}.
static func symptom(def: Dictionary, sid: String) -> Dictionary:
	for raw: Variant in (def.get("symptoms", {}) as Dictionary).get("table", []):
		if str((raw as Dictionary).get("id", "")) == sid:
			return raw as Dictionary
	return {}


## What `cr`'s symptoms ask the fight to do at `key` (`on_initiative`, `on_hurt`): [{symptom, hook, affliction}].
static func hooks(cr: Creature, key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fx in cr.effects:
		if fx.source_kind != SOURCE:
			continue
		var def := definition(fx.source_id)
		for sid: Variant in fx.data.get("symptoms", []):
			var sym := symptom(def, str(sid))
			if sym.get(key, null) is Dictionary:
				out.append({"symptom": sym, "hook": sym[key], "affliction": str(def.get("name", fx.source_id))})
	return out


## The symptoms `cr` has of `id` (their ids).
static func symptoms_of(cr: Creature, id: String) -> Array[String]:
	var out: Array[String] = []
	var fx := effect_of(cr, id)
	if fx != null:
		for s: Variant in fx.data.get("symptoms", []):
			out.append(str(s))
	return out


## A level of `id` gained where its symptoms strike (the caller checks `symptoms.when`): the save in `symptoms.save`, and on
## a failure (or with no save) a symptom from the table `cr` doesn't have yet, picked with `dice`, its modifiers and
## conditions joining the affliction's. Returns the line to show ("" when nothing came).
static func roll_symptom(cr: Creature, id: String, dice: DiceRoller) -> String:
	var def := definition(id)
	var sy := def.get("symptoms", {}) as Dictionary
	var fx := effect_of(cr, id)
	if sy.is_empty() or fx == null:
		return ""
	if sy.has("save"):
		var sv := sy["save"] as Dictionary
		var ab := StringName(str(sv.get("ability", "con")))
		var t := cr.roll_save(dice, ab, int(sv.get("dc", 10)), [], [], "%s save vs a symptom of %s (%s)" % [Creature.ABILITY_NAMES[ab],
			str(def.get("name", id)), cr.name])
		if t.success:
			return ""
	var had := symptoms_of(cr, id)
	var open: Array[Dictionary] = []
	for raw: Variant in sy.get("table", []):
		if not str((raw as Dictionary).get("id", "")) in had:
			open.append(raw as Dictionary)
	if open.is_empty():
		return ""
	var picked := open[dice.roll_one(open.size(), "%s symptom" % str(def.get("name", id))) - 1]
	had.append(str(picked["id"]))
	(fx.data["symptoms"] as Array).assign(had)
	set_level(cr, id, level_of(cr, id), def)   # rebuilt with the new symptom
	return "%s: %s" % [cr.name, str(picked.get("summary", picked.get("name", "")))]


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
		# A spell that holds it down (`suppressed_by` {spells, hours}): none of what it does for that long (AfflictionClock
		# starts the hours at its next look).
		var sup := def.get("suppressed_by", {}) as Dictionary
		if spell_id in (sup.get("spells", []) as Array):
			effect_of(cr, id).data["suppress_hours"] = int(sup.get("hours", 24))
			set_level(cr, id, level_of(cr, id), def)
			lines.append("%s's %s is held down for %d hours." % [cr.name, str(def.get("name", id)), int(sup.get("hours", 24))])
		# A spell that holds it off (`held_off_by`): the next daily save doesn't come (AfflictionClock).
		if spell_id in (def.get("held_off_by", []) as Array):
			effect_of(cr, id).data["held"] = true
			lines.append("%s's %s is held off for a day." % [cr.name, str(def.get("name", id))])
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
		# Hit Points lost for good with each rest it lasts (`max_hp_loss`: dice).
		if str(rest.get("max_hp_loss", "")) != "":
			var lost := int(dice.roll_expr(str(rest["max_hp_loss"]), "%s (%s)" % [str(def.get("name", id)), cr.name])["total"])
			var fx := effect_of(cr, id)
			fx.data["max_hp_lost"] = int(fx.data.get("max_hp_lost", 0)) + lost
			set_level(cr, id, before, def)
			cr.hp = mini(cr.hp, cr.max_hp())
			lines.append("%s's %s takes %d from their Hit Point maximum." % [cr.name, str(def.get("name", id)), lost])
			# Nothing left: it kills (a maximum worn down to 0).
			if cr.max_hp() <= 0:
				cr.hp = 0
				cr.dead = true
				cr.log_event({"type": "died", "creature": cr.id, "of": id})
				lines.append("%s dies of the %s." % [cr.name, str(def.get("name", id))])
				continue
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
