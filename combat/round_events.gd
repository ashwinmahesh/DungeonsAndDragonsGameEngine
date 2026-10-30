class_name RoundEvents
extends RefCounted
## Round events (docs/contracts/combat.md "Round events"): things that happen in a fight on an initiative count with
## no creature behind them, the way a lair acts on 20: fumes rising from a firebox, a storm's gusts, a breach in the
## wall letting the mist in, reinforcements coming down the stairs. An encounter's `round_events` lists them; each
## acts on its initiative count `at` (20, 10, 0...; losing ties, as a lair does) in the rounds it says, from a `table`
## of outcomes (in turn, or at random without repeating the last) or as itself. Legendary runs them beside the lair's
## turn (lair_due, lair_turn, round_ending), so the turn order needs nothing new.
##
## An event (or a table entry) does one of:
##   save:    each creature it reaches (`affects`: party, enemies or all; `area`: cells, a rectangle or a circle round
##            a square, else the whole field; creatures resistant or immune to `skip_if_resists` are spared) makes the
##            save (`dc`, plus `dc_step` for each time the event has acted before); a failure takes `damage` (half on
##            a success with `half`), gains `exhaustion` levels and has `condition` until `until` (target_turn_end,
##            minute, permanent).
##   summon:  `monster` x `count` arrives at `cells` (the first free ones; else near the first), on the event's count.
##   text:    only says something (a warning before a later event; `say` is the Narrator's key for the view).
## `name` and `summary` are what the log and the initiative tracker show.

var _legendary: WeakRef
## The fight's events, as the encounter gave them.
var events: Array[Dictionary] = []
## Event id -> {round: the last round it acted, times: how many times it has acted, last: the table entry it used}.
var done: Dictionary = {}


func _init(legendary: Legendary) -> void:
	_legendary = weakref(legendary)


func leg() -> Legendary:
	return _legendary.get_ref() as Legendary


func enc() -> Encounter:
	return leg().enc()


func set_events(list: Array) -> void:
	events.clear()
	for ev: Variant in list:
		events.append((ev as Dictionary).duplicate(true))


## Whether `ev` acts in the current round (its first and last round, and every `every` rounds from the first).
func _in_round(ev: Dictionary, round_no: int) -> bool:
	var first := int(ev.get("from_round", 1))
	if round_no < first:
		return false
	if ev.has("until_round") and round_no > int(ev["until_round"]):
		return false
	if ev.has("times") and int((done.get(str(ev["id"]), {}) as Dictionary).get("times", 0)) >= int(ev["times"]):
		return false
	return (round_no - first) % maxi(1, int(ev.get("every", 1))) == 0


## The events still to act this round on a count above `below` (the creature about to act rolled `below`).
func due(below: int) -> Array[Dictionary]:
	var e := enc()
	var out: Array[Dictionary] = []
	for ev in events:
		var st := done.get(str(ev["id"]), {}) as Dictionary
		if int(st.get("round", 0)) >= e.round_no or not _in_round(ev, e.round_no):
			continue
		if int(ev.get("at", 20)) > below:
			out.append(ev)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("at", 20)) > int(b.get("at", 20)))
	return out


## The events of this round that haven't acted yet, at any count (the round is ending).
func left_this_round() -> Array[Dictionary]:
	return due(-1000)


## Runs the events due before a creature on count `below`, in order of count; a save can stop for the choices after
## its roll (`pausable`), so this may come back paused.
func run_due(below: int, pausable: bool = true) -> CombatResult:
	var e := enc()
	return e.each(due(below), func(ev: Variant) -> CombatResult:
		if e.state != Encounter.State.ACTIVE:
			return CombatResult.new()
		return act(ev as Dictionary, pausable), func() -> CombatResult: return CombatResult.new())


