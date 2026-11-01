extends TestCase
## A drink that casts a spell through the drinker (`drink_cast`; ItemSpecials._drink_cast): Vampiric Touch at 6th level,
## no slot and no Concentration, and the touch again as a Bonus Action.


func test_a_vampiric_drink() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, hero)
	var p := {"item_id": "test_draught", "data": {"name": "Test Draught"},
		"power": {"id": "drink", "custom": "drink_cast", "cost": "bonus", "targeting": "creature", "range": 5,
			"params": {"spell": "vampiric_touch", "level": 6, "minutes": 1, "sustain_cost": "bonus_action"}}}
	TestCombat.next_d20(e, 19)
	assert_true(e.items.specials.use(hero, p, [bag], Vector2.INF, Vector2.ZERO, 0, {}).ok)
	assert_true(hero.creature.concentration == null, "no Concentration")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Vampiric Touch")))
	var again := e.spells.sustained.filter(func(a: Dictionary) -> bool: return str(a["spell_id"]) == "vampiric_touch")
	assert_eq(again.size(), 1, "the touch can come again")
	assert_eq(str((again[0] as Dictionary)["cost"]), "bonus_action", "as a Bonus Action")
	assert_eq(int((again[0] as Dictionary)["slot"]), 6, "at 6th level")
