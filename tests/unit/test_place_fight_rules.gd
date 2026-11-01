extends TestCase
## A place's own rules in its fights (a location's `fight_rules`, Encounter.place_rules): modifiers on every creature
## there, joiners too, gone with the fight; `crit_widen` and `fumble_range` on attack rolls.


func _jinxed() -> Encounter:
	var e := TestCombat.open_field()
	e.place_rules = {"name": "Jinxed deck", "modifiers": [
		{"stat": "crit_widen", "value": 1}, {"stat": "fumble_range", "value": 2},
		{"stat": "disadvantage", "on": ["concentration"]}]}
	return e


func _attack(e: Encounter, c: Combatant, natural: int, target: int) -> D20Test:
	TestCombat.next_d20(e, natural)
	return c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, Breakdown.new("Attack"), target, [] as Array[String])


func test_every_creature_in_the_fight_gets_the_rules_and_loses_them_after() -> void:
	var e := _jinxed()
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var w := TestCombat.foe(e, "wolf", Vector2i(8, 1))
	for c in [a, w]:
		var fx := (c as Combatant).creature.effects.filter(func(x: Effect) -> bool: return x.stack_key == Encounter.PLACE_RULES)
		assert_eq(fx.size(), 1, "one place-rules effect each")
		assert_eq((fx[0] as Effect).name, "Jinxed deck")
	TestCombat.start_with(e, a)
	var late := TestCombat.foe(e, "zombie", Vector2i(8, 5))
	assert_true(late.creature.effects.any(func(x: Effect) -> bool: return x.stack_key == Encounter.PLACE_RULES), "a creature that joins mid-fight")
	e.apply_place_rules(a)
	assert_eq(a.creature.effects.filter(func(x: Effect) -> bool: return x.stack_key == Encounter.PLACE_RULES).size(), 1, "never twice")
	EncounterSetup.clear_fight_effects(a.creature)
	assert_false(a.creature.effects.any(func(x: Effect) -> bool: return x.stack_key == Encounter.PLACE_RULES), "gone with the fight")


func test_attacks_crit_a_step_lower_and_miss_on_a_two() -> void:
	var e := _jinxed()
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	TestCombat.foe(e, "wolf", Vector2i(8, 1))
	var t := _attack(e, a, 19, 40)
	assert_true(t.critical and t.success, "19 crits")
	t = _attack(e, a, 2, 1)
	assert_false(t.success, "2 misses whatever the total")
	assert_true(t.would_succeed_with(3))
	assert_false(t.would_succeed_with(2))
	TestCombat.next_d20(e, 2)
	var s := a.creature.roll_d20(e.dice, D20Test.Kind.SAVING_THROW, Breakdown.new("Save"), 1, [] as Array[String])
	assert_true(s.success, "saves keep their own rules")
	var c := a.creature.roll_save(e.dice, &"con", 10, [], [], "Concentration", ["concentration"])
	assert_true(c.disadvantage, "the music: Disadvantage to keep Concentration")


func test_crit_widen_stacks_with_a_lower_crit_range() -> void:
	var e := _jinxed()
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	TestCombat.next_d20(e, 18)
	var t := a.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, Breakdown.new("Attack"), 40, [] as Array[String],
		[], [], "", 19)
	assert_true(t.critical, "Improved Critical's 19 and the board's step: 18")


func test_without_place_rules_nothing_changes() -> void:
	var e := TestCombat.open_field()
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	assert_false(a.creature.effects.any(func(x: Effect) -> bool: return x.stack_key == Encounter.PLACE_RULES))
	assert_false(_attack(e, a, 19, 40).critical)
	assert_true(_attack(e, a, 2, 1).success)
