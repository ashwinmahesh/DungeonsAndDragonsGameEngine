class_name ObjectCarry
extends RefCounted
## Set-piece objects a fight is played with rather than broken (owned by EncounterObjects as `carry`):
## - Carried things (`carry: {tag}`): plain objects with no Hit Points or Armor Class that can't be attacked or caught in
##   a spell. A creature within 5 ft takes one with its object interaction (else the Utilize action) and holds it until
##   it puts it somewhere; one that drops (0 Hit Points, gone from the fight) leaves it on its square.
## - Things they go into (`takes: {tag, label, flag, say, damage, light}`): the Utilize action within 5 ft, holding a
##   thing with that tag, puts it in. It is used up; the receiver is cleansed (its `hazard` ends), `flag` is set for the
##   story, `damage` ({who, amount, type}) strikes each creature named in `who` (a name or a stat block), and `light`
##   ({radius, disadvantage: who}) lights a ward round the receiver in which those creatures have Disadvantage on D20
##   Tests.
## - Hazards (`hazard`: [{on, near_ft, save, exhaustion, damage, if_flag, unless_flag}]): a creature entering a square
##   within `near_ft` (0: its own squares) for `on: "enter"`, or ending its turn there for `on: "end"`, makes the save
##   or gains `exhaustion` levels and takes `damage` ({dice, type}); once a turn for each object. `if_flag` /
##   `unless_flag` hold it to while a fight flag is set or unset (a boss phase's `flag`).
## - Study (`study: {skills, dc, say, flag}`): the Study action within 30 ft and the best of those checks tell what it is
##   (`say` in the log) and set `flag`.

const REACH := 5
const STUDY_RANGE := 30

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func objs() -> EncounterObjects:
	return enc().objects


## Whether `c` is named in `who` (creature names or stat block ids).
static func named(c: Combatant, who: Array) -> bool:
	var block := str((c.creature as Monster).data.get("id", "")) if c.creature is Monster else ""
	for w: Variant in who:
		if str(w) == c.name() or (block != "" and str(w) == block):
			return true
	return false


## The thing `c` holds (an object it took), or null.
func held_by(c: Combatant) -> BattleObject:
	for o in objs().list:
		if o.carried_by == c.id and not o.destroyed:
			return o
	return null


# --- Taking and putting -------------------------------------------------------------------------------------------

func take_why(c: Combatant, o: BattleObject) -> String:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act" % c.name()
	if o == null or o.destroyed or o.carry.is_empty() or o.carried_by != "":
		return "Nothing to take there"
	if not c.creature is Character:
		return "Only a hero carries these"
	if held_by(c) != null:
		return "Already carrying %s" % held_by(c).the()
	if objs().distance_ft(c, o) > REACH:
		return "Out of reach: move within 5 ft"
	if e.ground.cost_of(c) == "":
		return "No object interaction or action left"
	return ""


## `c` takes `o` up: its object interaction, else what one costs now.
func take(c: Combatant, oid: String) -> CombatResult:
	var e := enc()
	var o := objs().get_object(oid)
	var why := take_why(c, o)
	if why != "":
		return CombatResult.fail(why)
	var cost := objs().actions._spend_interaction(c)
	objs().clear_squares(o)
	o.carried_by = c.id
	e.log.add("info", "%s takes %s%s" % [c.name(), o.the(), ObjectActions._how(cost)], c.id)
	e.events.append({"type": "object_carried", "id": o.id, "by": c.id})
	return CombatResult.new()


func put_why(c: Combatant, o: BattleObject) -> String:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return why
	if o == null or o.destroyed or o.takes.is_empty() or o.cleansed:
		return "Nothing to put it in"
	var held := held_by(c)
	if held == null or str(held.carry.get("tag", "")) != str(o.takes.get("tag", "")):
		return "Not carrying what it takes"
	if objs().distance_ft(c, o) > REACH:
		return "Out of reach: move within 5 ft"
	return ""


