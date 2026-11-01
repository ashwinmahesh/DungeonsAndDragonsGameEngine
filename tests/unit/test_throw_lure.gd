extends TestCase
## A lure thrown to a square (`throw_lure`; ItemSpecials._throw_lure): the creatures it names nearby go for it and are
## busy over it, and others pay it no mind.


func test_hounds_fight_over_the_scraps() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3), 5)
	var hound := e.add(TestChars.dummy(30, false, {"id": "test_hound", "name": "Test Hound"}), &"enemy", Vector2i(3, 3))
	var other := e.add(TestChars.dummy(30, false, {"id": "test_ghoul", "name": "Test Ghoul"}), &"enemy", Vector2i(3, 5))
	TestCombat.start_with(e, hero)
	var p := {"item_id": "test_treats", "data": {"name": "Test Treats"},
		"power": {"id": "throw", "custom": "throw_lure", "cost": "action", "params": {"range": 30, "radius": 60, "lures": ["test_hound"], "rounds": "3"}}}
	assert_true(e.items.specials.use(hero, p, [], Vector2(7.5, 3.5), Vector2.ZERO, 0, {}).ok)
	assert_true(hound.creature.has_condition(&"incapacitated"), "busy over the treats")
	assert_true(e.grid.distance_ft(hound.cell, 1, Vector2i(7, 3), 1) <= 5, "by where they landed")
	assert_false(other.creature.has_condition(&"incapacitated"), "the ghoul doesn't care")
	e.deal_damage(hero, hound, [{"amount": 1, "type": "piercing"}], false, "test")
	assert_false(hound.creature.has_condition(&"incapacitated"), "a blow brings it back to the fight")
