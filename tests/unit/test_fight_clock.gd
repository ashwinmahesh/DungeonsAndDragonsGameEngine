extends TestCase
## A fight on a clock (an encounter's `ends_when.rounds`; EncounterTurns.clock_left and _clock_runs_out,
## LocationFights.ends_when_for): it ends as its last round ends, with the clock's outcome and flag, and the HUD
## counts the rounds down.


func _fight(ends: Dictionary) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	e.ends_when = ends
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3), 500)
	TestCombat.start_with(e, hero)
	return [e, hero, foe]


## Ends turns (nobody acts) until round `n` begins or the fight is over.
func _to_round(e: Encounter, n: int) -> void:
	for i in 40:
		if e.round_no >= n or e.state != Encounter.State.ACTIVE:
			return
		e.end_turn()


func test_the_clock_counts_down_and_ends_the_fight_as_its_last_round_ends() -> void:
	var got := _fight({"rounds": 3, "rounds_outcome": "defeat", "rounds_flag": "test_mill_fell", "rounds_label": "The roof falls"})
	var e := got[0] as Encounter
	assert_eq(e.turns.clock_left(), 3, "three rounds left in the first")
	_to_round(e, 3)
	assert_eq(e.state, Encounter.State.ACTIVE, "the third round is still played")
	assert_eq(e.turns.clock_left(), 1, "the last one")
	_to_round(e, 4)
	assert_eq(e.state, Encounter.State.OVER, "over as round 3 ends")
	assert_eq(e.outcome, "defeat", "with the clock's outcome")
	assert_eq(e.round_no, 3, "no fourth round")
	assert_true(bool(e.legendary.story_flags.get("test_mill_fell", false)), "its flag goes to the story")
	assert_true(e.events.any(func(ev: Dictionary) -> bool: return str(ev["type"]) == "clock" and str(ev["label"]) == "The roof falls"))
	assert_eq(str((e.events[-1] as Dictionary)["type"]), "over")


func test_holding_out_can_be_a_victory_and_ended_is_the_default() -> void:
	var got := _fight({"rounds": 1, "rounds_outcome": "victory"})
	var e := got[0] as Encounter
	_to_round(e, 2)
	assert_eq(e.outcome, "victory", "the party held out")
	got = _fight({"rounds": 1})
	e = got[0] as Encounter
	_to_round(e, 2)
	assert_eq(e.outcome, "ended", "no winner by default")


func test_a_fight_won_first_never_runs_out() -> void:
	var got := _fight({"rounds": 5, "rounds_flag": "test_too_late"})
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	e.deal_damage(hero, foe, [{"amount": 999, "type": "force"}], false, "test")
	e._check_over()
	assert_eq(e.outcome, "victory")
	assert_false(e.legendary.story_flags.has("test_too_late"))


func test_no_clock_without_rounds() -> void:
	var got := _fight({})
	assert_eq((got[0] as Encounter).turns.clock_left(), -1)


func test_the_place_passes_the_clock_on() -> void:
	var view := LocationView.new()
	view.st = StoryState.new()
	view.loc = {"id": "test_mill", "region": "", "exits": []}
	var out := LocationFights.ends_when_for(view, {"ends_when": {"rounds": 4, "rounds_outcome": "defeat", "rounds_flag": "test_f",
		"rounds_label": "Collapse"}})
	assert_eq([out["rounds"], out["rounds_outcome"], out["rounds_flag"], out["rounds_label"]], [4, "defeat", "test_f", "Collapse"])
	view.free()


func test_a_countdown_only_sets_its_flag_and_the_fight_goes_on() -> void:
	var got := _fight({"rounds": 2, "rounds_outcome": "none", "rounds_flag": "test_falls_now"})
	var e := got[0] as Encounter
	_to_round(e, 4)
	assert_eq(e.state, Encounter.State.ACTIVE, "the fight goes on")
	assert_eq(e.round_no, 4)
	assert_true(bool(e.legendary.story_flags.get("test_falls_now", false)))
	assert_eq(e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "clock").size(), 1, "once")
	assert_eq(e.turns.clock_left(), 0)
