extends TestCase
## The flag `reactive`: a Reaction on every creature's turn.


func test_its_reaction_comes_back_each_turn() -> void:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var ally := TestCombat.hero(e, "thistle", Vector2i(2, 5), 5)
	var boss := e.add(TestChars.dummy(100, false, {"name": "Test Effigy",
		"traits": [{"id": "reactive", "name": "Reactive", "modifiers": [{"stat": "flag", "value": "reactive"}]}]}), &"enemy", Vector2i(8, 3))
	var plain := TestCombat.punching_bag(e, Vector2i(9, 6), 100)
	TestCombat.start_with(e, hero)
	for i in 6:
		boss.reaction_available = false
		plain.reaction_available = false
		e.end_turn()
		var now := e.current()
		if now != boss:
			assert_true(boss.reaction_available, "back on %s's turn" % now.name())
		if now != plain:
			assert_false(plain.reaction_available, "a creature without it waits for its own turn")
