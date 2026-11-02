extends TestCase
## Holding your breath (HoldBreath): a creature that senses breath can't see a hero holding it; damage may break it,
## and it runs out after the hero's own turns.


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var hearse := e.add(TestChars.dummy(80, false, {"name": "Test Hearse",
		"traits": [{"id": "breath_sense", "name": "Breath Sense", "senses_breath": true}]}), &"enemy", Vector2i(6, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, hearse]


func test_a_held_breath_hides_the_hero_from_what_senses_breath() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var hearse := got[2] as Combatant
	var cat := ActionCatalog.new(e)
	var act := cat.find(hero, "hold_breath")
	assert_false(act.is_empty(), "offered while something senses breath")
	assert_true(e.can_see(hearse, hero))
	assert_true(cat.perform(hero, act).ok)
	assert_false(e.can_see(hearse, hero), "it can't find a hero holding their breath")
	assert_eq(str(cat.find(hero, "hold_breath")["label"]), "Breathe again")


func test_it_runs_out_after_the_heros_turns() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	HoldBreath.toggle(e, hero)
	var turns := maxi(1, 1 + hero.creature.ability_mod(&"con"))
	for i in turns:
		while e.current() != hero:
			e.end_turn()
		e.end_turn()
	assert_false(HoldBreath.holding(hero), "%d of its own turns, then a breath" % turns)


func test_without_a_breath_sensing_creature_it_isnt_offered() -> void:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	TestCombat.punching_bag(e, Vector2i(8, 3), 100)
	TestCombat.start_with(e, hero)
	assert_true(ActionCatalog.new(e).find(hero, "hold_breath").is_empty())
