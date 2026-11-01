class_name FightMeters
extends RefCounted
## A fight's meters (an encounter's `meters`, docs/reference/contracts/combat.md "Meters"): a named count the fight is
## about, such as a frightened guide's loyalty or the pips of a rite, shown on the combat HUD. The heroes move it with
## the meter's actions (a check, as an action or a Bonus Action, near what it names); reaching a mark sets a flag for
## the story or ends the fight. Kept in a round's save (EncounterSnapshot).
##
## A meter: {id, label, start (0), min (0), max, actions: [{id, label, cost (action or bonus), near (an object id or a
## creature's name; anywhere when missing), range (5), check: {skill, dc} (none: it simply works, a word said plainly),
## success (+1), failure (0), failure_damage: {dice, type, or a list of types one is rolled from} (to whoever failed),
## once (once a fight), when (a story condition, read as the fight starts: for_story); for a rite (vault "Design - Final
## Rites as a fight objective"): check `skills` (the hero rolls the best of them) or `any_skill`, advantage_when (a story
## condition: Advantage), brilliant ({by, meter}: a success by that much moves a second meter), failure_event ({affects,
## save: {ability, dc}, damage, condition, instead: {damage}}: a burst on everyone it reaches, a hero who failed may
## take the `instead` damage rather than the condition)}], store (a story flag the value is set to as the fight ends),
## pips (the HUD draws pips), menu (its actions fold under one hotbar entry of that name: a rite's Honour the Fallen),
## marks: [{value, falling (reached going down to it; else going up), flag, outcome
## (victory, defeat or ended), say}]}.

var _enc: WeakRef
## id -> the meter's data.
var defs: Dictionary = {}
## id -> its value now.
var values: Dictionary = {}
## "<meter id>:<mark index>" for the marks already reached.
var reached: Dictionary = {}
## "<meter id>:<action id>" for the `once` actions already taken.
var used: Dictionary = {}
## Rounds the fight's clock (`ends_when.rounds`) has lost or gained (a round event's `clock`: a fire burst that catches
## the captive), and whether it has run out (EncounterTurns.clock_left).
var clock_lost: int = 0
var clock_rang: bool = false


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## The fight's meters from its entry. Values a saved round brought back (from_dict) are kept.
func setup(list: Array) -> void:
	defs.clear()
	for raw: Variant in list:
		var d := raw as Dictionary
		var id := str(d.get("id", ""))
		if id == "":
			continue
		defs[id] = d.duplicate(true)
		if not values.has(id):
			values[id] = int(d.get("start", 0))


## `list` (an encounter's `meters`) with each action whose `when` doesn't hold in `st` left out (a word only a hero who
## found the token can say).
static func for_story(list: Array, st: StoryState) -> Array:
	var out: Array = []
	for raw: Variant in list:
		var d := (raw as Dictionary).duplicate(true)
		d["actions"] = (d.get("actions", []) as Array).filter(func(a: Variant) -> bool:
			return st == null or StoryConditions.check(str((a as Dictionary).get("when", "")), st))
		for a: Variant in d["actions"]:
			var cond := str((a as Dictionary).get("advantage_when", ""))
			if cond != "" and st != null and StoryConditions.check(cond, st):
				(a as Dictionary)["advantage"] = true   # a theme backed by what the party learned
		out.append(d)
	return out


func value(id: String) -> int:
	return int(values.get(id, 0))


## The HUD's line for each meter: "<label> <value>/<max>".
func lines() -> Array[String]:
	var out: Array[String] = []
	for id: String in defs:
		var d := defs[id] as Dictionary
		if bool(d.get("pips", false)) and d.has("max"):
			out.append("%s %s" % [str(d.get("label", id.capitalize())), "●".repeat(value(id)) + "○".repeat(maxi(0, int(d["max"]) - value(id)))])
			continue
		var top := " / %d" % int(d["max"]) if d.has("max") else ""
		out.append("%s %d%s" % [str(d.get("label", id.capitalize())), value(id), top])
	return out


