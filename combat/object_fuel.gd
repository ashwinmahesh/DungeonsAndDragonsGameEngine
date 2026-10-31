class_name ObjectFuel
extends RefCounted
## Things on the battlefield a creature eats, and things that hold a creature (docs/reference/contracts/combat.md
## "Fuel and what breaks open"), owned by EncounterObjects as `fuel`:
## - A stat block's `devours` {fuel: [words], within (ft, default 10), heal, advantage, seeks, name}: at the start of its
##   turn, a creature within `within` feet of a standing object whose `fuel` is one of its words eats the nearest: the
##   object is gone, it regains `heal` Hit Points, and with `advantage` its attacks have Advantage until its next turn
##   starts. One a turn. The AI walks it to food it can reach this turn ahead of a foe, and with `seeks` toward the
##   nearest food farther off when no foe is in reach where it stands (AiBrain._fuel_turn).
## - An object's `releases` {monster, name, art, hp, side, minion_of}: when it breaks, or is eaten, that creature comes
##   out on its square (or the nearest free one) and joins the fight right after the creature named in `minion_of`
##   (or the one whose turn it is). `hp` "half" starts it at half its Hit Points. `minion_of` makes it leave with that
##   boss (BossPhases.fell, the block's `minions`).
## Pure logic: the scene draws it from the events (`object_eaten` {id, by}, then `summon_creature` for what came out).

const DEFAULT_WITHIN := 10
## On a creature that came out of an object: the object's id (a game may treat it apart: no opening wail for an echo).
const RELEASED_META := "released_from"

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## `c`'s stat block `devours`, or {}.
static func devours_of(c: Combatant) -> Dictionary:
	if not c.creature is Monster:
		return {}
	return MonsterActions.data_of(c).get("devours", {}) as Dictionary


## The standing objects `c` would eat, nearest first.
func food_for(c: Combatant) -> Array[BattleObject]:
	var dv := devours_of(c)
	var out: Array[BattleObject] = []
	if dv.is_empty():
		return out
	var words := dv.get("fuel", []) as Array
	for o in enc().objects.list:
		if not o.destroyed and o.fuel != "" and o.fuel in words:
			out.append(o)
	var objs := enc().objects
	out.sort_custom(func(a: BattleObject, b: BattleObject) -> bool: return objs.distance_ft(c, a) < objs.distance_ft(c, b))
	return out


## How near `c` must be to eat.
static func within_ft(c: Combatant) -> int:
	return int(devours_of(c).get("within", DEFAULT_WITHIN))


## EncounterObjects.turn_start: a creature that starts its turn near its food eats the nearest.
func turn_start(c: Combatant) -> void:
	if not c.is_alive() or c.is_down() or c.has_meta("left_fight"):
		return
	var food := food_for(c)
	if not food.is_empty() and enc().objects.distance_ft(c, food[0]) <= within_ft(c):
		devour(c, food[0])


## `c` eats `o`: it's gone, `c` heals and may attack with Advantage until its next turn starts, and what it held
## comes out.
func devour(c: Combatant, o: BattleObject) -> void:
	var e := enc()
	if o.destroyed:
		return
	var dv := devours_of(c)
	var label := str(dv.get("name", "Devour"))
	e.objects.clear_squares(o)
	o.destroyed = true
	o.hp = 0
	if o.burning:
		o.burning = false
		e.objects.fires_changed()
	var details: Array = []
	var healed := 0
	if int(dv.get("heal", 0)) > 0:
		healed = c.creature.heal(int(dv["heal"]), label)
		details.append("Regains %d Hit Points" % healed)
	if bool(dv.get("advantage", false)):
		var fx := Effect.new(label, &"feature", "devour")
		fx.caster_id = c.id
		fx.ends = Effect.Ends.START_OF_TURN
		fx.turn_owner_id = c.id
		c.creature.add_effect(fx.with_modifier("advantage", {"on": "attack"}))
		details.append("Advantage on its attacks until its next turn starts")
	e.log.add("info", "%s devours %s (%s)" % [c.name(), o.the(), label], c.id, details)
	e.events.append({"type": "object_eaten", "id": o.id, "by": c.id})
	if healed > 0:
		e.events.append({"type": "heal", "id": c.id, "amount": healed})
	e.events.append({"type": "condition", "id": c.id})
	release(o)


## What `o` held comes out on its square, or the nearest free one. Returns the new combatant, or null.
func release(o: BattleObject) -> Combatant:
	var e := enc()
	var rl := o.releases
	if rl.is_empty():
		return null
	o.releases = {}   # once
	var data := Compendium.shared().monster_data(str(rl.get("monster", "")))
	if data.is_empty():
		push_error("%s releases no stat block '%s'" % [o.id, rl.get("monster", "")])
		return null
	if rl.has("art"):
		data = data.duplicate()
		data["art"] = str(rl["art"])
	var size := CombatGrid.size_cells_for(StringName(str(data.get("size", "medium"))))
	var at := o.cells[0] if not o.cells.is_empty() else Vector2i(-1, -1)
	var cell := at if at.x >= 0 and e.spells._room_for(at, size) else e.spells._free_cell_near(at, size)
	if cell.x < 0:
		e.log.add("info", "%s has no room to come out of %s" % [str(rl.get("name", data.get("name", "It"))), o.the()], "")
		return null
	var mon := Monster.from_data(data)
	if rl.has("name"):
		mon.name = str(rl["name"])
	var hp: Variant = rl.get("hp", null)
	if str(hp) == "half":
		mon.hp = maxi(1, ceili(mon.max_hp() / 2.0))
	elif hp != null:
		mon.hp = clampi(int(hp), 1, mon.max_hp())
	var side := StringName(str(rl.get("side", "enemy")))
	var sc := e.add(mon, side, cell)
	sc.set_meta(RELEASED_META, o.id)
	var master: Combatant = null
	if str(rl.get("minion_of", "")) != "":
		sc.set_meta("minion_of", str(rl["minion_of"]))
		for x in e.combatants:
			if x != sc and x.is_alive() and str(MonsterActions.data_of(x).get("id", "")) == str(rl["minion_of"]):
				master = x
				break
	e.insert_after(master if master != null else e.current(), sc)
	e.legendary.phases.watch(sc)
	e.log.add("info", "%s comes out of %s" % [sc.name(), o.the()], sc.id)
	e.events.append({"type": "summon_creature", "id": sc.id, "cell": sc.cell, "caster": master.id if master != null else ""})
	return sc
