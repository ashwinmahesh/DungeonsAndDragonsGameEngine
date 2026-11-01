extends TestCase
## Swimming in fights (a map's `swim`; CombatGrid.make_swimmable): deep water costs double without a Swim Speed,
## normal with one, a water-only creature stays in it, and a swimmer's turn in the water runs at its Swim Speed.


func _fight(swim: bool) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	for z in e.grid.depth:
		for x in range(5, 9):
			e.grid.set_flag(Vector2i(x, z), CombatGrid.VOID | CombatGrid.WATER, true)
	if swim:
		e.grid.make_swimmable()
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	var fish := e.add(TestChars.dummy(50, false, {"id": "test_eel", "name": "Test Eel", "speed": {"walk": 0, "swim": 40}}), &"enemy", Vector2i(7, 6))
	TestCombat.start_with(e, hero)
	return [e, hero, fish]


func test_without_the_key_water_is_a_wall() -> void:
	var got := _fight(false)
	var e := got[0] as Encounter
	assert_false(e.reachable_for(got[1] as Combatant, 30).has(Vector2i(5, 3)))


func test_a_hero_swims_at_double_cost() -> void:
	var got := _fight(true)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var reach := e.reachable_for(hero, 30)
	assert_eq(int((reach[Vector2i(5, 3)] as Dictionary)["cost"]), 10, "5 ft of water: 10 ft of movement")
	assert_true(e.move(hero, Vector2i(6, 3)).ok, "into the water")
	assert_eq(hero.cell, Vector2i(6, 3))


func test_a_water_only_creature_stays_in() -> void:
	var got := _fight(true)
	var e := got[0] as Encounter
	var fish := got[2] as Combatant
	e.turn_index = e.order.find(fish)
	e._begin_turn()
	assert_eq(fish.movement_left, 40, "its Swim Speed in the water")
	var reach := e.reachable_for(fish)
	assert_true(reach.has(Vector2i(8, 3)))
	assert_false(reach.has(Vector2i(4, 6)), "not onto land")
