extends TestCase
## A drink that wraps the drinker in a spell's area (`drink_zone`; ItemSpecials._drink_zone): Silence round them that
## goes where they go, with no Concentration.


func test_a_silence_that_walks_along() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	TestCombat.punching_bag(e, Vector2i(11, 7), 300)
	TestCombat.start_with(e, hero)
	var p := {"item_id": "test_hush", "data": {"name": "Test Hush"},
		"power": {"id": "drink", "custom": "drink_zone", "cost": "bonus", "params": {"spell": "silence", "minutes": 10}}}
	assert_true(e.items.specials.use(hero, p, [], Vector2.INF, Vector2.ZERO, 0, {}).ok)
	var zone: FieldObject = null
	for o in e.spells.zones.objects:
		if o.spell_id == "silence":
			zone = o
	assert_true(zone != null, "the silence is there")
	assert_true(zone.follows_caster)
	assert_false(zone.expired(), "still up: rounds %d" % zone.rounds_left)
	assert_true(hero.creature.concentration == null, "no Concentration")
	var mr := e.move(hero, Vector2i(6, 3))
	assert_true(mr.ok, mr.reason)
	assert_eq(hero.cell, Vector2i(6, 3))
	assert_true(Vector2i(10, 3) in zone.cells, "20 ft on from where they stand now: it moved with them")
	assert_false(Vector2i(0, 7) in zone.cells, "and left the old spot")
	assert_true(e.spells.zones.silenced(hero.cell), "the drinker is in the silence too")
