class_name AreaHazards
extends RefCounted
## Ground that harms whoever stays in it (a location area's `hazard`; owned by the Encounter as `zones`): a pool of
## blood, a bog of rot. `{difficult, on, save, condition, damage, except_types, while_in}`:
## - `difficult`: its squares are Difficult Terrain.
## - At the end of its turn in one of the area's squares (`on: "end"`, the default) or the start (`on: "start"`), a
##   creature makes the `save` ({ability, dc}) unless its type is in `except_types`; failing, it takes `damage`
##   ({dice, type}) and gains `condition`. With `while_in` (the default) the condition lasts only while it stays in the
##   area: it goes as the creature steps out. Only creatures on the ground are touched (not flying over it).
## Read from the place when a fight starts or is picked up from a save (from_location), so nothing of it is saved.

var _enc: WeakRef
## [{id, name, cells: {Vector2i: true}, hazard}]
var list: Array[Dictionary] = []


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## The place `loc`'s areas that carry a `hazard`, onto this fight (and their Difficult Terrain onto its grid).
func from_location(loc: Dictionary) -> void:
	var e := enc()
	list.clear()
	for a: Variant in loc.get("areas", []):
		var ad := a as Dictionary
		if not ad.has("hazard"):
			continue
		var corners := ad["cells"] as Array
		var c0 := Vector2i(int((corners[0] as Array)[0]), int((corners[0] as Array)[1]))
		var c1 := Vector2i(int((corners[1] as Array)[0]), int((corners[1] as Array)[1]))
		var cells := {}
		for z in range(mini(c0.y, c1.y), maxi(c0.y, c1.y) + 1):
			for x in range(mini(c0.x, c1.x), maxi(c0.x, c1.x) + 1):
				var cell := Vector2i(x, z)
				if not e.grid.in_bounds(cell) or e.grid.is_solid(cell):
					continue
				cells[cell] = true
				if bool((ad["hazard"] as Dictionary).get("difficult", false)):
					e.grid.set_flag(cell, CombatGrid.DIFFICULT, true)
		list.append({"id": str(ad["id"]), "name": str(ad.get("name", ad["id"])), "cells": cells, "hazard": ad["hazard"]})


func _source(z: Dictionary) -> String:
	return "area:" + str(z["id"])


## The areas `c` stands in (on the ground).
func areas_of(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c.altitude > 0:
		return out
	for z in list:
		if c.footprint().any(func(cell: Vector2i) -> bool: return (z["cells"] as Dictionary).has(cell)):
			out.append(z)
	return out


## EncounterTurns, the start and end of `c`'s turn.
func turn_start(c: Combatant) -> void:
	_strike_all(c, "start")


func turn_end(c: Combatant) -> void:
	_strike_all(c, "end")


func _strike_all(c: Combatant, on: String) -> void:
	if not c.is_alive():
		return
	for z in areas_of(c):
		var hz := z["hazard"] as Dictionary
		if str(hz.get("on", "end")) == on:
			_strike(c, z, hz)


func _strike(c: Combatant, z: Dictionary, hz: Dictionary) -> void:
	var e := enc()
	if str(c.creature.creature_type) in (hz.get("except_types", []) as Array).map(func(t: Variant) -> String: return str(t)):
		return
	var cond := StringName(str(hz.get("condition", "")))
	if cond != &"" and c.creature.has_condition(cond) and _source(z) in (c.creature.conditions.get(cond, []) as Array):
		return   # already held by it
	var sv := hz.get("save", {}) as Dictionary
	if not sv.is_empty():
		var t := c.creature.roll_save(e.dice, StringName(str(sv["ability"])), int(sv["dc"]), [], [], "%s save vs %s (%s)" % [
			str(sv["ability"]).to_upper(), str(z["name"]), c.name()])
		if t.success:
			e.log.add("info", "%s resists %s" % [c.name(), str(z["name"])], c.id, [t.describe()])
			return
		e.log.add("info", "%s is overcome by %s" % [c.name(), str(z["name"])], c.id, [t.describe()])
	var dmg := hz.get("damage", {}) as Dictionary
	if not dmg.is_empty():
		var rolled := e._roll_damage_dice(str(dmg.get("dice", "1d6")), false, 0, str(z["name"]))
		e.deal_damage(null, c, [{"amount": int(rolled["total"]), "type": str(dmg.get("type", "poison"))}], false, str(z["name"]), [str(rolled["text"])])
	if cond != &"" and c.is_alive() and c.creature.add_condition(cond, _source(z)):
		e.log.add("condition", "%s is %s (%s)" % [c.name(), str(cond).capitalize(), str(z["name"])], c.id)
		e.events.append({"type": "condition", "id": c.id})


## EncounterMovement, each step: a condition held only while in an area goes once `c` is out of it.
func on_moved(c: Combatant) -> void:
	var e := enc()
	var inside := areas_of(c).map(func(z: Dictionary) -> String: return str(z["id"]))
	for z in list:
		var hz := z["hazard"] as Dictionary
		if not bool(hz.get("while_in", true)) or str(z["id"]) in inside:
			continue
		var cond := StringName(str(hz.get("condition", "")))
		if cond == &"" or not _source(z) in (c.creature.conditions.get(cond, []) as Array):
			continue
		c.creature.remove_condition(cond, _source(z))
		e.log.add("condition", "%s is out of %s: no longer %s" % [c.name(), str(z["name"]), str(cond).capitalize()], c.id)
		e.events.append({"type": "condition", "id": c.id})
