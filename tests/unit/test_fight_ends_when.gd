extends TestCase
## A fight that ends with no winner (an encounter's `ends_when`; Encounter.ends_when, EncounterTurns, LocationFights;
## docs/contracts/combat.md): a sleeper that wakes, fights until the party leaves the map or the hero who hurt it drops,
## then goes back to sleep. The outcome is "ended": not a victory, not a defeat.

const EXIT := Vector2i(0, 3)


func _field(ends: Dictionary) -> Encounter:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	e.ends_when = ends
	return e


func _hurt(e: Encounter, source: Combatant, target: Combatant, amount: int) -> void:
	e.deal_damage(source, target, [{"amount": amount, "type": "force"}], false, "test")
	e._check_over()


## Ends turns (nobody acts) until it is `c`'s.
func _turn_of(e: Encounter, c: Combatant) -> void:
	for i in 10:
		if e.current() == c or e.state != Encounter.State.ACTIVE:
			return
		e.end_turn()
	assert_eq(e.current(), c, "%s's turn came round" % c.name())


# --- The hero who hurt it drops ------------------------------------------------------------------------------------

func test_the_fight_ends_when_the_first_hero_to_hurt_a_foe_drops() -> void:
	var e := _field({"trigger_hero_down": true})
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 3)
	var b := TestCombat.hero(e, "thistle", Vector2i(4, 5), 3)
	TestCombat.hero(e, "silvain_aster", Vector2i(3, 4), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, a)
	_hurt(e, a, foe, 5)
	_hurt(e, b, foe, 5)
	assert_true(a.has_meta(EncounterTurns.FIRST_TO_HURT), "the first blow marks its hero")
	assert_false(b.has_meta(EncounterTurns.FIRST_TO_HURT), "and only the first")
	_hurt(e, foe, b, b.creature.hp + 1)
	assert_eq(e.state, Encounter.State.ACTIVE, "another hero dropping changes nothing")
	_hurt(e, foe, a, a.creature.hp + 1)
	assert_eq(e.state, Encounter.State.OVER, "the one who hurt it drops: it's over")
	assert_eq(e.outcome, "ended", "with no winner")
	assert_true(e.events.any(func(ev: Dictionary) -> bool: return str(ev["type"]) == "over" and str(ev["outcome"]) == "ended"))


func test_without_ends_when_the_hero_dropping_is_just_a_hero_down() -> void:
	var e := _field({})
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 3)
	TestCombat.hero(e, "thistle", Vector2i(4, 5), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, a)
	_hurt(e, a, foe, 5)
	assert_false(a.has_meta(EncounterTurns.FIRST_TO_HURT), "nothing is marked in an ordinary fight")
	_hurt(e, foe, a, a.creature.hp + 1)
	assert_eq(e.state, Encounter.State.ACTIVE)


func test_the_whole_party_down_is_still_a_defeat() -> void:
	var e := _field({"trigger_hero_down": true})
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, a)
	_hurt(e, a, foe, 5)
	_hurt(e, foe, a, a.creature.hp + 1)
	assert_eq(e.outcome, "defeat", "nobody is left standing: a defeat, as ever")


# --- The party leaves the map --------------------------------------------------------------------------------------

func test_heroes_step_out_by_an_exit_and_the_fight_ends_when_none_is_left() -> void:
	var e := _field({"exits": [[EXIT.x, EXIT.y]]})
	var a := TestCombat.hero(e, "hedda_ironvow", EXIT, 3)
	var b := TestCombat.hero(e, "thistle", Vector2i(4, 5), 3)
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, a)
	e.end_turn()
	assert_eq(str(a.get_meta("left_fight", "")), "exit", "a hero ending their turn on the exit steps out")
	assert_eq(a.get_meta(EncounterTurns.LEFT_AT), [EXIT.x, EXIT.y], "remembering where")
	assert_eq(e.state, Encounter.State.ACTIVE, "one hero is still on the board")
	_turn_of(e, b)
	b.cell = Vector2i(2, 2)
	e.end_turn()
	assert_eq(e.state, Encounter.State.ACTIVE, "a hero off the exit stays")
	_turn_of(e, b)
	b.cell = EXIT
	e.end_turn()
	assert_eq(e.state, Encounter.State.OVER, "the last hero out: it's over")
	assert_eq(e.outcome, "ended")


