extends TestCase
## What potions need of the engine: a fickle die on every D20 Test (a 1 is Disadvantage, else it's added), a coating
## whose extra damage the next hit uses up, and a drink that adds modifiers besides its exploring spell.


func test_a_fickle_die() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 3)
	ch.add_effect(Effect.new("Test Rum", &"item", "test_rum").with_modifier("fickle_die", {"dice": "1d4"}))
	var dice := DiceRoller.new(7)
	var saw_dis := false
	var saw_add := false
	for i in 40:
		var t := ch.roll_save(dice, &"con", 10)
		if t.disadvantage_sources.has("Test Rum"):
			saw_dis = true
		elif t.describe().contains("Test Rum"):
			saw_add = true
	assert_true(saw_dis, "a 1 gives Disadvantage")
	assert_true(saw_add, "otherwise the die is added")


func test_a_coating_lasts_one_hit() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, hero)
	var p := {"item_id": "test_sap", "data": {"name": "Test Sap"}, "power": {"params": {"dice": "3d8", "types": ["acid", "cold"], "minutes": 1}}}
	hero.creature.add_effect(ItemSpecials.coating(p, "cold"))
	var opt := str((e.weapons.attack_options(hero)[0] as Dictionary)["id"])
	for i in 6:
		TestCombat.next_d20(e, 19)
		hero.attacks_left = 1
		e.attack(hero, bag, opt)
		if not hero.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "test_sap"):
			break
	assert_false(hero.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "test_sap"), "a hit used it up")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.to_lower().contains("cold")), "cold damage on that hit")