## Moves meter `id` by `delta` (kept between its min and max) and reaches its marks.
func change(id: String, delta: int) -> void:
	var e := enc()
	if not defs.has(id) or delta == 0:
		return
	var d := defs[id] as Dictionary
	var before := value(id)
	var after := before + delta
	after = maxi(int(d.get("min", 0)), after)
	if d.has("max"):
		after = mini(int(d["max"]), after)
	values[id] = after
	e.events.append({"type": "meter", "id": id, "value": after, "from": before})
	var marks := d.get("marks", []) as Array
	for i in marks.size():
		var m := marks[i] as Dictionary
		var key := "%s:%d" % [id, i]
		var at := int(m.get("value", 0))
		var hit := (after <= at and before > at) if bool(m.get("falling", false)) else (after >= at and before < at)
		if not hit or reached.has(key):
			continue
		reached[key] = true
		if str(m.get("flag", "")) != "":
			e.legendary.story_flags[str(m["flag"])] = true
		e.events.append({"type": "meter_mark", "id": id, "value": after, "say": str(m.get("say", ""))})
		var outcome := str(m.get("outcome", ""))
		if outcome in ["victory", "defeat", "ended"] and e.state == Encounter.State.ACTIVE:
			e.turns._finish(outcome)
			return
	if e.state == Encounter.State.ACTIVE and not (e.ends_when.get("meters_needed", []) as Array).is_empty():
		e._check_over()   # the meter the fight needed is full: won, if the foes are down too


# --- The heroes' actions --------------------------------------------------------------------------------

