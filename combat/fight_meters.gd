class_name FightMeters
extends RefCounted
## A fight's meters (an encounter's `meters`, docs/reference/contracts/combat.md "Meters"): a named count the fight is
## about, such as a frightened guide's loyalty or the pips of a rite, shown on the combat HUD. The heroes move it with
## the meter's actions (a check, as an action or a Bonus Action, near what it names); reaching a mark sets a flag for
## the story or ends the fight. Kept in a round's save (EncounterSnapshot).
##
## A meter: {id, label, start (0), min (0), max, actions: [{id, label, cost (action or bonus), near (an object id or a
## creature's name; anywhere when missing), range (5), check: {skill, dc}, success (+1), failure (0), failure_damage:
## {dice, type} (to whoever failed)}], marks: [{value, falling (reached going down to it; else going up), flag, outcome
## (victory, defeat or ended), say}]}.

var _enc: WeakRef
## id -> the meter's data.
var defs: Dictionary = {}
## id -> its value now.
var values: Dictionary = {}
## "<meter id>:<mark index>" for the marks already reached.
var reached: Dictionary = {}


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
				"sub": "DC %d %s" % [int(check.get("dc", 10)), str(check.get("skill", "athletics")).capitalize()],
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
	var check := a.get("check", {}) as Dictionary
	var skill := StringName(str(check.get("skill", "athletics")))
	var label := str(a.get("label", "Help"))
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
		e.deal_damage(c, c, [{"amount": int(rolled["total"]), "type": str(hurt.get("type", "force"))}], false, label,
			["%s %s: %s" % [label, str(hurt.get("dice", "1d6")), str(rolled["text"])]])
	change(meter_id, int(a.get("failure", 0)))
	return CombatResult.new()


func to_dict() -> Dictionary:
	return {"values": values.duplicate(), "reached": reached.duplicate()}


func from_dict(d: Dictionary) -> void:
	values = (d.get("values", {}) as Dictionary).duplicate()
	reached = (d.get("reached", {}) as Dictionary).duplicate()
