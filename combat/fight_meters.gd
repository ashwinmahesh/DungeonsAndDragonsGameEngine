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
## once (once a fight), when (a story condition, read as the fight starts: for_story)}], marks: [{value, falling (reached going down to it; else going up), flag, outcome
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
## How far into the encounter's events the meters' `on` rules have looked (scan); back to 0 as the view drains them.
var _scanned := 0
## Creature ids already counted as defeated (a fall and then a death count once).
var _defeated: Dictionary = {}


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
		out.append(d)
	return out


func value(id: String) -> int:
	return int(values.get(id, 0))


## The HUD's line for each meter: "<label> <value>/<max>".
func lines() -> Array[String]:
	var out: Array[String] = []
	for id: String in defs:
		var d := defs[id] as Dictionary
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
		# The ones the mark frees (`take`: names or stat blocks): out of the fight, rescued.
		for c in e.combatants.duplicate():
			if c.is_alive() and not c.has_meta("left_fight") and _named(c, m.get("take", []) as Array):
				e.log.add("info", "%s is free" % c.name(), c.id)
				e.movement.leave_grid(c, "rescued")
		var outcome := str(m.get("outcome", ""))
		if outcome in ["victory", "defeat", "ended"] and e.state == Encounter.State.ACTIVE:
			e.turns._finish(outcome)
			return


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
				"sub": "DC %d %s" % [int(check.get("dc", 10)), str(check.get("skill", "athletics")).capitalize()] if not check.is_empty() else "No check",
				"cost": "bonus" if str(a.get("cost", "action")) == "bonus" else "action", "why": why_not(c, a),
				"help": "%s %+d on a success%s." % [str((defs[id] as Dictionary).get("label", id)), int(a.get("success", 1)),
					(", %+d on a failure" % int(a["failure"])) if int(a.get("failure", 0)) != 0 else ""]})
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
	var skill := StringName(str(check.get("skill", "athletics")))
	var label := str(a.get("label", "Help"))
	if check.is_empty():   # no check: it simply works
		e.events.append({"type": "ability", "source": "feature", "by": c.id, "key": "meter:%s:%s" % [meter_id, action_id], "targets": [], "cells": []})
		e.log.add("info", "%s: %s" % [c.name(), label], c.id)
		change(meter_id, int(a.get("success", 1)))
		return CombatResult.new()
	var t := c.creature.roll_check(e.dice, skill, int(check.get("dc", 10)), [], [], "%s: %s check (%s)" % [label,
		str(skill).capitalize(), c.name()])
	e.events.append({"type": "ability", "source": "feature", "by": c.id, "key": "meter:%s:%s" % [meter_id, action_id], "targets": [], "cells": []})
	if t.success:
		e.log.add("info", "%s: %s succeeds" % [c.name(), label], c.id, [t.describe()])
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
	return CombatResult.new()


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


# --- Fight events ---------------------------------------------------------------------------------

## Reads the encounter's new events for the meters' `on` rules ([{event: defeat, crit or failed_save, who: [names or
## stat blocks], side: party or enemy, delta}]): a creature falling, an attacker's critical hit, a failed save, each
## moving the meter by `delta`. Called as each turn ends and before the view drains the events.
func scan() -> void:
	var e := enc()
	if defs.is_empty():
		_scanned = e.events.size()
		return
	while _scanned < e.events.size():
		var ev := e.events[_scanned] as Dictionary
		_scanned += 1
		var kind := ""
		var who: Combatant = null
		match str(ev.get("type", "")):
			"down", "death":
				if _defeated.has(str(ev.get("id", ""))):
					continue
				_defeated[str(ev.get("id", ""))] = true
				kind = "defeat"
				who = e.get_c(str(ev.get("id", "")))
			"attack":
				if bool(ev.get("critical", false)):
					kind = "crit"
					who = e.get_c(str(ev.get("attacker", "")))
			"save":
				var t := ev.get("test") as D20Test
				if t != null and not t.success:
					kind = "failed_save"
					who = e.get_c(str(ev.get("id", "")))
		if kind == "" or who == null:
			continue
		for id: String in defs.keys():
			for rv: Variant in (defs[id] as Dictionary).get("on", []):
				var rule := rv as Dictionary
				if str(rule.get("event", "")) != kind:
					continue
				if rule.has("who") and not _named(who, rule["who"] as Array):
					continue
				if rule.has("side") and _side(who) != str(rule["side"]):
					continue
				change(id, int(rule.get("delta", 1)))


## The view has taken the events: the next scan starts from the top.
func drained() -> void:
	_scanned = 0


static func _named(c: Combatant, names: Array) -> bool:
	var block := str((c.creature as Monster).data.get("id", "")) if c.creature is Monster else ""
	return names.has(c.name()) or (block != "" and names.has(block))


static func _side(c: Combatant) -> String:
	return "party" if c.side in [&"party", &"guest"] else str(c.side)


func to_dict() -> Dictionary:
	return {"values": values.duplicate(), "reached": reached.duplicate(), "used": used.duplicate(), "clock_lost": clock_lost,
		"clock_rang": clock_rang}


func from_dict(d: Dictionary) -> void:
	values = (d.get("values", {}) as Dictionary).duplicate()
	reached = (d.get("reached", {}) as Dictionary).duplicate()
	used = (d.get("used", {}) as Dictionary).duplicate()
	clock_lost = int(d.get("clock_lost", 0))
	clock_rang = bool(d.get("clock_rang", false))