## The Utilize action: the thing `c` carries goes into `o`, with all that brings (the class comment).
func put(c: Combatant, oid: String) -> CombatResult:
	var e := enc()
	var o := objs().get_object(oid)
	var why := put_why(c, o)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	var held := held_by(c)
	held.carried_by = ""
	held.destroyed = true
	if held.flag != "":
		e.legendary.story_flags[held.flag] = true
	o.cleansed = true
	o.hazard = []
	var t := o.takes
	e.log.add("info", "%s puts %s in %s" % [c.name(), held.the(), o.the()], c.id)
	if str(t.get("say", "")) != "":
		e.log.add("info", str(t["say"]), c.id)
	if str(t.get("flag", "")) != "":
		e.legendary.story_flags[str(t["flag"])] = true
	e.events.append({"type": "object_cleansed", "id": o.id, "by": c.id, "used": held.id})
	var lt := t.get("light", {}) as Dictionary
	if not lt.is_empty():
		o.ward = lt.duplicate(true)
		objs().fires_changed()
	var dmg := t.get("damage", {}) as Dictionary
	if not dmg.is_empty():
		for v in e.living():
			if named(v, dmg.get("who", []) as Array):
				e.deal_damage(c, v, [{"amount": int(dmg.get("amount", 0)), "type": str(dmg.get("type", "psychic"))}], false, o.title())
	return e.run_reaction_queue(CombatResult.new())


## Whoever dropped or left the fight with a thing in hand leaves it on its square.
func tidy() -> void:
	var e := enc()
	for o in objs().list:
		if o.carried_by == "" or o.destroyed:
			continue
		var c := e.get_c(o.carried_by)
		if c != null and c.is_alive() and not c.is_down() and not c.has_meta("left_fight"):
			continue
		o.carried_by = ""
		if c != null:
			o.cells = [c.cell] as Array[Vector2i]
		objs().fill_squares(o)
		e.log.add("info", "%s falls to the floor" % o.title(), "")
		e.events.append({"type": "object_carried", "id": o.id, "by": ""})


# --- Studying ----------------------------------------------------------------------------------------------------

func study_why(c: Combatant, o: BattleObject) -> String:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return why
	if o == null or o.destroyed or o.study.is_empty() or o.studied:
		return "Nothing more to learn"
	if not c.creature is Character:
		return "Only a hero studies it"
	if objs().distance_ft(c, o) > STUDY_RANGE:
		return "Too far to study: within 30 ft"
	return ""


## The Study action: the best of `o`'s checks; a success tells what it is.
func study(c: Combatant, oid: String) -> CombatResult:
	var e := enc()
	var o := objs().get_object(oid)
	var why := study_why(c, o)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	var skills := o.study.get("skills", ["investigation"]) as Array
	var best := StringName(str(skills[0]))
	for s: Variant in skills:
		if c.creature.skill_bonus(StringName(str(s))).total() > c.creature.skill_bonus(best).total():
			best = StringName(str(s))
	var t := c.creature.roll_check(e.dice, best, int(o.study.get("dc", 10)), [], [], "Study %s (%s)" % [o.the(), c.name()], ["study"])
	if not t.success:
		e.log.add("info", "%s learns nothing from %s" % [c.name(), o.the()], c.id, [t.describe()])
		return CombatResult.new()
	for other in objs().list:
		if other.study.hash() == o.study.hash():
			other.studied = true   # one look tells what all of their kind are
	e.log.add("info", str(o.study.get("say", "%s works out what %s is" % [c.name(), o.the()])), c.id, [t.describe()])
	if str(o.study.get("flag", "")) != "":
		e.legendary.story_flags[str(o.study["flag"])] = true
	return CombatResult.new()


# --- Hazards and wards -------------------------------------------------------------------------------------------

func _live(o: BattleObject, hz: Dictionary) -> bool:
	var flags := enc().legendary.story_flags
	if str(hz.get("if_flag", "")) != "" and not bool(flags.get(str(hz["if_flag"]), false)):
		return false
	if str(hz.get("unless_flag", "")) != "" and bool(flags.get(str(hz["unless_flag"]), false)):
		return false
	return not o.destroyed and not o.cleansed


func _near(c: Combatant, o: BattleObject, ft: int) -> bool:
	return objs().distance_ft(c, o) <= ft if ft > 0 else c.footprint().any(func(cell: Vector2i) -> bool: return cell in o.cells)


