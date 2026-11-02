class_name EncounterTurns
extends RefCounted
## Turns in a fight (Encounter): Initiative and the turn order, each turn's start and end, new rounds and the
## lair's turn, the end of the fight, AI turns, and the action economy's checks (whose turn it is; whether an action, a
## Bonus Action or an attack is left).

var _enc: WeakRef
## Set while a turn begins inside the running shared turn (_take_shared, Time Stop): _join_shared keeps the group.
var _keep_group := false


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## Rolls Initiative (2024: a Dexterity check; surprised creatures roll with Disadvantage; identical monsters share
## one roll) and starts round 1. Ties: higher Dexterity first, then the party.
func start(surprised_ids: Array = []) -> void:
	var e := enc()
	surprised_ids = e.items.surprise_filter(surprised_ids)
	e.faerun.before_initiative()
	var group_rolls := {}
	for c in e.combatants:
		c.surprised = c.id in surprised_ids
		var group := c.initiative_group   # set before the fight began (a rider and its steed: EncounterMounts.seat)
		if group == "" and c.creature is Monster:
			group = str((c.creature as Monster).data.get("id", ""))
		if group != "" and group_rolls.has(group):
			c.initiative = int(group_rolls[group])
			c.initiative_group = group
			continue
		var dis: Array[String] = []
		if c.surprised:
			dis.append("Surprised")
		var bonus := c.creature.initiative_bonus()
		var init_adv := e.items.initiative_advantage(c)
		init_adv.append_array(e.faerun.initiative_advantage(c))
		init_adv.append_array(e.game.initiative_advantage(c))
		var t := c.creature.roll_d20(e.dice, D20Test.Kind.ABILITY_CHECK, bonus, 0, c.creature.initiative_keys(), init_adv, dis,
			"Initiative (%s)" % c.name())
		# Ambush (Battle Master): a Superiority Die on Initiative.
		if e.features.knows_maneuver(c, "ambush") and (c.creature as Character).resource_left("superiority_dice") > 0:
			(c.creature as Character).spend_resource("superiority_dice")
			t.add_bonus(e.dice.roll_one(e.features.superiority_die(c), "Ambush"), "Ambush")
		var item_init := e.items.initiative_bonus(c)
		if item_init > 0:
			t.add_bonus(item_init, "Sword of Kas")
		c.initiative_test = t
		c.initiative = t.total
		if group != "":
			group_rolls[group] = t.total
			c.initiative_group = group
		e.log.add("roll", "%s rolls Initiative: %d" % [c.name(), t.total], c.id, [t.describe(), bonus.describe()])
	e.class_features.initiative_rolled()
	_symptoms_on_initiative()
	e.ravenloft.initiative_rolled()
	e.faerun.initiative_rolled()
	e.game.initiative_rolled()
	e.echo_knight.initiative_rolled()
	_order_by_initiative()
	# Decoy images come after the order is set: they have no turns (DecoyImages).
	e.images.initiative_rolled()
	# Portent (Diviner): the two (Greater Portent: three) foreseen d20s for this fight.
	for c in e.combatants:
		if CombatFeatures.has_feature(c, "portent") and c.creature is Character:
			var n := 3 if CombatFeatures.has_feature(c, "greater_portent") else 2
			c.set_meta("portent_rolls", e.dice.roll(20, n, "Portent"))
			e.log.add("info", "%s foresees: %s (Portent)" % [c.name(), str(c.get_meta("portent_rolls"))], c.id)
	e.state = Encounter.State.ACTIVE
	for cc in e.combatants:
		e.class_features.prepare(cc)
	e.items.combat_started()
	e.spells.zones.refresh_auras()
	e.round_no = 1
	e.log.round_no = 1
	e.log.add("turn", "Round 1", "")
	e.events.append({"type": "round", "round": 1})
	e.legendary.combat_started()
	e.game.fight_started()
	e.turn_index = 0
	# Choices once Initiative is rolled (Tandem Footwork): asked before the first turn, which then begins with the order
	# they settle. A prompt here leaves `pending` set for the view, as any other does.
	var offers := e.class_features.initiative_offers()
	if offers.is_empty():
		_keep_round()
		_lair_then_begin()
		return
	e.reactions.offer(offers, func() -> CombatResult:
		_order_by_initiative()
		e.turn_index = 0
		_keep_round()
		return _lair_then_begin(), CombatResult.new())


