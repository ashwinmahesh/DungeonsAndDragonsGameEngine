class_name HeldObjects
extends RefCounted
## Things a monster holds that the heroes can strike (a rotweaver's horn, a kackle's lantern): a trait's `held_object`
## {name, ac, hp, needs: [action ids], owner_share, owner_type} puts an object in the fight held by the creature
## (BattleObject.held_target, carried_by the holder), on the holder's square. Heroes strike it from the Common tab with
## their weapon (EncounterObjects.attack: Armor Class and Hit Points of its own). Once it breaks, the holder's actions in
## `needs` can't be used (the horn's Call the Rot); with `owner_share` the holder takes that share of the damage the
## object takes, as `owner_type` (the lantern's half as Force). Saved with the fight's objects.


## Puts `c`'s held objects in the fight (once each: a fight picked up from a save has them already).
static func ensure(e: Encounter, c: Combatant) -> void:
	if not c.creature is Monster:
		return
	for tv: Variant in e.monster_actions.traits(c):
		var tr := tv as Dictionary
		var spec := tr.get("held_object", {}) as Dictionary
		if spec.is_empty():
			continue
		var oid := "held:%s:%s" % [c.id, str(tr.get("id", ""))]
		if e.objects.get_object(oid) != null:
			continue
		var cells: Array[Vector2i] = [c.cell]
		var o := e.objects.add("vessel", cells, {"name": str(spec.get("name", "its relic"))})
		o.id = oid
		o.ac = int(spec.get("ac", 15))
		o.hp_max = int(spec.get("hp", 10))
		o.hp = o.hp_max
		o.carried_by = c.id
		o.held_target = true
		o.held = spec.duplicate(true)


## Keeps a held object on its holder's squares (for reach and line of sight).
static func follow(e: Encounter, o: BattleObject) -> void:
	var holder := e.get_c(o.carried_by)
	if holder != null:
		o.cells = holder.footprint()


## Why `c` can't use `act`: a held object it needs is broken. "" otherwise.
static func broken_for(e: Encounter, c: Combatant, act: Dictionary) -> String:
	var aid := str(act.get("id", ""))
	for o in e.objects.list:
		if o.held_target and o.destroyed and o.carried_by == c.id and (o.held.get("needs", []) as Array).has(aid):
			return "%s is broken" % o.title()
	return ""


## The Common tab's strikes at held objects within `c`'s reach: "heldhit:<object id>|<attack option id>", with the
## first weapon that can.
static func entries(e: Encounter, c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.side in [&"party", &"guest"]:
		return out
	for o in e.objects.list:
		if not o.held_target or o.destroyed:
			continue
		var holder := e.get_c(o.carried_by)
		if holder == null or not holder.is_alive() or not c.hostile_to(holder):
			continue
		follow(e, o)
		var pick := ""
		var why := "Get within reach first"
		for opt in e.attack_options(c):
			if str(opt["kind"]) == "unarmed":
				continue
			var w := e.objects.attack_why(c, o, opt)
			if w == "":
				pick = str(opt["id"])
				why = ""
				break
		out.append({"id": "heldhit:%s|%s" % [o.id, pick], "label": "Strike %s" % o.title(), "sub": "AC %d · %d HP" % [o.ac, o.hp],
			"why": why, "help": "Strike the thing %s holds; once it breaks, what it needs it for is gone." % holder.name()})
	return out


## After `o` took `amount` damage: its holder takes its share (`owner_share`, as `owner_type`).
static func hurt_owner(e: Encounter, o: BattleObject, amount: int, by: Combatant) -> void:
	if not o.held_target or amount <= 0:
		return
	var share := float(o.held.get("owner_share", 0.0))
	var holder := e.get_c(o.carried_by)
	if share <= 0.0 or holder == null or not holder.is_alive():
		return
	var dmg := maxi(1, int(floor(amount * share)))
	e.deal_damage(by, holder, [{"amount": dmg, "type": str(o.held.get("owner_type", "force"))}], false, o.title(),
		["%s takes %d of the %d its %s took" % [holder.name(), dmg, amount, o.title()]])
