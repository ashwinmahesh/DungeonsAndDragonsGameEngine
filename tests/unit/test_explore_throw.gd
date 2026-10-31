extends TestCase
## A flask thrown at a foe waiting in plain view, from the exploration menu (LocationNpcs.throw_actions_at_foe and
## throw_at_foe, LocationFights._opening_for, EncounterTurns._take_opening; docs/contracts/locations.md): the menu offers
## it within range and in sight, the fight opens as an attack opens it, and the thrower's first turn begins with the
## throw.


func _hero() -> Combatant:
	var ch := TestChars.pregen("hedda_ironvow", 3)
	ch.add_item("holy_water", 2)
	return Combatant.new(ch, &"party", Vector2i(1, 3))


func _view(hero: Combatant) -> LocationView:
	var view := LocationView.new()
	view.st = StoryState.new()
	var rows: Array[String] = []
	for z in 8:
		rows.append("....................")
	view.grid = CombatGrid.from_rows(rows)
	view.members.append(hero)
	return view


func test_the_menu_offers_a_flask_in_range() -> void:
	var hero := _hero()
	var view := _view(hero)
	var near := {"kind": "foe", "id": "test_sleeper", "name": "The Sleeper", "spec": {"cell": [5, 3]}}
	var acts := LocationNpcs.throw_actions_at_foe(view, near)
	assert_eq(acts.size(), 1, "one entry for the hero's Holy Water")
	assert_eq(str(acts[0]["id"]), "strike_throw:0:holy_water:test_sleeper")
	assert_true(bool(acts[0]["enabled"]))
	assert_true(str(acts[0]["label"]).begins_with("Throw Holy Water"))
	var far := {"kind": "foe", "id": "test_sleeper", "name": "The Sleeper", "spec": {"cell": [19, 3]}}
	var out := LocationNpcs.throw_actions_at_foe(view, far)
	assert_false(bool(out[0]["enabled"]), "90 ft away")
	assert_eq(str(out[0]["why"]), "Out of range (20 ft)")
	view.free()


func test_the_fight_takes_the_opening_and_the_thrower_starts_with_it() -> void:
	var hero := _hero()
	var view := _view(hero)
	view.opening = {"member": 0, "item": "holy_water", "cell": Vector2i(5, 3)}
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var by := e.add(hero.creature, &"party", hero.cell)
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3), 80, "undead")
	e.opening = LocationFights._opening_for(view, e)
	assert_eq(e.opening, {"by": by.id, "kind": "flask", "item": "holy_water", "target": foe.id})
	assert_eq(view.opening, {}, "the view's choice is used once")
	var before := foe.creature.hp
	TestCombat.next_d20(e, 2)
	TestCombat.start_with(e, by)
	assert_true(foe.creature.hp < before, "the thrower's first turn began with the throw")
	assert_eq(int((hero.creature as Character).entry_of("holy_water")["qty"]), 1, "one flask spent")
	assert_eq(by.attacks_left, e.attacks_per_action(by) - 1, "it took one of the thrower's attacks")
	assert_eq(e.opening, {}, "and is spent")
	view.free()


func test_an_opening_whose_target_is_gone_is_dropped() -> void:
	var hero := _hero()
	var e := TestCombat.open_field(3)
	var by := e.add(hero.creature, &"party", hero.cell)
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3), 80, "undead")
	e.opening = {"by": by.id, "kind": "flask", "item": "holy_water", "target": foe.id}
	foe.creature.dead = true
	TestCombat.start_with(e, by)
	assert_eq(int((hero.creature as Character).entry_of("holy_water")["qty"]), 2, "nothing thrown at a fallen foe")
	assert_eq(e.opening, {})
	assert_true(by.action_available, "the hero keeps the turn")