## One event acts now.
func act(ev: Dictionary, pausable: bool = true) -> CombatResult:
	var e := enc()
	var id := str(ev["id"])
	var st := (done.get(id, {}) as Dictionary).duplicate()
	var times := int(st.get("times", 0))
	var outcome := _pick(ev, str(st.get("last", "")))
	st["round"] = e.round_no
	st["times"] = times + 1
	st["last"] = str(outcome.get("id", ""))
	done[id] = st
	var label := str(outcome.get("name", ev.get("name", id.capitalize())))
	leg()._log("spell", "Initiative %d: %s" % [int(ev.get("at", 20)), label], null, [str(outcome.get("summary", ev.get("summary", "")))])
	var r := CombatResult.new()
	var reached := _reached(outcome)
	e.events.append({"type": "round_event", "event": id, "outcome": str(outcome.get("id", "")), "name": label,
		"say": str(outcome.get("say", "")), "targets": reached.map(func(c: Combatant) -> String: return c.id)})
	var done_fn := func() -> CombatResult:
		e._check_over()
		if e.state == Encounter.State.ACTIVE:
			return e.run_reaction_queue(r)
		return r
	match str(outcome.get("kind", "save" if outcome.has("save") else "text")):
		"save":
			var dc := int((outcome["save"] as Dictionary)["dc"]) + int(outcome.get("dc_step", 0)) * times
			return e.each(reached, func(tv: Variant) -> CombatResult:
				var t := tv as Combatant
				if not t.is_alive() or e.state != Encounter.State.ACTIVE:
					return r
				return _save(outcome, t, dc, label, pausable), done_fn)
		"summon":
			_summon(outcome, int(ev.get("at", 20)))
	return done_fn.call() as CombatResult


## The outcome this time: the event itself, or one entry of its `table` (`pick`: "cycle" in turn, else at random and
## never the one used last time).
func _pick(ev: Dictionary, last: String) -> Dictionary:
	var table := ev.get("table", []) as Array
	if table.is_empty():
		return ev
	if str(ev.get("pick", "random")) == "cycle":
		var at := 0
		for i in table.size():
			if str((table[i] as Dictionary).get("id", "")) == last:
				at = (i + 1) % table.size()
		return table[at] as Dictionary
	var choices: Array = table.filter(func(x: Variant) -> bool: return table.size() == 1 or str((x as Dictionary).get("id", "")) != last)
	return choices[enc().dice.roll_one(choices.size(), "Round event") - 1] as Dictionary


## The creatures an outcome reaches: on the side it names, inside its area, not spared by a resistance.
func _reached(o: Dictionary) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	var affects := str(o.get("affects", "party"))
	var spared := o.get("skip_if_resists", []) as Array
	for c in e.living():
		if c.is_down() and affects != "all":
			continue
		var on_party := c.side in [&"party", &"guest"]
		if (affects == "party" and not on_party) or (affects == "enemies" and on_party):
			continue
		if not in_area(o.get("area", {}) as Dictionary, c):
			continue
		var skip := false
		for dt: Variant in spared:
			if c.creature.resistance_source(StringName(str(dt))) != "" or c.creature.immunity_source(StringName(str(dt))) != "":
				skip = true
		if not skip:
			out.append(c)
	return out


## Whether any square of `c` is in `area` ({} is the whole field): `cells` [[x, y]...], `rect` [x0, y0, x1, y1]
## (inclusive), or `around` [x, y] with `radius` in feet.
func in_area(area: Dictionary, c: Combatant) -> bool:
	if area.is_empty():
		return true
	for cell in c.footprint():
		if area.has("cells"):
			for xy: Variant in area["cells"]:
				if Vector2i(int((xy as Array)[0]), int((xy as Array)[1])) == cell:
					return true
		if area.has("rect"):
			var rc := area["rect"] as Array
			if cell.x >= int(rc[0]) and cell.y >= int(rc[1]) and cell.x <= int(rc[2]) and cell.y <= int(rc[3]):
				return true
		if area.has("around"):
			var at := Vector2i(int((area["around"] as Array)[0]), int((area["around"] as Array)[1]))
			if enc().grid.distance_ft(at, 1, cell, 1) <= int(area.get("radius", 5)):
				return true
	return false


