class_name FightOpenings
extends RefCounted
## Openings a creature can be thrown out of (an encounter's `openings`; owned by the Encounter as `openings`): the
## windows of a tower or of a building walking on legs. `[{name, cells, drop_ft, aloft: {flag, drop_ft}, climb: {skill,
## dc}}]`:
## - A creature with a `throws_out` trait ({needs: conditions, reach}) can, with its action, throw a foe within its reach
##   that has one of those conditions (Paralyzed, Restrained by default) and stands within 5 ft of an opening out of it.
##   The foe falls the opening's drop (`aloft.drop_ft` while the fight flag `aloft.flag` is set, else `drop_ft`):
##   1d6 Bludgeoning for each 10 ft and Prone, and is outside, off the board.
## - At the start of each of its turns outside it climbs back in with the `climb` check (Athletics DC 15 by default):
##   back on a free square by the opening, its turn going on; failing, the turn passes with it still outside.
## The AI throws whenever it can (AiBrain.begin_turn). The openings come from the fight's entry each time it starts or
## is picked up; who is outside is kept on the creature (meta `thrown_out`).

const OUT := "thrown_out"

var _enc: WeakRef
var list: Array[Dictionary] = []


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## The fight entry's openings onto this fight.
func set_openings(entries: Array) -> void:
	list.clear()
	for x: Variant in entries:
		var d := (x as Dictionary).duplicate(true)
		var cells: Array[Vector2i] = []
		for c: Variant in d.get("cells", []):
			cells.append(Vector2i(int((c as Array)[0]), int((c as Array)[1])))
		d["cells"] = cells
		list.append(d)


## How far a creature thrown out of `op` falls now.
func drop_ft(op: Dictionary) -> int:
	var aloft := op.get("aloft", {}) as Dictionary
	if not aloft.is_empty() and bool(enc().legendary.story_flags.get(str(aloft.get("flag", "")), false)):
		return int(aloft.get("drop_ft", 0))
	return int(op.get("drop_ft", 0))


## The opening within 5 ft of `t`, or {}.
func near(t: Combatant) -> Dictionary:
	var e := enc()
	for op in list:
		for cell: Vector2i in op["cells"]:
			if e.grid.distance_ft(cell, 1, t.cell, t.size_cells) <= 5:
				return op
	return {}


static func throw_trait(c: Combatant) -> Dictionary:
	if c == null or not c.creature is Monster:
		return {}
	for tr: Variant in (c.creature as Monster).data.get("traits", []):
		if (tr as Dictionary).has("throws_out"):
			var d := ((tr as Dictionary)["throws_out"] as Dictionary).duplicate()
			d["_has"] = true   # an empty `throws_out` takes every default
			return d
	return {}


## "" if `c` can throw `t` out of an opening now, otherwise why not.
func throw_why(c: Combatant, t: Combatant) -> String:
	var e := enc()
	var tr := throw_trait(c)
	if tr.is_empty() or list.is_empty():
		return "Nothing to throw anyone out of"
	var why := e._action_check(c)
	if why != "":
		return why
	if t == null or not t.is_alive() or not c.hostile_to(t) or t.has_meta(OUT) or t.has_meta("left_fight"):
		return "No one to throw"
	if e.distance(c, t) > int(tr.get("reach", 5)):
		return "Out of reach"
	var needs := (tr.get("needs", ["paralyzed", "restrained"]) as Array)
	if not needs.any(func(n: Variant) -> bool: return t.creature.has_condition(StringName(str(n)))):
		return "%s isn't held" % t.name()
	if Creature.SIZES.find(t.creature.size) > Creature.SIZES.find(c.creature.size):
		return "%s is too big to throw" % t.name()
	if near(t).is_empty():
		return "Not by an opening"
	return ""


## `c` throws `t` out of the opening by it: the fall, and `t` outside.
func throw_out(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var why := throw_why(c, t)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	var op := near(t)
	var feet := drop_ft(op)
	e.log.add("info", "%s throws %s out of %s" % [c.name(), t.name(), str(op.get("name", "the opening"))], c.id)
	e._release_grapples_by(t)
	if e.grapples.has(t.id):
		e.grapples.erase(t.id)
		t.creature.remove_condition(&"grappled")
	t.set_meta(OUT, list.find(op))
	var from := t.cell
	t.cell = SpellSpecials.BANISHED_CELL
	e.events.append({"type": "vanish", "id": t.id, "left": "thrown"})
	if feet > 0:
		e.movement.fall(t, feet, "Thrown out of %s" % str(op.get("name", "the opening")))
	else:
		t.creature.add_condition(&"prone", "Thrown")
	t.set_meta("thrown_from", [from.x, from.y])
	return e.run_reaction_queue(CombatResult.new())


## The start of `c`'s turn: outside, it climbs back in (or its turn passes).
func turn_start(c: Combatant) -> void:
	var e := enc()
	if not c.has_meta(OUT):
		return
	var idx := int(c.get_meta(OUT))
	var op := list[idx] if idx >= 0 and idx < list.size() else {}
	var climb := op.get("climb", {"skill": "athletics", "dc": 15}) as Dictionary
	if not c.can_act():
		return
	var t := c.creature.roll_check(e.dice, StringName(str(climb.get("skill", "athletics"))), int(climb.get("dc", 15)), [], [],
		"Climb back in (%s)" % c.name())
	if not t.success:
		e.log.add("info", "%s can't get back in" % c.name(), c.id, [t.describe()])
		c.action_available = false
		c.bonus_available = false
		c.movement_left = 0
		return
	var at := (op.get("cells", []) as Array)
	var cell: Vector2i = at[0] if not at.is_empty() else Vector2i(int((c.get_meta("thrown_from") as Array)[0]), int((c.get_meta("thrown_from") as Array)[1]))
	if not e.spells._room_for(cell, c.size_cells):
		cell = e.spells._free_cell_near(cell, c.size_cells)
	c.remove_meta(OUT)
	c.remove_meta("thrown_from")
	c.cell = cell
	e.events.append({"type": "teleport", "id": c.id, "from": cell, "to": cell})
	e.log.add("info", "%s climbs back in" % c.name(), c.id, [t.describe()])


## The AI's throw as its turn begins: the first foe it can throw out (AiBrain.begin_turn).
func ai_throw(c: Combatant) -> CombatResult:
	if throw_trait(c).is_empty() or list.is_empty():
		return null
	for t in enc().hostiles_of(c):
		if throw_why(c, t) == "":
			return throw_out(c, t)
	return null