## The turn order from Initiative: highest first; ties go to higher Dexterity, then the party. Thief's Reflexes (Thief
## 17) adds a second turn in the first round at Initiative − 10.
func _order_by_initiative() -> void:
	var e := enc()
	_clear_shared()   # a new order: the next turn to begin makes its own group
	e.order = e.combatants.duplicate()
	e.order.assign(e.order.filter(func(c: Combatant) -> bool: return not DecoyImages.is_image(c)))   # images have no turns
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		var da := a.creature.ability_score(&"dex")
		var db := b.creature.ability_score(&"dex")
		if da != db:
			return da > db
		return a.side == &"party" and b.side != &"party")
	for c: Combatant in e.combatants.duplicate():
		if CombatFeatures.has_feature(c, "thiefs_reflexes"):
			var at := e.order.size()
			for i in e.order.size():
				if e.order[i].initiative < c.initiative - 10:
					at = i
					break
			e.order.insert(at, c)
			c.set_meta("reflex_turn", true)


## Begins the current creature's turn: effects that end, a readied spell let go, the turn's resources, then each part
## of the game that acts as a turn starts. Saves and Reactions there can stop for the player's answer (F6), so the
## parts run one after another (Encounter.each) and the queued reactions run last.
func _begin_turn() -> CombatResult:
	var e := enc()
	var c := e.current()
	if c == null:
		return CombatResult.new()
	_join_shared(c)
	for o in e.combatants:
		o.cast_slot_spell_this_turn = false
		o.creature.on_turn_start(c.id)
	e._expire_marks(c.id, "start")
	e.movement.settle_all()   # a flyer whose flight ended comes down (F4)
	if c.readied.has("spell"):
		e.log.add("info", "%s lets the readied spell go" % c.name(), c.id)
	c.swimming = e.grid.swimmable and c.altitude <= 0 and c.footprint().any(func(f: Vector2i) -> bool: return e.grid.has_flag(f, CombatGrid.WATER))
	c.reset_turn()
	if c.creature.has_flag("hasted"):
		c.haste_action = true
	e.log.add("turn", "%s's turn" % c.name(), c.id)
	e.events.append({"type": "turn", "id": c.id, "round": e.round_no})
	# Legendary actions come back; Regeneration (before anything else starts this turn); a foe whose time is up leaves.
	e.legendary.turn_start(c)
	if not c.is_alive():
		return CombatResult.new()
	var none := CombatResult.new()
	var steps: Array = [
		func() -> CombatResult: return e.spells.turn_start(c),
		func() -> CombatResult:
			e.objects.turn_start(c)
			e.zones.turn_start(c)
			e.openings.turn_start(c)   # thrown out of a window: the climb back in
			e.feature_actions.turn_start(c)
			return none,
		func() -> CombatResult: return e.class_features.turn_start(c),
		func() -> CombatResult:
			e.ravenloft.turn_start(c)
			e.faerun.turn_start(c)
			e.echo_knight.turn_start(c)
			return none,
		func() -> CombatResult: return e.monster_actions.turn_start(c),
		func() -> CombatResult: return e.game.turn_start(c),
		func() -> CombatResult:
			e.items.turn_start(c)
			e.triggered_features.turn_start(c)
			return none,
	]
	return e.each(steps, func(step: Variant) -> CombatResult: return (step as Callable).call() as CombatResult, func() -> CombatResult:
		_turn_start_flags(c)
		return e.run_reaction_queue(CombatResult.new()))


## The last of a turn's start: Dazed, a dropped weapon picked up, a turn without an action, an AI creature's Death
## Saving Throw.
func _turn_start_flags(c: Combatant) -> void:
	var e := enc()
	if not c.is_alive() or e.current() != c:
		return
	if c.creature.has_flag("dazed"):
		e.log.add("info", "%s is Dazed: this turn it can move, take an action or take a Bonus Action, one of the three" % c.name(), c.id)
	if c.creature.has_flag("no_action_or_bonus"):
		c.action_available = false
		c.bonus_available = false
		e.log.add("info", "%s can't take an action or a Bonus Action this turn" % c.name(), c.id)
	if e.needs_death_save(c) and not c.is_player_controlled():
		e.death_save(c, false)
	_take_opening(c)


## The party's chosen opening (Encounter.opening), made by `c` as its first turn begins: the flask thrown at its target
## (EncounterActions.throw_flask), costing one of its attacks as any throw does. Spent whether or not it could be made.
func _take_opening(c: Combatant) -> void:
	var e := enc()
	if e.opening.is_empty() or str(e.opening.get("by", "")) != c.id:
		return
	var o := e.opening
	e.opening = {}
	var target := e.get_c(str(o.get("target", "")))
	if str(o.get("kind", "")) != "flask" or target == null or not target.is_alive() or target.has_meta("left_fight") or not c.can_act():
		return
	var r := e.actions.throw_flask(c, str(o["item"]), target)
	if not r.ok:
		e.log.add("info", "%s can't throw it now: %s" % [c.name(), r.reason], c.id)


