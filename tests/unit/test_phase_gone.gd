extends TestCase
## A stat block's own `catch` and the phase trigger `gone` (combat/boss_phases.gd, EncounterGrapples; docs/contracts/
## combat.md): summoned creatures of a catchable block can be caught, and a phase begins once so many of a block are
## dead, caught or gone, or on a flag, whichever comes first.

var content := FixtureContent.new()


func before_each() -> void:
	content.add("monsters", {"id": "test_crow", "name": "Test Crow", "size": "tiny", "type": "beast", "ac": 10,
		"hp": {"average": 2, "dice": "1d4"}, "speed": {"walk": 10, "fly": 50},
		"abilities": {"str": 2, "dex": 4, "con": 8, "int": 2, "wis": 10, "cha": 4}, "cr": 0, "proficiency_bonus": 2,
		"actions": [], "catch": {"flag": "test_crow_caught"}})


func after_each() -> void:
	content.restore()


static func _boss() -> Dictionary:
	return {"id": "test_feaster", "name": "Test Feaster", "size": "large", "type": "fiend", "ac": 15,
		"hp": {"average": 100, "dice": "10d10+45"}, "speed": {"walk": 30},
		"abilities": {"str": 18, "dex": 12, "con": 16, "int": 10, "wis": 10, "cha": 10}, "cr": 4, "proficiency_bonus": 2,
		"actions": [], "ai_profile": "brute", "legendary_resistance": 2,
		"phases": [{"id": "feast_over", "name": "The Feast Is Over", "summary": "Its crows are gone.",
			"when": {"gone": {"monster": "test_crow", "at_least": 3}, "flag": "test_crows_eaten"}, "legendary_resistance": "refill"}]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var boss := e.add(Monster.from_data(_boss()), &"enemy", Vector2i(8, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	TestCombat.start_with(e, hero)
	assert_eq(e.legendary.summon_near(boss, "test_crow", 4, Vector2i(5, 3)), 4, "four crows come")
	var crows: Array[Combatant] = []
	for c in e.combatants:
		if str(MonsterActions.data_of(c).get("id", "")) == "test_crow":
			crows.append(c)
	return [e, boss, hero, crows]


func test_a_summoned_creature_of_a_catchable_block_can_be_caught() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[2] as Combatant
	var crow := (got[3] as Array[Combatant])[0]
	crow.cell = Vector2i(5, 3)
	var act := ActionCatalog.new(e).find(hero, "catch:" + crow.id)
	assert_false(act.is_empty(), "a summoned crow is on the hotbar to catch")
	TestCombat.next_d20(e, 2)
	assert_true(e.grappling.catch_creature(hero, crow).ok)
	assert_eq(str(crow.get_meta("left_fight", "")), "caught")
	assert_true(bool(e.legendary.story_flags.get("test_crow_caught", false)), "the block's flag")
	var boss := got[1] as Combatant
	assert_true(ActionCatalog.new(e).find(hero, "catch:" + boss.id).is_empty(), "a block without catch is fought, not caught")


func test_the_phase_begins_once_enough_are_gone_by_any_means() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var boss := got[1] as Combatant
	var hero := got[2] as Combatant
	var crows := got[3] as Array[Combatant]
	boss.set_meta("legendary_resistance_used", 2)
	e.deal_damage(hero, crows[0], [{"amount": 10, "type": "slashing"}], false, "test")
	assert_false(e.legendary.phases.is_active(boss, "feast_over"), "one gone")
	crows[1].cell = Vector2i(5, 3)
	TestCombat.next_d20(e, 2)
	e.grappling.catch_creature(hero, crows[1])
	assert_false(e.legendary.phases.is_active(boss, "feast_over"), "two gone: a kill and a catch")
	e.movement.leave_grid(crows[2], "fell")
	assert_true(e.legendary.phases.is_active(boss, "feast_over"), "the third, off the board, begins it")
	assert_eq(int(boss.get_meta("legendary_resistance_used", 0)), 0, "and what it does happens")
	e.deal_damage(hero, crows[3], [{"amount": 10, "type": "slashing"}], false, "test")
	assert_eq(e.legendary.phases.active(boss).size(), 1, "once")


func test_the_flag_alternative_begins_it_too() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var boss := got[1] as Combatant
	e.legendary.story_flags["test_crows_eaten"] = true
	assert_false(e.legendary.phases.is_active(boss, "feast_over"), "a flag waits for the boss's turn")
	e.legendary.phases.turn_start(boss)
	assert_true(e.legendary.phases.is_active(boss, "feast_over"), "whichever trigger comes first")
