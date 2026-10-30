class_name BossPhases
extends RefCounted
## Boss phases (docs/contracts/combat.md "Boss phases"): a stat block's `phases` change the creature mid-fight when
## their trigger is met, once each, in the order the block lists them. A phase can heal it or give it a second life,
## refill its Legendary Resistance, add and take away traits and actions, swap its legendary and lair actions, turn the
## lair on, end what ails it, call allies, change its art and tell the story a flag. Actions and traits marked
## `"phase": "<id>"` in the block are held back until that phase begins (the Multiattack a boss gains when Bloodied).
## The block's `minions` say what its allies do when it falls (`vanish`: they go with it).
##
## The creature's stat block is rebuilt from its data at the start of the fight and each phase on top of it, so a
## loaded fight comes back the same (to_dict keeps the start data and the phases begun). Legendary owns this and calls
## the hooks below.

## Triggers, checked in this order of what can happen: after damage (bloodied, hp_below, at_zero, allies_down), at
## the start of its turn (round, flag), and when the story or a game module calls `enter`.
const TRIGGERS := ["bloodied", "hp_below", "at_zero", "allies_down", "round", "flag"]

var _legendary: WeakRef
## Creature id -> {base: the stat block at the fight's start, active: [phase ids begun, in order]}.
var _state: Dictionary = {}


func _init(legendary: Legendary) -> void:
	_legendary = weakref(legendary)


func leg() -> Legendary:
	return _legendary.get_ref() as Legendary


func enc() -> Encounter:
	return leg().enc()


static func phases_of(data: Dictionary) -> Array:
	return data.get("phases", []) as Array


## The phases `c` has begun, in order.
func active(c: Combatant) -> Array:
	return (_state.get(c.id, {}) as Dictionary).get("active", []) as Array


func is_active(c: Combatant, phase_id: String) -> bool:
	return phase_id in active(c)


## The fight begins: every creature whose block has phases (or phase-held parts) starts from its block without them.
func fight_started() -> void:
	for c in enc().combatants:
		watch(c)


## Starts keeping `c`'s phases (a creature that joins mid-fight, a summoned boss).
func watch(c: Combatant) -> void:
	if not c.creature is Monster or _state.has(c.id):
		return
	var data := (c.creature as Monster).data
	if phases_of(data).is_empty() and not _has_held(data):
		return
	_state[c.id] = {"base": data.duplicate(true), "active": []}
	_rebuild(c)


static func _has_held(data: Dictionary) -> bool:
	for key: String in ["traits", "actions", "bonus_actions", "reactions"]:
		for x: Variant in data.get(key, []):
			if x is Dictionary and (x as Dictionary).has("phase"):
				return true
	return false


## After damage lands on `c` (`was_up`: it had Hit Points before). True when a phase gave it a second life at 0 Hit
## Points, so the damage path skips its death.
func after_damage(c: Combatant, was_up: bool) -> bool:
	if not _state.has(c.id) or not was_up:
		return false
	var cr := c.creature
	var down := cr.dead or cr.hp <= 0
	if down:
		var second := _next(c, "at_zero")
		if second.is_empty():
			return false
		cr.dead = false
		enter(c, str(second["id"]))
		if cr.hp <= 0:
			cr.hp = 1
		return true
	for kind: String in ["bloodied", "hp_below", "allies_down"]:
		var ph := _next(c, kind)
		if not ph.is_empty():
			enter(c, str(ph["id"]))
	return false


## Someone fell: a phase waiting on its allies being down may begin.
func someone_fell() -> void:
	for id: String in _state.keys():
		var c := enc().get_c(id)
		if c != null and c.is_alive():
			var ph := _next(c, "allies_down")
			if not ph.is_empty():
				enter(c, str(ph["id"]))


## The start of `c`'s turn: a phase that waits for a round or a story flag.
func turn_start(c: Combatant) -> void:
	if not _state.has(c.id) or not c.is_alive():
		return
	for kind: String in ["round", "flag"]:
		var ph := _next(c, kind)
		if not ph.is_empty():
			enter(c, str(ph["id"]))


