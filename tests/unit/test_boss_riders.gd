extends TestCase
## Boss traits that reach the heroes or turn on the boss (MonsterActions): an aura that hurts and spreads an affliction
## (the `afflict` rider), and a thing the boss can't bear to see (`dreads_item`).

const ID := "test_rot"


func before_each() -> void:
	Compendium.shared().table("afflictions")[ID] = {"id": ID, "name": "Test Rot", "modifiers": []}


func after_each() -> void:
	Compendium.shared().table("afflictions").erase(ID)


func test_an_aura_that_hurts_and_spreads_a_rot() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 3)
	var boss := e.add(TestChars.dummy(100, false, {"name": "Test Spore Lord", "traits": [{"id": "test_spores", "name": "Test Spores",
		"aura": {"radius": 10, "trigger": "start_turn", "affects": "enemies", "damage": {"dice": "1d10", "type": "necrotic"},
		"riders": [{"do": "afflict", "id": ID, "levels": 1, "save": {"ability": "con", "dc": 40}}]}}]}), &"enemy", Vector2i(5, 3))
	TestCombat.start_with(e, boss)
	var hp := hero.creature.hp
	for i in 4:
		if e.current() == hero:
			break
		e.end_turn()
	assert_eq(e.current(), hero)
	assert_true(hero.creature.hp < hp, "the spores burn")
	assert_eq(Afflictions.level_of(hero.creature, ID), 1, "DC 40: the rot takes")


func test_a_thing_it_cant_bear_to_see() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 3)
	var boss := e.add(TestChars.dummy(100, false, {"name": "Test Mourner", "traits": [{"id": "test_longing", "name": "Test Longing",
		"dreads_item": {"items": ["test_locket"], "damage": [{"amount": 10, "type": "psychic"}],
		"riders": [{"do": "condition", "condition": "", "until": "target_turn_start", "modifiers": [{"stat": "disadvantage", "on": "attack"}]}]}}]}),
		&"enemy", Vector2i(7, 3))
	TestCombat.start_with(e, hero)
	var hp := boss.creature.hp
	e.end_turn()
	assert_eq(boss.creature.hp, hp, "nothing seen, nothing felt")
	Compendium.shared().table("items")["test_locket"] = {"id": "test_locket", "name": "Test Locket", "category": "gear"}
	(hero.creature as Character).add_item("test_locket", 1)
	for i in 4:
		e.end_turn()
		if e.current() == boss:
			break
	assert_eq(boss.creature.hp, hp - 10, "it sees the locket: 10 Psychic")
	assert_true(boss.creature.effects.any(func(fx: Effect) -> bool: return fx.name == "Test Longing"), "and is shaken")
	Compendium.shared().table("items").erase("test_locket")
