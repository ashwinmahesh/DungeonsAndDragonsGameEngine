class_name WardLights
extends RefCounted
## A guest's warding light in a fight (an NPC's `ward_light`; a lantern that holds the dark back): a zone round the
## square the guest stands on, `{radius, bright, dim, keep_out, disadvantage, small: {when, radius, bright, dim}, off_at}`:
## - It lights the fight: Bright Light `bright` ft and Dim Light `dim` more (by default `radius` and `radius`).
## - The creatures named in `keep_out` (names, stat block ids or creature types) can't step into it unless they're
##   already inside, and those in `disadvantage` have Disadvantage on D20 Tests while in it.
## - With `small` its story `when` holds (the beacons lit), its numbers shrink to that entry's; at a place in `off_at`
##   (a corrupted light) it isn't there at all. LocationFights.ward_guests puts it down as a fight starts; a fight picked
##   up from a save keeps the zone it had.

const SPELL_ID := "ward_light"


## Puts `spec`'s light down round `cell` (the guest `who`, by name).
static func place(e: Encounter, cell: Vector2i, spec: Dictionary, who: String) -> void:
	var radius := int(spec.get("radius", 30))
	var o := FieldObject.new(FieldObject.Kind.ZONE, SPELL_ID, "%s's light" % who)
	o.cell = cell
	o.origin = Vector2(cell.x + 0.5, cell.y + 0.5)
	o.cells = e.grid.area_cells("emanation", radius, o.origin, Vector2.RIGHT, 5, cell, 1)
	if not cell in o.cells:
		o.cells.append(cell)
	o.rules = {"triggers": [], "affects": "none", "colour": "gilt", "size": radius,
		"light": {"bright": int(spec.get("bright", radius)), "dim": int(spec.get("dim", radius))},
		"keep_out": spec.get("keep_out", []), "disadvantage": spec.get("disadvantage", [])}
	e.spells.zones.add(o, CombatResult.new())
	e.log.add("info", "%s's light holds the dark back" % who, "")


static func named(c: Combatant, who: Array) -> bool:
	var block := str((c.creature as Monster).data.get("id", "")) if c.creature is Monster else ""
	for w: Variant in who:
		var s := str(w)
		if s == c.name() or (block != "" and s == block) or s == str(c.creature.creature_type):
			return true
	return false


static func _inside(c: Combatant, o: FieldObject) -> bool:
	return c.footprint().any(func(f: Vector2i) -> bool: return f in o.cells)


## The squares `c` can't step into: every ward light that keeps it out, unless it's inside already.
static func blocks(e: Encounter, c: Combatant) -> Dictionary:
	var out := {}
	for o in e.spells.zones.live():
		if o.spell_id != SPELL_ID or not named(c, o.rules.get("keep_out", []) as Array) or _inside(c, o):
			continue
		for cell in o.cells:
			out[cell] = true
	return out


## The ward lights that put `c` at Disadvantage on its D20 Tests where it stands.
static func disadvantage(e: Encounter, c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for o in e.spells.zones.live():
		if o.spell_id == SPELL_ID and named(c, o.rules.get("disadvantage", []) as Array) and _inside(c, o):
			out.append(o.name)
	return out
