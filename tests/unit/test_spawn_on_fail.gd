extends TestCase
## A round event's save that tears a creature out of whoever fails it (`spawn_on_fail`), up to its `max`.


func test_a_creature_tears_out_of_each_hero_who_fails() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	TestCombat.hero(e, "thistle", Vector2i(2, 5), 5)
	TestCombat.hero(e, "silvain_aster", Vector2i(2, 1), 5)
	TestCombat.punching_bag(e, Vector2i(10, 6), 300)
	e.legendary.set_round_events([{"id": "test_sprout", "name": "Death from Within", "affects": "party",
		"save": {"ability": "con", "dc": 40}, "damage": {"dice": "1d4", "type": "necrotic"},
		"spawn_on_fail": {"monster": "zombie", "max": 2, "name": "Test Sprout"}, "at": 20, "times": 1}])
	TestCombat.start_with(e, a)
	for i in 8:
		if e.combatants.any(func(c: Combatant) -> bool: return c.name() == "Test Sprout"):
			break
		e.end_turn()
	var sprouts := e.combatants.filter(func(c: Combatant) -> bool: return c.name() == "Test Sprout")
	assert_eq(sprouts.size(), 2, "three failed (DC 40), two allowed")
	for s: Combatant in sprouts:
		assert_eq(s.side, &"enemy")
		assert_true(e.order.has(s), "in the turn order")