## The hotbar's entries for `c`: each meter action, id "meter:<meter id>:<action id>" (heroes only).
func entries(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.side in [&"party", &"guest"]:
		return out
	for id: String in defs:
		for raw: Variant in (defs[id] as Dictionary).get("actions", []):
			var a := raw as Dictionary
			var check := a.get("check", {}) as Dictionary
			out.append({"id": "meter:%s:%s" % [id, str(a.get("id", ""))], "label": str(a.get("label", "Help")),
				"sub": ("DC %d %s%s" % [int(check.get("dc", 10)), str(skill_for(c, check)).replace("_", " ").capitalize(),
					" (Advantage)" if bool(a.get("advantage", false)) else ""]) if not check.is_empty() else "No check",
				"cost": "bonus" if str(a.get("cost", "action")) == "bonus" else "action", "why": why_not(c, a),
				"help": "%s %+d on a success%s." % [str((defs[id] as Dictionary).get("label", id)), int(a.get("success", 1)),
					(", %+d on a failure" % int(a["failure"])) if int(a.get("failure", 0)) != 0 else ""],
				"menu": str((defs[id] as Dictionary).get("menu", "")),
				"menu_sub": ("%s DC %d%s" % [str(skill_for(c, check)).replace("_", " ").capitalize(), int(check.get("dc", 10)),
					" (Adv)" if bool(a.get("advantage", false)) else ""]) if not check.is_empty() else "No check"})
	return out


func _action(meter_id: String, action_id: String) -> Dictionary:
	for raw: Variant in (defs.get(meter_id, {}) as Dictionary).get("actions", []):
		if str((raw as Dictionary).get("id", "")) == action_id:
			return raw as Dictionary
	return {}


## "" if `c` can take meter action `a` now, else why not.
func why_not(c: Combatant, a: Dictionary) -> String:
	var e := enc()
	var why := e._bonus_check(c) if str(a.get("cost", "action")) == "bonus" else e._action_check(c)
	if why != "":
		return why
	if bool(a.get("once", false)) and used.has(_key(a)):
		return "Done already this fight"
	var near := str(a.get("near", ""))
	if near == "":
		return ""
	var reach := int(a.get("range", 5))
	var o := e.objects.get_object(near)
	if o != null:
		return "" if not o.destroyed and e.objects.distance_ft(c, o) <= reach else "Get within %d ft of %s first" % [reach, o.the()]
	for t in e.combatants:
		if t.name() == near and t.is_alive() and not t.has_meta("left_fight"):
			return "" if e.distance(c, t) <= reach else "Get within %d ft of %s first" % [reach, t.name()]
	return "%s isn't here" % near


## Takes meter action `action_id` of meter `meter_id`: spends its cost, rolls its check, and moves the meter.
func take(c: Combatant, meter_id: String, action_id: String) -> CombatResult:
	var e := enc()
	var a := _action(meter_id, action_id)
	if a.is_empty():
		return CombatResult.fail("Nothing to do for that")
	var why := why_not(c, a)
	if why != "":
		return CombatResult.fail(why)
	if str(a.get("cost", "action")) == "bonus":
		c.bonus_available = false
	else:
		e.spend_action(c)
	if bool(a.get("once", false)):
		used[_key(a)] = true
	var check := a.get("check", {}) as Dictionary
	var skill := skill_for(c, check)
	var label := str(a.get("label", "Help"))
	if check.is_empty():   # no check: it simply works
		e.events.append({"type": "ability", "source": "feature", "by": c.id, "key": "meter:%s:%s" % [meter_id, action_id], "targets": [], "cells": []})
		e.log.add("info", "%s: %s" % [c.name(), label], c.id)
		change(meter_id, int(a.get("success", 1)))
		return CombatResult.new()
	var adv: Array[String] = []
	if bool(a.get("advantage", false)):
		adv.append("Remembered")
	var t := c.creature.roll_check(e.dice, skill, int(check.get("dc", 10)), adv, [], "%s: %s check (%s)" % [label,
		str(skill).capitalize(), c.name()])
	e.events.append({"type": "ability", "source": "feature", "by": c.id, "key": "meter:%s:%s" % [meter_id, action_id], "targets": [], "cells": []})
	if t.success:
		e.log.add("info", "%s: %s succeeds" % [c.name(), label], c.id, [t.describe()])
		var brilliant := a.get("brilliant", {}) as Dictionary
		if not brilliant.is_empty() and t.total >= int(check.get("dc", 10)) + int(brilliant.get("by", 5)):
			e.log.add("info", "A brilliant success", c.id)
			change(str(brilliant["meter"]), 1)
		change(meter_id, int(a.get("success", 1)))
		return CombatResult.new()
	e.log.add("info", "%s: %s fails" % [c.name(), label], c.id, [t.describe()])
	var hurt := a.get("failure_damage", {}) as Dictionary
	if not hurt.is_empty():
		var rolled := e.damage._roll_damage_dice(str(hurt.get("dice", "1d6")), false, 0, label)
		var type: Variant = hurt.get("type", "force")
		if type is Array:   # one of several (a torch, an apple or a crown: fire, poison or piercing)
			type = (type as Array)[e.dice.roll_one((type as Array).size(), "%s: damage type" % label) - 1]
		e.deal_damage(c, c, [{"amount": int(rolled["total"]), "type": str(type)}], false, label,
			["%s %s: %s" % [label, str(hurt.get("dice", "1d6")), str(rolled["text"])]])
	change(meter_id, int(a.get("failure", 0)))
	var burst := a.get("failure_event", {}) as Dictionary
	if not burst.is_empty() and e.state == Encounter.State.ACTIVE:
		return _burst(burst, label)
	return CombatResult.new()


## The skill `c` rolls for `check`: its `skill`, or the best of its `skills` (all of them with `any_skill`).
func skill_for(c: Combatant, check: Dictionary) -> StringName:
	var options: Array = Abilities.SKILLS.keys() if bool(check.get("any_skill", false)) else check.get("skills", [])
	if options.is_empty():
		return StringName(str(check.get("skill", "athletics")))
	var best := StringName(str(options[0]))
	for s: Variant in options:
		if c.creature.skill_bonus(StringName(str(s))).total() > c.creature.skill_bonus(best).total():
			best = StringName(str(s))
	return best


## A failed check's burst (a rite's mocking spirits): everyone it reaches saves; a failure takes the damage and has the
## condition until the end of its next turn, unless a hero takes the `instead` damage, asked one by one.
func _burst(o: Dictionary, label: String) -> CombatResult:
	var e := enc()
	var r := CombatResult.new()
	var rounds := e.legendary.round_events
	var sv := o.get("save", {}) as Dictionary
	return e.each(rounds._reached(o), func(tv: Variant) -> CombatResult:
		var t := tv as Combatant
		if not t.is_alive() or e.state != Encounter.State.ACTIVE:
			return r
		var ab := StringName(str(sv.get("ability", "wis")))
		var test := t.creature.roll_save(e.dice, ab, int(sv.get("dc", 13)), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, t.name()])
		if test.success:
			e.log.add("info", "%s resists %s" % [t.name(), label], t.id, [test.describe()])
			return r
		_hurt(t, o.get("damage", {}) as Dictionary, label, [test.describe()])
		var cond := str(o.get("condition", ""))
		if cond == "" or not t.is_alive():
			return r
		var instead := (o.get("instead", {}) as Dictionary).get("damage", {}) as Dictionary
		if instead.is_empty() or e._reaction_decision(t, "rite_burst") != "ask":
			rounds._condition(t, cond, "target_turn_end", label)
			e.events.append({"type": "condition", "id": t.id})
			return r
		var req := ReactionRequest.new("rite_burst", t.id, "")
		req.title = label
		req.text = "Take %s %s damage rather than be %s until the end of your next turn?" % [str(instead.get("dice", "6d6")),
			str(instead.get("type", "psychic")).capitalize(), cond.capitalize()]
		req.cost = "No action or Reaction"
		req.spends_reaction = false
		req.continuation = func(use: bool) -> CombatResult:
			if use:
				_hurt(t, instead, label, [])
			elif t.is_alive():
				rounds._condition(t, cond, "target_turn_end", label)
				e.events.append({"type": "condition", "id": t.id})
			return r
		e.pending = req
		return r, func() -> CombatResult:
			e._check_over()
			return r)