## The first phase not yet begun whose trigger is `kind` and is met now, or {}. Phases begin in the block's order:
## a later one never comes before an earlier one of the same kind.
func _next(c: Combatant, kind: String) -> Dictionary:
	for p: Variant in phases_of(_base(c)):
		var ph := p as Dictionary
		if str(ph["id"]) in active(c):
			continue
		var when := ph.get("when", {}) as Dictionary
		if not when.has(kind):
			continue
		if _met(c, when, kind):
			return ph
	return {}


func _met(c: Combatant, when: Dictionary, kind: String) -> bool:
	var cr := c.creature
	match kind:
		"bloodied":
			return cr.hp > 0 and cr.is_bloodied()
		"hp_below":
			return cr.hp > 0 and cr.hp < int(when["hp_below"])
		"at_zero":
			return true
		"round":
			return enc().round_no >= int(when["round"])
		"flag":
			return _flag_set(str(when["flag"]))
		"allies_down":
			var ids := when["allies_down"] as Array
			for o in enc().combatants:
				if o != c and o.side == c.side and str(MonsterActions.data_of(o).get("id", "")) in ids and o.is_alive() and not o.is_down():
					return false
			return true
	return false


## A flag this fight set (Legendary.story_flags: a phase, a withdraw, a game module's set piece).
func _flag_set(flag: String) -> bool:
	return bool(leg().story_flags.get(flag, false))


## Begins phase `phase_id` on `c` (once): the trigger met, or a game module or the story calling it.
func enter(c: Combatant, phase_id: String) -> bool:
	var e := enc()
	watch(c)
	if not _state.has(c.id) or phase_id in active(c):
		return false
	var ph := phase(c, phase_id)
	if ph.is_empty():
		return false
	var cr := c.creature as Monster
	var had_max := cr.max_hp()
	(_state[c.id]["active"] as Array).append(phase_id)
	_rebuild(c)
	var label := str(ph.get("name", phase_id.capitalize()))
	leg()._log("info", "%s: %s" % [c.name(), label], c, [str(ph.get("summary", ""))])
	# Hit Points: "full", "half" (of its maximum), a number to set, or `heal` to add.
	if ph.has("hp"):
		var to: Variant = ph["hp"]
		var full := cr.max_hp()
		var hp := full if str(to) == "full" else (full / 2 if str(to) == "half" else int(to))
		cr.hp = clampi(hp, 1, full)
		e.events.append({"type": "heal", "id": c.id, "amount": maxi(0, cr.hp)})
	elif ph.has("heal"):
		var healed := cr.heal(int(ph["heal"]), label)
		if healed > 0:
			e.events.append({"type": "heal", "id": c.id, "amount": healed})
	elif cr.max_hp() != had_max:
		cr.hp = mini(cr.hp, cr.max_hp())
	var lr: Variant = ph.get("legendary_resistance", null)
	if lr != null:
		if str(lr) == "refill":
			c.set_meta("legendary_resistance_used", 0)
		else:
			c.set_meta("legendary_resistance_used", maxi(0, leg().resistances(c) - int(lr)))
	if bool(ph.get("legendary_refill", false)) and leg().per_round(c) > 0:
		c.set_meta("legendary_left", leg().per_round(c))
	if bool(ph.get("end_conditions", false)):
		for fx: Effect in cr.effects.duplicate():
			if not fx.conditions.is_empty() and fx.caster_id != c.id:
				cr.remove_effect(fx)
		for cond: StringName in [&"prone", &"grappled", &"restrained", &"frightened", &"charmed", &"stunned", &"paralyzed"]:
			cr.remove_condition(cond)
		if e.grapples.has(c.id):
			e.grapples.erase(c.id)
	if bool(ph.get("lair", false)):
		e.lair = true
	if ph.has("flag"):
		leg().story_flags[str(ph["flag"])] = true
	var sm := ph.get("summon", {}) as Dictionary
	if not sm.is_empty():
		var made := leg()._summon(c, str(sm["monster"]), leg()._count(sm), c.cell, -1)
		if made > 0:
			leg()._log("info", "%s calls %d %s" % [c.name(), made, Legendary._plural(str(sm["monster"]), made)], c)
	e.events.append({"type": "phase", "id": c.id, "phase": phase_id, "name": label, "say": str(ph.get("say", ""))})
	e.events.append({"type": "condition", "id": c.id})
	return true


