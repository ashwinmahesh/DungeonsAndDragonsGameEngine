extends TestCase
## A mark wiped on a weapon (`weapon_mark`; ItemSpecials.mark_effect): a creature whose trait names it takes the weapon's
## damage twice over, and the hit uses the mark up.


func test_salt_on_the_blade() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3), 5)
	var beast := e.add(TestChars.dummy(300, false, {"id": "test_beast", "name": "Test Beast", "ac": 1,
		"traits": [{"id": "test_salt", "name": "Test Salt", "vulnerable_to_mark": "salt"}]}), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, hero)
	var p := {"item_id": "test_salt", "data": {"name": "Test Salt"}, "power": {"params": {"mark": "salt", "minutes": 1}}}
	hero.creature.add_effect(ItemSpecials.mark_effect(p))
	assert_eq(e.items.specials.weapon_mark(hero), "salt")
	var opt := str((e.weapons.attack_options(hero)[0] as Dictionary)["id"])
	for i in 6:
		TestCombat.next_d20(e, 15)
		hero.attacks_left = 1
		e.attack(hero, beast, opt)
		if e.items.specials.weapon_mark(hero) == "":
			break
	assert_eq(e.items.specials.weapon_mark(hero), "", "the hit used the salt up")
	assert_true(e.log.entries.any(func(en: Dictionary) -> bool: return str(en.get("details", [])).contains("Vulnerable to the salt")),
		"double damage, said in the hit's breakdown")
