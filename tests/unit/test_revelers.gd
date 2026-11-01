extends TestCase
## Bystanders and brawls (monster entries' `nonlethal` and `hostile_if_harmed`, an encounter's `nonlethal`): a charmed
## townsperson stays out of it until harmed, and is knocked out rather than killed; in a brawl a hero is too.


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var townie := e.add(TestChars.dummy(10, false, {"id": "test_reveler", "name": "Test Reveler"}), &"neutral", Vector2i(3, 3))
	townie.set_meta(Encounter.NONLETHAL, true)
	townie.set_meta(Encounter.PROVOKED_BY_HARM, true)
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3), 50)
	TestCombat.start_with(e, hero)
	return [e, hero, townie, foe]


func test_harm_turns_it_but_never_kills_it() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var townie := got[2] as Combatant
	assert_false(hero.hostile_to(townie) and townie.side == &"enemy", "neutral at first")
	e.deal_damage(hero, townie, [{"amount": 3, "type": "bludgeoning"}], false, "test")
	assert_eq(townie.side, &"enemy", "it turns on the party")
	e.deal_damage(hero, townie, [{"amount": 50, "type": "slashing"}], false, "test")
	assert_false(townie.creature.dead, "never killed")
	assert_true(townie.creature.has_flag("knocked_out"), "knocked out")


func test_in_a_brawl_a_hero_is_knocked_out_too() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[3] as Combatant
	e.nonlethal = true
	e.deal_damage(foe, hero, [{"amount": 500, "type": "bludgeoning"}], false, "test")
	assert_false(hero.creature.dead)
	assert_true(hero.creature.has_flag("knocked_out"))
