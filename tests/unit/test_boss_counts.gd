extends TestCase
## Boss numbers that count the fight (Legendary.counted; a phase's `hp`/`heal`, a stat block's `damage_threshold`):
## "alive:<stat block>" is how many of that block are still up.


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var boss := TestChars.dummy(200, false, {"id": "test_rot_lord", "name": "Test Rot Lord", "damage_threshold": "5 * alive:test_minion"})
	var b := e.add(boss, &"enemy", Vector2i(8, 3))
	var minions: Array[Combatant] = []
	for i in 2:
		minions.append(e.add(TestChars.dummy(10, false, {"id": "test_minion", "name": "Test Minion %d" % i}), &"enemy", Vector2i(9, 1 + i * 4)))
	TestCombat.start_with(e, hero)
	return [e, hero, b, minions]


func test_counting_the_living() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	assert_eq(e.legendary.alive_of("test_minion"), 2)
	assert_eq(e.legendary.counted("40 + 10 * alive:test_minion"), 60)
	assert_eq(e.legendary.counted(7), 7)
	assert_eq(e.legendary.counted("nonsense +"), 0, "unreadable is 0")


func test_a_threshold_that_falls_as_its_minions_fall() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var boss := got[2] as Combatant
	var minions := got[3] as Array[Combatant]
	var hp := boss.creature.hp
	e.deal_damage(hero, boss, [{"amount": 9, "type": "slashing"}], false, "test")
	assert_eq(boss.creature.hp, hp, "9 is under 5 x 2 living minions")
	e.deal_damage(hero, minions[0], [{"amount": 50, "type": "force"}], false, "test")
	e.deal_damage(hero, boss, [{"amount": 9, "type": "slashing"}], false, "test")
	assert_eq(boss.creature.hp, hp - 9, "one minion down: 9 beats 5")


func test_a_second_life_healed_by_the_living() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var boss := got[2] as Combatant
	(boss.creature as Monster).data["phases"] = [{"id": "test_again", "when": {"at_zero": true}, "heal": "10 * alive:test_minion"}]
	boss.creature.hp = 1
	e.legendary.phases.enter(boss, "test_again")
	assert_eq(boss.creature.hp, 21, "1 + 10 x 2")


func test_a_second_life_that_takes_its_minions_and_rolls_for_each() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var boss := got[2] as Combatant
	var minions := got[3] as Array[Combatant]
	(boss.creature as Monster).data["phases"] = [{"id": "test_harvest", "when": {"at_zero": true}, "heal": "(alive:test_minion)d12",
		"destroys": ["test_minion"]}]
	boss.creature.hp = 1
	e.legendary.phases.enter(boss, "test_harvest")
	assert_true(boss.creature.hp >= 3 and boss.creature.hp <= 25, "1 + 2d12 (%d)" % boss.creature.hp)
	assert_true(minions.all(func(m: Combatant) -> bool: return m.creature.dead), "its minions are taken")
	assert_eq(e.legendary.alive_of("test_minion"), 0)
