class_name LastAct
extends RefCounted
## A hero's willing death to cripple a foe (a set piece's `last_act`: R26's lava, the Brimstone Behemoth): a hero within
## 5 ft takes the action, asked once more first since it can't be undone. The hero dies for good: their soul is gone
## (Character.soul_gone: no revival by any means), the creatures named in `target` take `effect` ({name, modifiers,
## no_legendary_resistance}) for the rest of the fight, and `flag` is set for the story. A set piece's `last_act` is
## {label, target: [names or stat blocks], effect, flag, say}.

const KIND := "last_act"
const REACH := 5


static func entries(e: Encounter, c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.side in [&"party", &"guest"] or not c.creature is Character:
		return out
	for o in e.objects.list:
		if o.destroyed or o.last_act.is_empty():
			continue
		var why := e._action_check(c)
		if why == "" and e.objects.distance_ft(c, o) > REACH:
			why = "Get within 5 ft of %s first" % o.the()
		out.append({"id": "lastact:" + o.id, "label": str(o.last_act.get("label", "Give yourself to it")), "sub": "for good",
			"why": why, "help": "%s dies for good, beyond any revival, and what it was for is done." % c.name()})
	return out


## Asks first; on a yes, the hero goes.
static func take(e: Encounter, c: Combatant, oid: String) -> CombatResult:
	var o := e.objects.get_object(oid)
	if o == null or o.last_act.is_empty():
		return CombatResult.fail("Nothing to give yourself to")
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if e.objects.distance_ft(c, o) > REACH:
		return CombatResult.fail("Get within 5 ft first")
	var req := ReactionRequest.new(KIND, c.id, "")
	req.title = str(o.last_act.get("label", "Give yourself to it"))
	req.text = "%s will die for good: no spell, item or wish brings them back. Go?" % c.name()
	req.cost = "Action"
	req.spends_reaction = false
	req.continuation = func(use: bool) -> CombatResult:
		if use:
			_go(e, c, o)
		return CombatResult.new()
	e.pending = req
	return CombatResult.new()


static func _go(e: Encounter, c: Combatant, o: BattleObject) -> void:
	e.spend_action(c)
	var la := o.last_act
	var ch := c.creature as Character
	ch.build["soul_gone"] = str(la.get("label", "A last act"))
	ch.hp = 0
	ch.dead = true
	e.log.add("info", "%s %s" % [c.name(), str(la.get("say", "gives their life"))], c.id)
	e.events.append({"type": "death", "id": c.id})
	var eff := la.get("effect", {}) as Dictionary
	for t in e.combatants:
		if not t.is_alive() or not FightMeters._named(t, la.get("target", []) as Array):
			continue
		var fx := Effect.new(str(eff.get("name", "Crippled")), &"feature", "last_act")
		fx.ends = Effect.Ends.NEVER
		for md: Variant in eff.get("modifiers", []):
			var mdd := (md as Dictionary).duplicate()
			var stat := str(mdd["stat"])
			mdd.erase("stat")
			fx.with_modifier(stat, mdd)
		t.creature.add_effect(fx)
		if bool(eff.get("no_legendary_resistance", false)):
			t.set_meta("legendary_resistance_used", 99)
		e.log.add("condition", "%s is %s" % [t.name(), str(eff.get("name", "crippled"))], t.id)
		e.events.append({"type": "condition", "id": t.id})
	if str(la.get("flag", "")) != "":
		e.legendary.story_flags[str(la["flag"])] = true
	e._check_over()
