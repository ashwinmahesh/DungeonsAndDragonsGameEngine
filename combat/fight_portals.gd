class_name FightPortals
extends RefCounted
## Paired squares that lead into each other (an encounter's `portals`; owned by the Encounter as `portals`): a demiplane
## whose windows open onto the one opposite. `[{name, cells: [a, b], when_flag, broken}]`: a creature that steps onto
## one square of a pair, walking or pushed, comes out on the other (or the nearest free square to it), and that move
## ends there. A pair works always, or only while the fight flag `when_flag` is set, or only once the object the
## scenery made from prop `broken` is broken. Read from the entry whenever the fight starts or is picked up.

var _enc: WeakRef
var list: Array[Dictionary] = []


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func set_portals(entries: Array) -> void:
	list.clear()
	for x: Variant in entries:
		var d := (x as Dictionary).duplicate(true)
		var cells := d["cells"] as Array
		d["a"] = Vector2i(int((cells[0] as Array)[0]), int((cells[0] as Array)[1]))
		d["b"] = Vector2i(int((cells[1] as Array)[0]), int((cells[1] as Array)[1]))
		list.append(d)


## Whether pair `p` leads anywhere now.
func open(p: Dictionary) -> bool:
	var e := enc()
	if str(p.get("when_flag", "")) != "" and not bool(e.legendary.story_flags.get(str(p["when_flag"]), false)):
		return false
	var prop := str(p.get("broken", ""))
	if prop != "":
		return e.objects.list.any(func(o: BattleObject) -> bool: return o.prop_id == prop and o.destroyed)
	return true


## `c` has just stepped onto its square: through a pair onto the other side (true when it went, and its move stops).
func step(c: Combatant) -> bool:
	var e := enc()
	if c.altitude > 0 or not c.is_alive():
		return false
	for p in list:
		var other := Vector2i(-1, -1)
		if c.cell == p["a"]:
			other = p["b"]
		elif c.cell == p["b"]:
			other = p["a"]
		if other == Vector2i(-1, -1) or not open(p):
			continue
		var to: Vector2i = other if e.spells._room_for(other, c.size_cells) else e.spells._free_cell_near(other, c.size_cells)
		var from := c.cell
		c.cell = to
		e.events.append({"type": "teleport", "id": c.id, "from": from, "to": to})
		e.log.add("move", "%s goes through %s and comes out across the room" % [c.name(), str(p.get("name", "the opening"))], c.id)
		return true
	return false