func test_one_hero_out_and_the_rest_down_is_no_defeat() -> void:
	var e := _field({"exits": [[EXIT.x, EXIT.y]]})
	var a := TestCombat.hero(e, "hedda_ironvow", EXIT, 3)
	var b := TestCombat.hero(e, "thistle", Vector2i(4, 5), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, a)
	e.end_turn()
	_hurt(e, foe, b, b.creature.hp + 1)
	assert_eq(e.outcome, "ended", "one got out: the fight is left, not lost")


func test_a_hero_down_on_the_exit_does_not_step_out() -> void:
	var e := _field({"exits": [[EXIT.x, EXIT.y]]})
	var a := TestCombat.hero(e, "hedda_ironvow", EXIT, 3)
	TestCombat.hero(e, "thistle", Vector2i(4, 5), 3)
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, a)
	a.creature.hp = 0
	a.creature.stable = true
	e.end_turn()
	assert_false(a.has_meta("left_fight"), "the fallen are carried out by nobody")


func test_without_exits_a_hero_on_one_stays() -> void:
	var e := _field({})
	var a := TestCombat.hero(e, "hedda_ironvow", EXIT, 3)
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, a)
	e.end_turn()
	assert_false(a.has_meta("left_fight"))
	assert_eq(e.state, Encounter.State.ACTIVE)


# --- The place's side (LocationFights) -----------------------------------------------------------------------------

func _view() -> LocationView:
	var view := LocationView.new()
	view.st = StoryState.new()
	view.loc_id = "test_sleeper_den"
	view.loc = {"id": view.loc_id, "region": "", "exits": [
			{"id": "back", "cell": [0, 3], "to": "elsewhere", "label": "Back"},
			{"id": "on", "cell": [9, 3], "to": "elsewhere", "label": "On", "when": "flag.test_door_open"}],
		"encounters": [{"id": "test_sleeper", "trigger": "enter_area:bed", "waiting": true, "surprise": "enemies",
			"monsters": [{"monster": "tiger", "cell": [5, 3], "facing": "west"}],
			"ends_when": {"party_left_map": true, "trigger_hero_down": true, "flag": "test_sleeper_slept",
				"clear_flags": ["test_sleeper_woken"]}}]}
	return view


func test_the_place_hands_the_fight_its_open_exits() -> void:
	var view := _view()
	var spec := (view.loc["encounters"] as Array)[0] as Dictionary
	var ends := LocationFights.ends_when_for(view, spec)
	assert_true(bool(ends["trigger_hero_down"]))
	assert_eq(ends["exits"], [[0, 3]], "only the exits open now")
	view.st.set_flag("test_door_open")
	assert_eq(LocationFights.ends_when_for(view, spec)["exits"], [[0, 3], [9, 3]])
	assert_eq(LocationFights.ends_when_for(view, {"id": "plain"}), {}, "a fight without ends_when ends as ever")
	view.free()


func test_an_ended_fight_puts_the_sleeper_back_to_wait() -> void:
	var view := _view()
	var spec := (view.loc["encounters"] as Array)[0] as Dictionary
	(view.st.loc_state(view.loc_id)["encounters"] as Dictionary)["test_sleeper"] = "started"
	view.st.set_flag("test_sleeper_woken")
	LocationFights._ended_without_winner(view, "test_sleeper", spec)
	assert_false((view.st.loc_state(view.loc_id)["encounters"] as Dictionary).has("test_sleeper"), "the fight isn't done")
	assert_true(bool(view.st.get_flag("test_sleeper_slept")), "its flag is set")
	assert_false(view.st.flags.has("test_sleeper_woken"), "the flag that woke it is cleared, so it can wake again")
	var back := view.waiting.filter(func(w: Dictionary) -> bool: return str(w["encounter"]) == "test_sleeper")
	assert_eq(back.size(), 1, "it waits again")
	assert_eq((back[0]["foe"] as Combatant).cell, Vector2i(5, 3), "on its own square")
	assert_true(LocationStealth.is_asleep(view, back[0] as Dictionary), "asleep, as its entry says")
	view.free()
