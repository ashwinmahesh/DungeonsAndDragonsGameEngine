extends TestCase
## Things a monster holds that heroes can strike (HeldObjects, a trait's `held_object`), and iron that binds a creature
## to one of moving, its action or its Bonus Action (`one_of_move_action_bonus`).

const HORN := {"name": "its horn", "ac": 5, "hp": 10, "needs": ["call_the_rot"], "owner_share": 0.5, "owner_type": "force"}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var weaver := e.add(TestChars.dummy(60, false, {"name": "Test Weaver",
		"traits": [{"id": "horn", "name": "Horn", "held_object": HORN}],
		"actions": [{"id": "call_the_rot", "name": "Call the Rot", "kind": "melee", "attack": {"bonus": 5, "reach": 5},
			"damage": [{"dice": "1d4", "type": "necrotic"}]}]}), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, weaver]


func test_a_hero_strikes_the_horn_and_breaks_what_it_was_for() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var weaver := got[2] as Combatant
	var horn := e.objects.get_object("held:%s:horn" % weaver.id)
	assert_true(horn != null and horn.held_target, "the horn is in the fight, held")
	var entries := HeldObjects.entries(e, hero)
	assert_eq(entries.size(), 1, "the hero can strike it")
	assert_eq(str(entries[0]["why"]), "", "within reach")
	assert_true(str(entries[0]["id"]).begins_with("heldhit:%s|" % horn.id))
	assert_true(ActionCatalog.new(e).perform(hero, ActionCatalog.new(e).find(hero, str(entries[0]["id"]))).ok, "struck from the Common tab")
	var hp := weaver.creature.hp
	e.objects.damage(horn, [{"amount": 6, "type": "slashing"}], hero, "test")
	assert_eq(weaver.creature.hp, hp - 3, "half of it reaches the holder as Force")
	e.objects.damage(horn, [{"amount": 6, "type": "slashing"}], hero, "test")
	assert_true(horn.destroyed)
	var call := MonsterActions.data_of(weaver)["actions"][0] as Dictionary
	assert_eq(e.monster_actions.why_not(weaver, call), "%s is broken" % horn.title(), "no horn, no Call the Rot")


func test_iron_binds_a_creature_to_one_thing_a_turn() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var weaver := got[2] as Combatant
	var fx := Effect.new("Iron", &"item", "iron").with_modifier("flag", {"value": "one_of_move_action_bonus"})
	weaver.creature.add_effect(fx)
	while e.current() != weaver:
		e.end_turn()
	e.turns._turn_start_flags(weaver)
	assert_false(weaver.bonus_available)
	assert_eq(weaver.movement_left, 0, "a foe beside it: its action only")
	assert_true(weaver.action_available)