## Ends the current creature's turn: end-of-turn effects and repeated saves, then the next creature (and round).
func end_turn() -> CombatResult:
	var e := enc()
	if e.pending != null:
		return CombatResult.fail("Answer the reaction prompt first")
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.fail("Combat is over")
	var c := e.current()
	# A Death Saving Throw and the repeated saves can stop for the choices after their rolls (Heroic Inspiration,
	# Indomitable): the rest of the turn's end waits for the answer.
	if e.needs_death_save(c):
		var ds := e.death_save(c)
		if e.pending != null:
			return e.then(ds, func() -> CombatResult: return _turn_end_effects(c))
		if e.state != Encounter.State.ACTIVE:
			return CombatResult.new()
	return _turn_end_effects(c)


func _turn_end_effects(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.new()
	for o in e.combatants:
		o.creature.on_turn_end(c.id)
	e._expire_marks(c.id, "end")
	c.armed.clear()
	e.feature_actions.turn_end(c)
	return e.then(e.class_features.turn_end(c), func() -> CombatResult: return _turn_end_rest(c))


## The rest of the end of `c`'s turn, once Inspiring Movement (or another Reaction there) is answered.
func _turn_end_rest(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.new()
	e.ravenloft.turn_end(c)
	e.faerun.turn_end(c)
	e.echo_knight.turn_end(c)
	e.monster_actions.turn_end(c)
	e.game.turn_end(c)
	e.items.turn_end(c)
	e.triggered_features.turn_end(c)
	return e.then(e.spells.turn_end(c), func() -> CombatResult:
		e.objects.turn_end(c)
		e.zones.turn_end(c)
		e.legendary.round_events.turn_end(c)   # a possession's repeated save (`possess`)
		HoldBreath.turn_end(e, c)   # a held breath runs out
		e.meters.scan()   # what the turn did that moves a meter (`on`: a foe falling, a crit, a failed save)
		e.spells.zones.prune()
		e.movement.settle_all()   # a flyer whose flight ended comes down (F4)
		_step_out(c)
		_check_over()
		if e.state != Encounter.State.ACTIVE:
			return CombatResult.new()
		# Reactions the turn's end queued (damage from an area): offered before the next turn.
		return e.then(e.run_reaction_queue(CombatResult.new()), func() -> CombatResult:
			_check_over()
			if e.state != Encounter.State.ACTIVE:
				return CombatResult.new()
			# Legendary actions at the end of another creature's turn (not while time is stopped).
			var stopped := c.has_meta("time_stop") and int(c.get_meta("time_stop")) > 0
			var lr := e.legendary.after_turn(c) if not stopped else CombatResult.new()
			if e.pending != null:
				return e.then(lr, func() -> CombatResult: return _next_turn(c))
			return _next_turn(c)))


## After `c`'s turn (and any legendary actions): the next creature, a new round, the lair's turn.
func _next_turn(c: Combatant) -> CombatResult:
	var e := enc()
	_check_over()
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.new()
	# Time Stop: the caster's next turn comes straight away.
	if c.has_meta("time_stop") and int(c.get_meta("time_stop")) > 0 and c.is_alive() and c.can_act():
		c.set_meta("time_stop", int(c.get_meta("time_stop")) - 1)
		e.log.add("turn", "Time is still stopped: another turn for %s" % c.name(), c.id)
		_keep_group = true
		return _begin_turn()
	c.remove_meta("time_stop")
	# A shared party turn goes on while any of its heroes hasn't taken theirs: control passes to the next of them.
	_check_shared()
	if c.id in e.shared:
		if not c.id in e.shared_ended:
			e.shared_ended.append(c.id)
		var next := _next_shared()
		if next != null:
			return _take_shared(next)
		e.turn_index = _shared_index(e.get_c(e.shared.back()))
		_clear_shared()
	var was := e.round_no
	_advance_index()
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.new()
	if e.round_no != was:
		_keep_round()
	return _lair_then_begin()


# --- Shared party turns (owner 2026-10-09, after Baldur's Gate 3) -------------------------------------------------
# Heroes next to each other in the order take their turns together: each one's turn starts the first time the player
# takes control of them (switch_to, or when the one before ends) and ends when they end it, so everything keyed to a
# creature's own turn (its start, its end, "until your next turn") still happens once, at its own time.

## The shared turn `c` starts or joins (Encounter.shared): the running one when control passes within it (or Time Stop
## gives its hero another turn), else a new group from here, so an order changed meanwhile never leaves a stale one.
func _join_shared(c: Combatant) -> void:
	var e := enc()
	if not (_keep_group and c.id in e.shared):
		_clear_shared()
		e.shared = _shared_group()
	_keep_group = false
	if c.id in e.shared and not c.id in e.shared_started:
		e.shared_started.append(c.id)


## The heroes from the current place in the order who share its turn: the run of player-run party members and guests
## in a row (a creature that's down or gone is passed over; the lair's count 20 or anyone else ends the run), when it's
## two or more and the option is on.
func _shared_group() -> Array[String]:
	var e := enc()
	var out: Array[String] = []
	if not e.shared_turns or e.turn_index < 0:
		return out
	var lair := e.legendary.lair_slot()
	for i in range(e.turn_index, e.order.size()):
		var o := e.order[i]
		if i > e.turn_index and i == lair:
			break
		if not o.is_alive() or o.has_meta("left_fight"):
			continue
		if not _shares(o) or o.id in out:
			break   # a foe, a creature the AI plays, or a second turn of the same hero
		out.append(o.id)
	if out.size() < 2:
		out.clear()
	return out


## Whether `o` takes part in a shared party turn: a party member or guest the player runs, not compelled by a spell.
func _shares(o: Combatant) -> bool:
	return o.is_player_controlled() and o.side in [&"party", &"guest"] and not compelled(o) and not EchoKnight.is_echo(o)


## Drops a shared turn that no longer matches the order (a feature or a test that re-sorts it, an Initiative swap):
## its heroes must still stand in a row from the first (passing over the fallen and the gone), with the one in control
## among them. Called wherever the group is used, so a stale one never hands a turn to the wrong creature.
func _check_shared() -> void:
	var e := enc()
	if e.shared.is_empty():
		return
	var cur := e.current()
	var ok := cur != null and cur.id in e.shared
	var start := e.order.find(e.get_c(e.shared[0])) if ok else -1
	var k := 0
	var i := start
	while ok and i >= 0 and i < e.order.size() and k < e.shared.size():
		var o := e.order[i]
		if o.id == e.shared[k]:
			k += 1
		elif o.is_alive() and not o.has_meta("left_fight"):
			ok = false
		i += 1
	if not ok or k < e.shared.size():
		_clear_shared()


func _clear_shared() -> void:
	var e := enc()
	e.shared.clear()
	e.shared_started.clear()
	e.shared_ended.clear()


## Where `c` stands in the order within the shared turn.
func _shared_index(c: Combatant) -> int:
	var e := enc()
	var start := e.order.find(e.get_c(e.shared[0])) if not e.shared.is_empty() else 0
	var at := e.order.find(c, maxi(0, start))
	return at if at >= 0 else e.order.find(c)


## The first hero of the shared turn who hasn't ended theirs and can still take it, or null.
func _next_shared() -> Combatant:
	var e := enc()
	for id in e.shared:
		var o := e.get_c(id)
		if o != null and not id in e.shared_ended and o.is_alive() and not o.has_meta("left_fight"):
			return o
	return null


## Control to `c`, a hero of the shared turn: their turn starts if it hasn't yet, else it goes on.
func _take_shared(c: Combatant) -> CombatResult:
	var e := enc()
	e.turn_index = _shared_index(c)
	if c.id in e.shared_started:
		e.events.append({"type": "switch", "id": c.id})
		return CombatResult.new()
	_keep_group = true
	return _begin_turn()


## The player takes control of another hero sharing the turn (a click on their frame, Tab): theirs starts the first
## time, then goes on where it was left; the one left keeps what it hasn't used until control comes back to it.
func switch_to(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.fail("Combat is over")
	if e.pending != null:
		return CombatResult.fail("Answer the reaction prompt first")
	_check_shared()
	if c == null or not c.id in e.shared or c.id in e.shared_ended or not c.is_alive():
		return CombatResult.fail("%s isn't sharing this turn" % (c.name() if c != null else "No one"))
	if c == e.current():
		return CombatResult.new()
	return _take_shared(c)


## The heroes sharing the turn who can still take theirs, the one in control first.
func shared_heroes() -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	_check_shared()
	if e.shared.is_empty():
		return out
	var cur := e.current()
	if cur != null and cur.id in e.shared:
		out.append(cur)
	for id in e.shared:
		var o := e.get_c(id)
		if o != null and o != cur and not id in e.shared_ended and o.is_alive() and not o.has_meta("left_fight"):
			out.append(o)
	return out


## The round as it begins, before the lair and the first turn (Encounter.keep_round_snapshots).
func _keep_round() -> void:
	var e := enc()
	if e.keep_round_snapshots:
		e.round_snapshot = EncounterSnapshot.capture(e).duplicate(true)   # kept apart from what the round goes on to change


## Moves `turn_index` to the next living creature, starting a new round past the end of the order (a lair that hasn't
## acted yet this round acts first; called creatures arrive as the new round begins).
func _advance_index() -> void:
	var e := enc()
	for i in e.order.size():
		e.turn_index += 1
		if e.turn_index >= e.order.size():
			e.legendary.round_ending()
			if e.state != Encounter.State.ACTIVE:
				return
			_clock_runs_out()
			if e.state != Encounter.State.ACTIVE:
				return
			e.turn_index = 0
			e.round_no += 1
			_drop_reflex_turns()
			e.log.round_no = e.round_no
			e.log.add("turn", "Round %d" % e.round_no, "")
			e.events.append({"type": "round", "round": e.round_no})
			e.legendary.round_started()
			e.game.round_started(e.round_no)
			e.objects.round_started()
			e.images.check_flags()
		if e.current().is_alive() and not e.current().has_meta("left_fight"):
			break


## The lair acts on initiative count 20 (losing ties) before the first creature below 20; then the turn begins.
func _lair_then_begin() -> CombatResult:
	var e := enc()
	if not e.legendary.lair_due():
		return _begin_turn()
	return e.then(e.legendary.lair_turn(), func() -> CombatResult:
		_check_over()
		if e.state != Encounter.State.ACTIVE:
			return CombatResult.new()
		if not e.current().is_alive():
			_advance_index()
			if e.state != Encounter.State.ACTIVE:
				return CombatResult.new()
		return _begin_turn())


## After round 1, Thief's Reflexes' extra turns leave the order.
func _drop_reflex_turns() -> void:
	var e := enc()
	for c in e.combatants:
		if c.has_meta("reflex_turn"):
			c.remove_meta("reflex_turn")
			var first := e.order.find(c)
			var second := e.order.find(c, first + 1)
			if second >= 0:
				e.order.remove_at(second)


func _check_over() -> void:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return
	var party_up := false
	var enemies_up := false
	for c in e.combatants:
		# A creature that fell out of the fight (EncounterMovement.leave_grid) no longer counts for either side, nor one
		# knocked out (it's out until a Short Rest is over), nor a foe that surrendered (F13).
		if not c.is_alive() or c.creature.hp <= 0 or c.creature.has_flag("spell_object") or c.has_meta("left_fight") or DecoyImages.is_image(c) \
				or c.creature.has_flag("knocked_out") or c.creature.has_flag("surrendered"):
			continue
		if c.side in [&"party", &"guest"]:
			party_up = true
		elif c.side == &"enemy":
			enemies_up = true
	if _ward_fallen() != null:
		e.state = Encounter.State.OVER
		e.outcome = "ended" if str(e.ends_when.get("ward_lost", "defeat")) == "ended" else "defeat"
		e.log.add("info", "%s is lost" % _ward_fallen().name(), "")
	elif (not enemies_up and meters_met() and bool(e.ends_when.get("foes_end_it", true))) or _wards_out():
		e.state = Encounter.State.OVER
		e.outcome = "victory" if (e.ends_when.get("meters_needed", []) as Array).is_empty() else str(e.ends_when.get("meters_outcome", "victory"))
	elif _party_left():
		e.state = Encounter.State.OVER
		e.outcome = "ended"
		e.log.add("info", "The party has left the fight", "")
	elif not party_up:
		e.state = Encounter.State.OVER
		e.outcome = "defeat"
	elif _first_to_hurt_down() != null:
		e.state = Encounter.State.OVER
		e.outcome = "ended"
		e.log.add("info", "%s is down, and the fight goes out of the foes" % _first_to_hurt_down().name(), "")
	if e.state == Encounter.State.OVER:
		_wrap_up()


## Whether every meter the fight needs (`ends_when.meters_needed`: [{meter, value}], a rite's six successes) has
## reached its value; beating the foes doesn't end the fight before.
func meters_met() -> bool:
	var e := enc()
	for n: Variant in e.ends_when.get("meters_needed", []):
		if e.meters.value(str((n as Dictionary)["meter"])) < int((n as Dictionary).get("value", 1)):
			return false
	return true


## Ends the fight now with `outcome` (the clock running out).
func _finish(outcome: String) -> void:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return
	e.state = Encounter.State.OVER
	e.outcome = outcome
	_wrap_up()


## What every fight's end does, however it ended.
func _wrap_up() -> void:
	var e := enc()
	e.meters.store_values()   # a meter the story keeps (a beacon's brilliant successes)
	# The party gathers what it dropped or threw; the foes' weapons left lying are loot.
	e.ground.fight_over()
	# A relic spent in the fight crumbles (Saint Markovia's Thighbone, once it has hit a vampire).
	e.items.fight_over()
	# An Antimagic Field doesn't outlast the fight: magic items wake up again.
	for c in e.combatants:
		for who: Creature in [c.creature, e.shapes.original(c)]:
			if who is Character:
				(who as Character).magic_suppressed = false
	e.log.add("info", {"victory": "Victory!", "ended": "The fight is over."}.get(e.outcome, "The party has fallen.") as String, "")
	e.events.append({"type": "over", "outcome": e.outcome})


# --- Fights that end with no winner (Encounter.ends_when) -----------------------------------------------------------

## An affliction's symptom that strikes as Initiative is rolled (`on_initiative`: {save {ability, dc}, flag, rounds (10)}):
## a failed save leaves the creature under that flag for the fight (`confused`: it acts as Confusion makes it).
func _symptoms_on_initiative() -> void:
	var e := enc()
	for c in e.combatants:
		for h in Afflictions.hooks(c.creature, "on_initiative"):
			var hook := h["hook"] as Dictionary
			var sv := hook.get("save", {}) as Dictionary
			var ab := StringName(str(sv.get("ability", "wis")))
			var t := c.creature.roll_save(e.dice, ab, int(sv.get("dc", 10)), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab],
				str((h["symptom"] as Dictionary).get("name", "a symptom")), c.name()])
			if t.success:
				continue
			var fx := Effect.new(str((h["symptom"] as Dictionary).get("name", h["affliction"])), &"affliction", "symptom")
			fx.ends = Effect.Ends.ROUNDS
			fx.rounds_left = int(hook.get("rounds", 10))
			fx.modifiers.append(Modifier.make({"stat": "flag", "value": str(hook.get("flag", "confused"))}, fx.name, &"affliction"))
			c.creature.add_effect(fx)
			e.log.add("condition", "%s is overcome (%s)" % [c.name(), fx.name], c.id, [t.describe()])


## The meta on the first hero to hurt a foe in a fight that ends when they drop (`trigger_hero_down`).
const FIRST_TO_HURT := "first_to_hurt"
## The meta holding where a hero who stepped out by an exit stood ([x, y]): they are there once the fight is over.
const LEFT_AT := "left_at"


## Whether `c` is one of the heroes: the party and guests, not what they summoned.
static func _hero(c: Combatant) -> bool:
	return c.side in [&"party", &"guest"] and not c.has_meta("summoner")


## `source` hurt `target`: the first hero to hurt a foe is marked, in a fight that ends when they drop.
func note_hurt(source: Combatant, target: Combatant) -> void:
	var e := enc()
	if not bool(e.ends_when.get("trigger_hero_down", false)) or not _hero(source) or target.side != &"enemy":
		return
	if e.combatants.any(func(o: Combatant) -> bool: return o.has_meta(FIRST_TO_HURT)):
		return
	source.set_meta(FIRST_TO_HURT, true)


## The first hero to hurt a foe, if they are down now (`trigger_hero_down`), else null.
func _first_to_hurt_down() -> Combatant:
	var e := enc()
	if not bool(e.ends_when.get("trigger_hero_down", false)):
		return null
	for c in e.combatants:
		if c.has_meta(FIRST_TO_HURT):
			return c if c.is_down() else null
	return null


## An object the fight is about is gone: with every one of `ends_when.objects_gone` (object ids) broken or undone, the
## fight ends (`objects_outcome`: victory, the default, or ended). EncounterObjects calls it as each breaks.
func objects_gone_check() -> void:
	var e := enc()
	var ids := e.ends_when.get("objects_gone", []) as Array
	if ids.is_empty() or e.state != Encounter.State.ACTIVE:
		return
	for id: Variant in ids:
		var o := e.objects.get_object(str(id))
		if o != null and not o.destroyed:
			return
	e.log.add("info", "Everything the fight was for is done", "")
	e.events.append({"type": "objects_gone"})
	_finish("ended" if str(e.ends_when.get("objects_outcome", "victory")) == "ended" else "victory")


## The meta on a creature the party must keep alive in this fight (a location monster entry's `ward: true`): its fall
## loses the fight, and with `ends_when.ward_exits` getting every ward out by one wins it.
const WARD := &"ward"


static func is_ward(c: Combatant) -> bool:
	return bool(c.creature.get_meta(WARD, false))


## A ward that has fallen (dead or at 0 Hit Points, still on the board), or null.
func _ward_fallen() -> Combatant:
	for c in enc().combatants:
		if is_ward(c) and not c.has_meta("left_fight") and (not c.is_alive() or c.creature.hp <= 0):
			return c
	return null


## Whether every ward has left by a ward exit (and there is one).
func _wards_out() -> bool:
	var e := enc()
	if (e.ends_when.get("ward_exits", []) as Array).is_empty():
		return false
	var wards := e.combatants.filter(func(c: Combatant) -> bool: return is_ward(c))
	return not wards.is_empty() and wards.all(func(c: Combatant) -> bool: return str(c.get_meta("left_fight", "")) == "exit")


## A hero who ends their turn up on one of `ends_when.exits` steps out of the fight there; so does a ward on one of
## `ends_when.ward_exits`.


## The rounds left on the fight's clock (`ends_when.rounds`), this one counted; -1 when it has none.
func clock_left() -> int:
	var e := enc()
	var rounds := int(e.ends_when.get("rounds", 0))
	return maxi(0, rounds - e.meters.clock_lost - maxi(1, e.round_no) + 1) if rounds > 0 else -1


## As a round ends: the clock's last round is over, so the fight ends as the clock says (the mill falls, the rite is
## done, the party held out), its flag set for the story; a countdown only (`none`) sets the flag and goes on.
func _clock_runs_out() -> void:
	var e := enc()
	var rounds := int(e.ends_when.get("rounds", 0))
	# A round lost to the fight (FightMeters.shift_clock) brings the end nearer; it rings once.
	if rounds <= 0 or e.meters.clock_rang or e.round_no < rounds - e.meters.clock_lost:
		return
	e.meters.clock_rang = true
	var outcome := str(e.ends_when.get("rounds_outcome", "ended"))
	if not outcome in ["victory", "defeat", "ended", "none"]:
		outcome = "ended"
	var flag := str(e.ends_when.get("rounds_flag", ""))
	if flag != "":
		e.legendary.story_flags[flag] = true
	var label := str(e.ends_when.get("rounds_label", ""))
	e.log.add("info", "Time is up%s" % ((": " + label) if label != "" else ""), "")
	e.events.append({"type": "clock", "outcome": outcome, "label": label, "rounds": rounds})
	if outcome != "none":   # a countdown only: what it counted down to happens in the fight itself (a round event)
		_finish(outcome)


## A hero who ends their turn up on one of `ends_when.exits` steps out of the fight there.
func _step_out(c: Combatant) -> void:
	var e := enc()
	if is_ward(c) and not c.is_down() and not c.has_meta("left_fight"):
		for x: Variant in e.ends_when.get("ward_exits", []):
			if Vector2i(int((x as Array)[0]), int((x as Array)[1])) in c.footprint():
				c.set_meta(LEFT_AT, [c.cell.x, c.cell.y])
				e.log.add("move", "%s gets out" % c.name(), c.id)
				e.movement.leave_grid(c, "exit")
				return
	var exits := e.ends_when.get("exits", []) as Array
	if exits.is_empty() or not _hero(c) or c.is_down() or c.has_meta("left_fight"):
		return
	for x: Variant in exits:
		if Vector2i(int((x as Array)[0]), int((x as Array)[1])) in c.footprint():
			c.set_meta(LEFT_AT, [c.cell.x, c.cell.y])
			e.log.add("move", "%s leaves the fight" % c.name(), c.id)
			e.movement.leave_grid(c, "exit")
			return


## Whether the party has left: a hero stepped out by an exit, and no hero who is up is still on the board.
func _party_left() -> bool:
	var e := enc()
	if (e.ends_when.get("exits", []) as Array).is_empty():
		return false
	var out := false
	for c in e.combatants:
		if not _hero(c):
			continue
		if str(c.get_meta("left_fight", "")) == "exit":
			out = true
		elif not c.has_meta("left_fight") and not c.is_down() and not c.creature.has_flag("knocked_out"):
			return false
	return out


## True if something takes this creature's turn out of its controller's hands (Command, Fear, Turn Undead, Crown of
## Madness, Calm Emotions, Suggestion): the AI plays it as the effect demands, even for a party member.
func compelled(c: Combatant) -> bool:
	var e := enc()
	for f: String in ["command_grovel", "command_halt", "command_flee", "command_approach", "command_drop", "fear_flee", "crowned",
			"suggest_leave", "suggest_sit", "suggest_follow"]:
		if c.creature.has_flag(f):
			return true
	return e.features.fleeing_from(c) != null


## Plays the current creature's turn with the AI if it isn't player-controlled.
func run_ai_turn() -> CombatResult:
	var r := begin_ai_turn()
	if r != null:
		return r
	return finish_ai_turn(enc().ai.think(enc().current()))


## run_ai_turn in steps (FN-14): this one plays the turn up to its plan and returns null when the plan comes next
## (AiBrain.think, which only reads, so the combat view runs it on a worker thread), then finish_ai_turn.
func begin_ai_turn() -> CombatResult:
	var e := enc()
	var c := e.current()
	if c == null or (c.is_player_controlled() and not compelled(c)):
		return CombatResult.fail("Not an AI turn")
	if not c.can_act() and e.features.fleeing_from(c) == null and not c.creature.has_flag("transfixed"):
		return end_turn()
	var r := e.ai.begin_turn(c)
	return null if r == null else _after_ai_turn(c, r)


## The rest of the AI turn begin_ai_turn left at its plan: `thought` is AiBrain.think's.
func finish_ai_turn(thought: Dictionary) -> CombatResult:
	var c := enc().current()
	return _after_ai_turn(c, enc().ai.finish_turn(c, thought))


func _after_ai_turn(c: Combatant, r: CombatResult) -> CombatResult:
	var e := enc()
	return e.then(r, func() -> CombatResult:
		if e.state == Encounter.State.ACTIVE and e.current() == c:
			return end_turn()
		return CombatResult.new())


## "" if `c` may act now (it's its turn, nothing is waiting, combat is on).
func _turn_check(c: Combatant) -> String:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return "Combat is over"
	if e.pending != null:
		return "Answer the reaction prompt first"
	if e.current() != c:
		return "It isn't %s's turn" % c.name()
	return ""


func _action_check(c: Combatant) -> String:
	var why := _turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act (%s)" % [c.name(), "down" if c.creature.hp <= 0 else "Incapacitated"]
	if not c.action_available:
		return "Action already used"
	return action_start_block(c)


## "" if `c` may start an action now as far as the rules that cut a turn down allow: a Slowed creature (Slow, or the
## Coward spirit's `action_or_bonus`) takes an action or a Bonus Action, not both; a Dazed one, one of move, action or
## Bonus Action. _action_check asks it, and so does the first attack of an Attack action (Encounter.attack,
## monster_attack, begin_multiattack).
func action_start_block(c: Combatant) -> String:
	if (c.creature.has_flag("slowed") or c.creature.has_flag("action_or_bonus")) and not c.bonus_available and not c.surged:
		return "An action or a Bonus Action this turn, not both"
	return one_thing_block(c, "action")


## Dazed (Abjure Foes, a Rogue's Daze): on its turn the creature can do only one of these: move, take an action, or take
## a Bonus Action. "" if `what` ("move", "action" or "bonus") is still open to `c` now, else why not. Read off what the
## turn has used so far, so no spending site needs to know about it; more of the same thing stays open (the rest of a
## walk, the later attacks of one Attack action).
func one_thing_block(c: Combatant, what: String) -> String:
	if not c.creature.has_flag("dazed"):
		return ""
	var moved := c.moved or c.movement_left < c.turn_speed
	var acted := not c.action_available
	var bonus := not c.bonus_available
	var blocked := false
	match what:
		"move":
			blocked = acted or bonus
		"action":
			blocked = (moved or bonus) and not acted
		"bonus":
			blocked = (moved or acted) and not bonus
	return "%s is Dazed: it can only move, take an action or take a Bonus Action this turn, one of the three" % c.name() if blocked else ""


## "" if `c` could make one attack of the Attack action now (starting it if it hasn't).
func features_attack_why(c: Combatant) -> String:
	var why := _turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "Can't act"
	if c.attacks_left <= 0 and not c.action_available:
		return "Action already used"
	return ""


## Uses one attack of the Attack action (starting it if needed): Breath Weapon, Commander's Strike, War Magic.
func use_one_attack(c: Combatant) -> void:
	var e := enc()
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		spend_action(c)
		c.took_attack_action = true
		c.attacks_left = e.attacks_per_action(c) - 1
		e.echo_knight.attack_action_taken(c)


func spend_action(c: Combatant) -> void:
	c.remove_meta("attack_cantrip_used")
	if c.extra_actions > 0:
		c.extra_actions -= 1
		c.attacks_left = 0
	else:
		c.action_available = false


func _bonus_check(c: Combatant) -> String:
	var why := _turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act" % c.name()
	if not c.bonus_available:
		return "Bonus Action already used"
	if (c.creature.has_flag("slowed") or c.creature.has_flag("action_or_bonus")) and not c.action_available:
		return "An action or a Bonus Action this turn, not both"
	return one_thing_block(c, "bonus")