## A step into a square near a hazard (`on: "enter"`), or the end of a turn there (`on: "end"`).
func hazards(c: Combatant, on: String, from: Vector2i = Vector2i(-1, -1)) -> void:
	var e := enc()
	if not c.is_alive() or c.altitude > 0:
		return
	for o in objs().list:
		for raw: Variant in o.hazard:
			var hz := raw as Dictionary
			if str(hz.get("on", "enter")) != on or not _live(o, hz):
				continue
			var ft := int(hz.get("near_ft", 0))
			if not _near(c, o, ft):
				continue
			if on == "enter" and from != Vector2i(-1, -1):
				var was := e.grid.distance_ft(from, c.size_cells, o.cells[0], 1) <= ft if ft > 0 else from in o.cells
				if was:
					continue   # already there: entering means coming in
			var key := "%d:%d" % [e.round_no, e.turn_index]
			if str(o.hazard_hit.get(c.id, "")) == key:
				continue   # once a turn
			o.hazard_hit[c.id] = key
			_strike(c, o, hz)


func _strike(c: Combatant, o: BattleObject, hz: Dictionary) -> void:
	var e := enc()
	var sv := hz.get("save", {}) as Dictionary
	if not sv.is_empty():
		var t := c.creature.roll_save(e.dice, StringName(str(sv["ability"])), int(sv["dc"]), [], [], "%s save vs %s (%s)" % [
			str(sv["ability"]).to_upper(), o.title(), c.name()])
		if t.success:
			e.log.add("info", "%s shrugs off %s" % [c.name(), o.the()], c.id, [t.describe()])
			return
		e.log.add("info", "%s is caught by %s" % [c.name(), o.the()], c.id, [t.describe()])
	if int(hz.get("exhaustion", 0)) > 0:
		c.creature.add_exhaustion(int(hz["exhaustion"]))
		e.log.add("condition", "%s gains %d Exhaustion (%s)" % [c.name(), int(hz["exhaustion"]), o.title()], c.id)
		e.events.append({"type": "condition", "id": c.id})
	var dmg := hz.get("damage", {}) as Dictionary
	if not dmg.is_empty():
		var rolled := e._roll_damage_dice(str(dmg.get("dice", "1d6")), false, 0, o.title())
		e.deal_damage(null, c, [{"amount": int(rolled["total"]), "type": str(dmg.get("type", "fire"))}], false, o.title(), [str(rolled["text"])])


## The wards lit round cleansed things that `c` stands in and is named by: Disadvantage on its D20 Tests.
func ward_disadvantage(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for o in objs().list:
		if o.ward.is_empty() or o.destroyed:
			continue
		if named(c, o.ward.get("disadvantage", []) as Array) and objs().distance_ft(c, o) <= int(o.ward.get("radius", 20)):
			out.append(o.title())
	return out


# --- The menus ---------------------------------------------------------------------------------------------------

func entries(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in objs().list:
		if o.destroyed:
			continue
		if not o.carry.is_empty() and o.carried_by == "" and objs().distance_ft(c, o) <= REACH:
			var cost := enc().ground.cost_of(c)
			out.append(_entry("carry:" + o.id, "Take %s" % o.the(), {"free": "free", "bonus": "Fast Hands", "action": "Utilize"}.get(cost, "") as String,
				cost if cost != "" else "action", take_why(c, o), "Your free object interaction this turn, else the Utilize action: carry it to where it goes."))
		if not o.takes.is_empty() and not o.cleansed and held_by(c) != null:
			out.append(_entry("putin:" + o.id, "%s %s" % [str(o.takes.get("label", "Put it in")), o.the()], "Utilize", "action", put_why(c, o),
				"The Utilize action within 5 ft: what you carry goes in."))
		if not o.study.is_empty() and not o.studied and objs().distance_ft(c, o) <= STUDY_RANGE:
			var skills := (o.study.get("skills", ["investigation"]) as Array).map(func(s: Variant) -> String: return str(s).capitalize())
			out.append(_entry("study:" + o.id, "Study %s" % o.the(), "%s DC %d" % [" or ".join(skills), int(o.study.get("dc", 10))], "action",
				study_why(c, o), "The Study action: a check to tell what it is."))
	return out


func _entry(id: String, label: String, sub: String, cost: String, why: String, help: String) -> Dictionary:
	var a := objs()._entry(id, label, sub, cost, why, "none", help)
	a["tab"] = ActionCatalog.COMMON
	a["range"] = REACH
	return a


## Carries out a take, put or study line; null if `id` isn't one.
func perform(c: Combatant, id: String) -> CombatResult:
	if id.begins_with("carry:"):
		return take(c, id.substr(6))
	if id.begins_with("putin:"):
		return put(c, id.substr(6))
	if id.begins_with("study:"):
		return study(c, id.substr(6))
	return null
