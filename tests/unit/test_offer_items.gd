extends TestCase
## Monster secrets a hero acts on (a trait's `offers`; TraitOffers): one that needs a carried item and uses it up, one
## the holder must save against at a set DC, and one that simply lands.


func _fight(offer: Dictionary) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var beast := e.add(TestChars.dummy(80, false, {"id": "test_beast", "name": "Test Beast", "speed": {"walk": 30},
		"traits": [{"id": "test_secret", "name": "Test Secret", "offers": offer}]}), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, beast]


func test_a_bottle_splashed_and_used_up() -> void:
	var got := _fight({"label": "Splash", "needs_item": ["test_rum"], "consumes": true, "auto": true,
		"damage": [{"amount": 9, "type": "force"}], "on_success": [{"do": "condition", "condition": "restrained", "until": "source_turn_start"}]})
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var beast := got[2] as Combatant
	assert_true(e.trait_offers.why_not(hero, beast, {"needs_item": ["test_rum"]}).begins_with("Needs"), "nothing to splash yet")
	(hero.creature as Character).add_item("test_rum", 1)
	var hp := beast.creature.hp
	assert_true(e.trait_offers.take(hero, beast, "test_secret").ok)
	assert_eq(beast.creature.hp, hp - 9)
	assert_false((hero.creature as Character).carries("test_rum"), "the bottle is gone")


func test_flattery_it_must_save_against() -> void:
	var got := _fight({"label": "Flatter", "influence": true, "save": {"ability": "cha", "dc": 40},
		"on_success": [{"do": "condition", "condition": "incapacitated", "until": "target_turn_end"}]})
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var beast := got[2] as Combatant
	assert_true(e.trait_offers.take(hero, beast, "test_secret").ok)
	assert_true(beast.creature.has_condition(&"incapacitated"), "DC 40: it falls for it")
