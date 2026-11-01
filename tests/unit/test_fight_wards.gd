extends TestCase
## A creature the party must protect (a location monster entry's `ward`; EncounterTurns.WARD, LocationFights;
## docs/contracts/combat.md): if it falls the fight is lost, and with `ends_when.wards_out` getting it out by an open
## exit wins it.

const EXIT := Vector2i(0, 3)


func _fight(ends: Dictionary) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	e.ends_when = ends
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(10, 6), 200)
	var spirit := TestChars.dummy(20, false, {"name": "Test Spirit", "speed": {"walk": 20}})
	spirit.set_meta(EncounterTurns.WARD, true)
	var ward := e.add(spirit, &"guest", Vector2i(2, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, foe, ward]


func test_the_fight_is_lost_when_the_ward_falls() -> void:
	var got := _fight({})
	var e := got[0] as Encounter
	var foe := got[2] as Combatant
	var ward := got[3] as Combatant
	e.deal_damage(foe, ward, [{"amount": 50, "type": "force"}], false, "test")
	e._check_over()
	assert_eq(e.state, Encounter.State.OVER)
	assert_eq(e.outcome, "defeat", "though the hero is still up")


func test_a_lost_ward_can_end_the_fight_with_no_winner() -> void:
	var got := _fight({"ward_lost": "ended"})
	var e := got[0] as Encounter
	e.deal_damage(got[2] as Combatant, got[3] as Combatant, [{"amount": 50, "type": "force"}], false, "test")
	e._check_over()
	assert_eq(e.outcome, "ended")


func test_getting_the_ward_out_wins_and_the_heroes_stay() -> void:
	var got := _fight({"ward_exits": [[EXIT.x, EXIT.y]]})
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var ward := got[3] as Combatant
	hero.cell = EXIT
	e.end_turn()
	assert_false(hero.has_meta("left_fight"), "a hero on a ward exit doesn't step out")
	for i in 6:
		if e.current() == ward:
			break
		e.end_turn()
	assert_eq(e.current(), ward, "the ward's turn")
	ward.cell = EXIT
	e.end_turn()
	assert_eq(str(ward.get_meta("left_fight", "")), "exit", "the ward gets out")
	assert_eq(e.state, Encounter.State.OVER)
	assert_eq(e.outcome, "victory", "and the fight is won")


func test_beating_the_foes_still_wins_with_the_ward_alive() -> void:
	var got := _fight({"ward_exits": [[EXIT.x, EXIT.y]]})
	var e := got[0] as Encounter
	e.deal_damage(got[1] as Combatant, got[2] as Combatant, [{"amount": 999, "type": "force"}], false, "test")
	e._check_over()
	assert_eq(e.outcome, "victory")


func test_the_place_marks_the_ward_and_its_exits() -> void:
	var view := LocationView.new()
	view.st = StoryState.new()
	view.loc = {"id": "test_maze", "region": "", "exits": [{"cell": [0, 3], "to": "test_next"}]}
	var made := LocationFights.monsters_for(view, {"id": "test_soul", "monsters": [{"monster": "wolf", "cell": [5, 5]},
		{"monster": "wolf", "cell": [1, 1], "side": "guest", "name": "The Soul", "ward": true}]})
	assert_false((made[0]["creature"] as Monster).has_meta(EncounterTurns.WARD))
	assert_true(bool((made[1]["creature"] as Monster).get_meta(EncounterTurns.WARD, false)))
	assert_eq(made[1]["side"], &"guest")
	var ends := LocationFights.ends_when_for(view, {"ends_when": {"wards_out": true, "ward_lost": "ended"}})
	assert_eq(ends["ward_exits"], [[0, 3]], "the place's open exits")
	assert_eq(ends["exits"], [], "the heroes don't step out by them")
	assert_eq(str(ends["ward_lost"]), "ended")
	view.free()
