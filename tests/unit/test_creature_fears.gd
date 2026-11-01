extends TestCase
## A creature's dread of certain others (a trait's `fears`; MonsterActions._fears): Frightened of the one it sees as its
## turn starts, and not of anyone else.


func test_it_cowers_at_a_dog() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var weasel := e.add(TestChars.dummy(20, false, {"id": "test_weasel", "name": "Test Weasel", "speed": {"walk": 30},
		"traits": [{"id": "test_dread", "name": "Test Dread", "fears": ["test_hound"], "fear_modifiers": [{"stat": "disadvantage", "on": ["save:all"]}]}]}), &"enemy", Vector2i(2, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 3)
	TestCombat.start_with(e, weasel)
	e.monster_actions.turn_start(weasel)
	assert_false(weasel.creature.has_condition(&"frightened"), "no hound in sight")
	var hound := e.add(TestChars.dummy(20, false, {"id": "test_hound", "name": "Test Hound"}), &"guest", Vector2i(6, 3))
	e.monster_actions.turn_start(weasel)
	assert_true(weasel.creature.has_condition(&"frightened"))
	assert_true(e.movement.fear_sources(weasel).has(hound), "Frightened of the hound")
	assert_false(e.movement.fear_sources(weasel).has(hero), "not of the hero")
	assert_true(weasel.creature.roll_save(e.dice, &"wis", 10).disadvantage, "and Disadvantage on saves")
