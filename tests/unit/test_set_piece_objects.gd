extends TestCase
## Set pieces a fight is about (an encounter's `objects` with `threshold`, `undo` and `flag`; `ends_when.objects_gone`;
## a round event that takes a captive; docs/contracts/combat.md): chains only heavy blows break, a check slips them off,
## the fight is won once they're all gone, and a captive can vanish from the board on a round.


func _fight(ends: Dictionary = {}) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	e.ends_when = ends
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(10, 6), 300)
	var a := e.objects.put({"id": "test_chain_a", "kind": "crate", "cell": [3, 3], "name": "a chain", "hp": 20, "ac": 10,
		"threshold": 10, "undo": {"skill": "athletics", "dc": 5, "label": "Slip"}, "flag": "test_chain_a_off"})
	var b := e.objects.put({"id": "test_chain_b", "kind": "crate", "cell": [9, 1], "name": "a chain", "hp": 20, "ac": 10})
	TestCombat.start_with(e, hero)
	return [e, hero, foe, a, b]


func test_blows_under_the_threshold_do_nothing() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var a := got[3] as BattleObject
	e.objects.damage(a, [{"amount": 9, "type": "bludgeoning"}], got[1] as Combatant, "test")
	assert_eq(a.hp, 20, "9 is under its threshold of 10")
	e.objects.damage(a, [{"amount": 12, "type": "bludgeoning"}], got[1] as Combatant, "test")
	assert_eq(a.hp, 8, "12 gets through whole")


func test_a_check_slips_it_off_and_sets_its_flag() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var a := got[3] as BattleObject
	var cat := ActionCatalog.new(e)
	var act := cat.find(hero, "undo:" + a.id)
	assert_false(act.is_empty(), "the hotbar offers it")
	assert_true(str(act["label"]).begins_with("Slip"), str(act["label"]))
	assert_true(bool(act["legal"]), "within 5 ft")
	TestCombat.next_d20(e, 20)
	assert_true(cat.perform(hero, act).ok)
	assert_true(a.destroyed, "off")
	assert_false(hero.action_available, "the Utilize action")
	assert_true(bool(e.legendary.story_flags.get("test_chain_a_off", false)), "its flag goes to the story")
	assert_true(cat.find(hero, "undo:" + (got[4] as BattleObject).id).is_empty(), "nothing to undo on a plain object")


func test_the_fight_is_won_once_every_object_is_gone() -> void:
	var got := _fight({"objects_gone": ["test_chain_a", "test_chain_b"]})
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	e.objects.damage(got[3] as BattleObject, [{"amount": 50, "type": "bludgeoning"}], hero, "test")
	assert_eq(e.state, Encounter.State.ACTIVE, "one left")
	e.objects.damage(got[4] as BattleObject, [{"amount": 50, "type": "bludgeoning"}], hero, "test")
	assert_eq(e.state, Encounter.State.OVER)
	assert_eq(e.outcome, "victory", "the foe still standing")


func test_a_round_event_takes_a_captive() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	TestCombat.punching_bag(e, Vector2i(10, 6), 300)
	var m := TestChars.dummy(10, false, {"name": "Test Captive"})
	var captive := e.add(m, &"neutral", Vector2i(6, 6))
	e.legendary.set_round_events([{"id": "test_mist", "kind": "take", "who": ["Test Captive"], "flag": "test_taken",
		"narration": "Blue mist", "at": 20, "every": 1}])
	TestCombat.start_with(e, hero)
	for i in 6:
		if captive.has_meta("left_fight"):
			break
		e.end_turn()
	assert_eq(str(captive.get_meta("left_fight", "")), "taken", "the mist takes it")
	assert_true(bool(e.legendary.story_flags.get("test_taken", false)))
	assert_true(e.events.any(func(ev: Dictionary) -> bool: return str(ev["type"]) == "vanish" and str(ev.get("narration", "")) == "Blue mist"))
	assert_eq(e.state, Encounter.State.ACTIVE, "the fight goes on")


func test_saved_fights_keep_the_set_piece() -> void:
	var got := _fight()
	var a := got[3] as BattleObject
	var back := BattleObject.from_dict(a.to_dict())
	assert_eq([back.threshold, str(back.undo["label"]), back.flag], [10, "Slip", "test_chain_a_off"])
