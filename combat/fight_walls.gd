class_name FightWalls
extends RefCounted
## Walls a fight's place raises (an encounter's `walls`: R23's ring of fire), held up by its set pieces: a ring of
## squares `radius` squares round `center` that burns whoever steps onto it and lets nobody inside out, until `falls_at`
## of the objects in `held_by` are broken or undone (four of nine standing stones). From outside it can be crossed
## inward, burning. A wall is {name, center: [x, y], radius, damage: {dice, type}, held_by: [object ids], falls_at}.
## Read from the fight's entry whenever it starts or is picked up; whether it stands comes from its objects, so nothing
## of it is saved.


static func _center(w: Dictionary) -> Vector2i:
	var c := w.get("center", [0, 0]) as Array
	return Vector2i(int(c[0]), int(c[1]))


## Squares from the wall's center (Chebyshev, as the grid counts).
static func _rings(w: Dictionary, cell: Vector2i) -> int:
	var c := _center(w)
	return maxi(absi(cell.x - c.x), absi(cell.y - c.y))


static func standing(e: Encounter, w: Dictionary) -> bool:
	var gone := 0
	for oid: Variant in w.get("held_by", []):
		var o := e.objects.get_object(str(oid))
		if o == null or o.destroyed:
			gone += 1
	return gone < int(w.get("falls_at", 1))


## The squares of a wall's ring (for the board to draw it).
static func ring_cells(e: Encounter, w: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := int(w.get("radius", 5))
	for x in e.grid.width:
		for y in e.grid.depth:
			var cell := Vector2i(x, y)
			if _rings(w, cell) == r:
				out.append(cell)
	return out


## The squares a wall keeps `c` out of: from inside, the ring and everything past it.
static func blocks(e: Encounter, c: Combatant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for wv: Variant in e.walls:
		var w := wv as Dictionary
		var r := int(w.get("radius", 5))
		if not standing(e, w) or _rings(w, c.cell) >= r:
			continue
		for x in e.grid.width:
			for y in e.grid.depth:
				var cell := Vector2i(x, y)
				if _rings(w, cell) >= r:
					out.append(cell)
	return out


## A step onto a standing wall's ring burns, once a turn for each wall.
static func entered(e: Encounter, c: Combatant, from: Vector2i) -> void:
	for i in e.walls.size():
		var w := e.walls[i] as Dictionary
		var r := int(w.get("radius", 5))
		if not standing(e, w) or _rings(w, c.cell) != r or _rings(w, from) == r:
			continue
		var key := "wall_burned_%d" % i
		if int(c.get_meta(key, -1)) == e.round_no * 1000 + e.turn_index:
			continue
		c.set_meta(key, e.round_no * 1000 + e.turn_index)
		var dmg := w.get("damage", {}) as Dictionary
		var rolled := e._roll_damage_dice(str(dmg.get("dice", "5d8")), false, 0, str(w.get("name", "The wall")))
		e.deal_damage(null, c, [{"amount": int(rolled["total"]), "type": str(dmg.get("type", "fire"))}], false,
			str(w.get("name", "The wall")), [str(rolled["text"])])


## After a set piece breaks: a wall it held up that has just fallen says so.
static func after_break(e: Encounter) -> void:
	for i in e.walls.size():
		var w := e.walls[i] as Dictionary
		if not bool(w.get("_down", false)) and not standing(e, w):
			w["_down"] = true
			e.log.add("info", "%s goes out" % str(w.get("name", "The wall")), "")
			e.events.append({"type": "wall_down", "index": i})