func _hurt(t: Combatant, dmg: Dictionary, label: String, details: Array[String]) -> void:
	if dmg.is_empty():
		return
	var e := enc()
	var rolled := e._roll_damage_dice(str(dmg.get("dice", "1d6")), false, 0, label)
	var more := details.duplicate()
	more.append(str(rolled["text"]))
	e.deal_damage(null, t, [{"amount": int(rolled["total"]), "type": str(dmg.get("type", "psychic"))}], false, label, more)


## As the fight ends: each meter with `store` sets that story flag to its value (a beacon's brilliant successes).
func store_values() -> void:
	var e := enc()
	for id: String in defs:
		var flag := str((defs[id] as Dictionary).get("store", ""))
		if flag != "":
			e.legendary.story_flags[flag] = value(id)


func _key(a: Dictionary) -> String:
	for id: String in defs:
		if ((defs[id] as Dictionary).get("actions", []) as Array).has(a):
			return "%s:%s" % [id, a.get("id", "")]
	return str(a.get("id", ""))


## Moves the fight's clock by `rounds` (negative: it runs out sooner).
func shift_clock(rounds: int) -> void:
	clock_lost -= rounds
	var e := enc()
	e.events.append({"type": "clock_shift", "rounds": rounds, "left": e.turns.clock_left()})


func to_dict() -> Dictionary:
	return {"values": values.duplicate(), "reached": reached.duplicate(), "used": used.duplicate(), "clock_lost": clock_lost,
		"clock_rang": clock_rang}


func from_dict(d: Dictionary) -> void:
	values = (d.get("values", {}) as Dictionary).duplicate()
	reached = (d.get("reached", {}) as Dictionary).duplicate()
	used = (d.get("used", {}) as Dictionary).duplicate()
	clock_lost = int(d.get("clock_lost", 0))
	clock_rang = bool(d.get("clock_rang", false))