func _save(o: Dictionary, t: Combatant, dc: int, label: String, pausable: bool) -> CombatResult:
	var e := enc()
	var r := CombatResult.new()
	var sv := o["save"] as Dictionary
	var ab := StringName(str(sv["ability"]))
	var roll := func() -> D20Test:
		return t.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, t.name()])
	var after := func(test: D20Test) -> CombatResult:
		if test.success and not bool(o.get("half", false)):
			leg()._log("info", "%s resists %s" % [t.name(), label], t, [test.describe()])
			return r
		var details: Array[String] = [test.describe()]
		var dmg := o.get("damage", {}) as Dictionary
		if not dmg.is_empty():
			var rolled := e._roll_damage_dice(str(dmg["dice"]), false, 0, label)
			var amount := int(rolled["total"])
			if test.success:
				amount /= 2
			details.append(str(rolled["text"]))
			e.deal_damage(null, t, [{"amount": amount, "type": str(dmg["type"])}], false, label, details)
		if test.success or not t.is_alive():
			return r
		if int(o.get("exhaustion", 0)) > 0:
			for i in int(o["exhaustion"]):
				t.creature.add_exhaustion(1)
			leg()._log("condition", "%s gains Exhaustion (%s)" % [t.name(), label], t, details)
		if str(o.get("condition", "")) != "":
			_condition(t, str(o["condition"]), str(o.get("until", "target_turn_end")), label)
		e.events.append({"type": "condition", "id": t.id})
		return r
	if pausable:
		return e.d20.then_after(t, roll, after, r)
	return after.call(roll.call() as D20Test) as CombatResult


func _condition(t: Combatant, cond: String, until: String, label: String) -> void:
	var e := enc()
	var fx := Effect.new("%s (%s)" % [cond.capitalize(), label], &"round_event", "round_event:%s" % label)
	fx.conditions.append(StringName(cond))
	match until:
		"target_turn_end":
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = t.id
			fx.skip_turn_ends = e.own_turn_skip(t)
		"minute":
			fx.lasting({"kind": "minutes", "amount": 1})
			fx.turn_owner_id = t.id
		_:
			fx.ends = Effect.Ends.NEVER
	if t.creature.add_effect(fx):
		leg()._log("condition", "%s is %s (%s)" % [t.name(), cond.capitalize(), label], t)


## Reinforcements: `monster` x `count` on the enemies' side, at `cells` (else near the first enemy), joining the order
## on the event's count.
func _summon(o: Dictionary, at: int) -> void:
	var e := enc()
	var data := Compendium.shared().monster_data(str(o["monster"]))
	if data.is_empty():
		return
	var spots: Array[Vector2i] = []
	for xy: Variant in o.get("cells", []):
		spots.append(Vector2i(int((xy as Array)[0]), int((xy as Array)[1])))
	var side := StringName(str(o.get("side", "enemy")))
	if spots.is_empty():
		for c in e.living():
			if c.side == side:
				spots.append(c.cell)
				break
	if spots.is_empty():
		return
	var size := CombatGrid.size_cells_for(StringName(str(data.get("size", "medium"))))
	var made := 0
	for i in int(o.get("count", 1)):
		var cell := e.spells._free_cell_near(spots[i % spots.size()], size)
		if cell.x < 0:
			break
		var sc := e.add(Monster.from_data(data), side, cell)
		leg()._insert_at(sc, at)
		leg().phases.watch(sc)
		e.events.append({"type": "summon_creature", "id": sc.id, "cell": sc.cell, "caster": ""})
		made += 1
	if made > 0:
		leg()._log("info", "%d %s join the fight" % [made, Legendary._plural(str(o["monster"]), made)], null)


func to_dict() -> Dictionary:
	return {"events": events.duplicate(true), "done": done.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	set_events(d.get("events", []) as Array)
	done = (d.get("done", {}) as Dictionary).duplicate(true)
