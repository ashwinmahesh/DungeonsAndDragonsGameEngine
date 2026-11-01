extends TestCase
## A drink that changes the drinker's shape (`drink_shape`; ItemSpecials._drink_shape): the form's own Temporary Hit
## Points, no Concentration, and back to themselves when the time is up.

var _fx := FixtureContent.new()


func before_each() -> void:
	_fx.add("monsters", {"id": "test_frog", "name": "Test Frog", "type": "beast", "size": "tiny", "cr": 0, "ac": 11,
		"hp": {"average": 1, "dice": "1d4-1"}, "speed": {"walk": 20, "swim": 20},
		"abilities": {"str": 1, "dex": 13, "con": 8, "int": 1, "wis": 8, "cha": 3}, "actions": []})


func after_each() -> void:
	_fx.restore()


func test_a_frog_for_a_minute() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, hero)
	var p := {"item_id": "test_tonic", "data": {"name": "Test Tonic"},
		"power": {"id": "drink", "custom": "drink_shape", "cost": "bonus", "params": {"form": "test_frog", "minutes": 1}}}
	assert_true(e.items.specials.use(hero, p, [], Vector2.INF, Vector2.ZERO, 0, {}).ok)
	assert_true(e.shapes.is_shaped(hero), "a frog now")
	assert_true(hero.name().contains("Test Frog"))
	assert_false(hero.bonus_available, "a Bonus Action")
	assert_true(hero.creature.concentration == null, "no Concentration")
	for i in 30:
		e.end_turn()
		if not e.shapes.is_shaped(hero):
			break
	assert_false(e.shapes.is_shaped(hero), "itself again once the minute is up")
