extends TestCase
## A boss phase that moves the fight (a phase's `move`; BossPhases, LocationFights.continue_moved; vault "Design - Boss
## phase that moves the fight"): the fight ends here as "moved", saying where it goes, with everyone as they are.


func test_the_phase_ends_the_fight_as_moved() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var boss := e.add(TestChars.dummy(100, false, {"id": "test_abbot", "name": "Test Abbot", "phases": [
		{"id": "test_geyser", "when": {"bloodied": true}, "move": {"location": "test_nave", "spawn": "test_door", "encounter": "test_nave_fight"}}]}),
		&"enemy", Vector2i(6, 3))
	TestCombat.start_with(e, hero)
	e.deal_damage(hero, boss, [{"amount": 60, "type": "force"}], false, "test")
	assert_eq(e.state, Encounter.State.OVER)
	assert_eq(e.outcome, "moved")
	assert_eq(str(e.legendary.moving["location"]), "test_nave")
	var ev := e.events.filter(func(x: Dictionary) -> bool: return str(x["type"]) == "fight_moves")
	assert_eq(ev.size(), 1)
	assert_eq(str((ev[0] as Dictionary)["encounter"]), "test_nave_fight")
	assert_eq(boss.creature.hp, 40, "everyone as they are")
	var snap := EncounterSnapshot.capture(e)
	assert_eq((snap["combatants"] as Array).size(), 2, "the snapshot the place carries")