func phase(c: Combatant, phase_id: String) -> Dictionary:
	for p: Variant in phases_of(_base(c)):
		if str((p as Dictionary)["id"]) == phase_id:
			return p as Dictionary
	return {}


func _base(c: Combatant) -> Dictionary:
	if _state.has(c.id):
		return _state[c.id]["base"] as Dictionary
	return MonsterActions.data_of(c)


## `c`'s stat block now: its start data without the parts held for phases not begun, then each begun phase's changes.
func _rebuild(c: Combatant) -> void:
	var st := _state[c.id] as Dictionary
	var on := st["active"] as Array
	var data := (st["base"] as Dictionary).duplicate(true)
	for key: String in ["traits", "actions", "bonus_actions", "reactions"]:
		if not data.has(key):
			continue
		var kept: Array = []
		for x: Variant in data[key]:
			if x is Dictionary and (x as Dictionary).has("phase") and not str((x as Dictionary)["phase"]) in on:
				continue
			kept.append(x)
		data[key] = kept
	for id: Variant in on:
		var ph := phase(c, str(id))
		for key: String in ["traits", "actions", "bonus_actions", "reactions"]:
			var list := (data.get(key, []) as Array)
			for gone: Variant in ph.get("%s_remove" % key, []):
				list = list.filter(func(x: Variant) -> bool: return str((x as Dictionary).get("id", "")) != str(gone))
			for add: Variant in ph.get("%s_add" % key, []):
				var ad := add as Dictionary
				list = list.filter(func(x: Variant) -> bool: return str((x as Dictionary).get("id", "")) != str(ad.get("id", "")))
				list.append(ad.duplicate(true))
			data[key] = list
		for key2: String in ["legendary_actions", "lair_actions", "art", "art_height", "ai_profile", "ac", "speed",
				"resistances", "immunities", "vulnerabilities", "condition_immunities"]:
			if ph.has(key2):
				data[key2] = (ph[key2] as Variant).duplicate(true) if ph[key2] is Dictionary or ph[key2] is Array else ph[key2]
		if ph.has("legendary_resistance_max"):
			data["legendary_resistance"] = int(ph["legendary_resistance_max"])
	var m := c.creature as Monster
	m.set_block(data)


## The block's minions when it falls: `vanish` takes every creature it brought into the fight (its summons, or
## creatures whose block or encounter entry names it as `minion_of`) out of the fight with it.
func fell(c: Combatant) -> void:
	var data := _base(c) if _state.has(c.id) else MonsterActions.data_of(c)
	var mn := data.get("minions", {}) as Dictionary
	if str(mn.get("when_it_falls", "")) != "vanish":
		return
	var e := enc()
	var block_id := str(data.get("id", ""))
	for o in e.combatants:
		if o == c or not o.is_alive() or o.side != c.side:
			continue
		var by_summon := str(o.get_meta("summoner", "")) == c.id
		var by_name := str(o.get_meta("minion_of", MonsterActions.data_of(o).get("minion_of", ""))) == block_id
		if by_summon or by_name:
			leg().vanish(o, str(mn.get("narration", "")))


func to_dict() -> Dictionary:
	return _state.duplicate(true)


func from_dict(d: Dictionary) -> void:
	_state = d.duplicate(true)


## After a fight is loaded: each creature's block as its phases left it.
func after_restore() -> void:
	for id: String in _state.keys():
		var c := enc().get_c(id)
		if c != null and c.creature is Monster:
			_rebuild(c)
