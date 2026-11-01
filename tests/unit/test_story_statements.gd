extends TestCase
## Story statements and fills (story/dialogue_file.gd, story/dialogue_runner.gd, story/schedule.gd,
## story/campaign_module.gd; docs/contracts/dialogue.md): Exhaustion from a conversation, a save every hero makes and
## what the ones who failed take, an attack roll as a check, a schedule's counters, and {flag.x} in a journal.


func _st() -> StoryState:
	var st := StoryState.new()
	for id: String in ["hedda_ironvow", "thistle"]:
		var ch := TestChars.pregen(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	return st


func _run(st: StoryState, text: String, seed_value: int = 1) -> DialogueRunner:
	var f := DialogueFile.parse(text, "test/talk")
	var r := DialogueRunner.new(st, DiceRoller.new(seed_value))
	r.file = f
	r.start("start")
	r.speaker = st.party[0]
	return r


func _beats(r: DialogueRunner) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in 30:
		var b := r.next()
		out.append(b)
		if str(b.get("kind", "")) == "end":
			break
	return out


func test_exhaustion_comes_and_goes() -> void:
	var st := _st()
	_beats(_run(st, "~ start\nexhaust +2\n"))
	assert_eq(st.party[0].exhaustion, 2, "the hero in the conversation")
	assert_eq(st.party[1].exhaustion, 0)
	_beats(_run(st, "~ start\nexhaust +1 party\nexhaust -2\n"))
	assert_eq([st.party[0].exhaustion, st.party[1].exhaustion], [1, 1])


func test_a_party_save_names_each_roll_and_the_failed_take_the_rest() -> void:
	var st := _st()
	var hp := [st.party[0].hp, st.party[1].hp]
	var beats := _beats(_run(st, "~ start\nsave Constitution DC 30 party -> bad | bad\n~ bad\ndamage 1d4 poison failed\nexhaust +1 failed\n"))
	assert_true(str(beats[0]["text"]).begins_with("Constitution save, DC 30:"), str(beats[0]))
	assert_false(st.last_check, "nobody makes DC 30")
	assert_true(st.party[0].hp < hp[0] and st.party[1].hp < hp[1], "both failed, both hurt")
	assert_eq([st.party[0].exhaustion, st.party[1].exhaustion], [1, 1])
	beats = _beats(_run(st, "~ start\nsave Constitution DC 1 party -> good | bad\n~ good\n| Fine.\n~ bad\nexhaust +1 failed\n"))
	assert_true(st.last_check, "everyone makes DC 1")
	assert_eq([st.party[0].exhaustion, st.party[1].exhaustion], [1, 1], "the ok branch: nobody failed")


func test_a_hero_who_resists_the_damage_passes_the_save() -> void:
	var st := _st()
	var fx := Effect.new("Test Fire Ward", &"feature", "test_fire_ward").with_modifier("resistance", {"value": "fire"})
	st.party[0].add_effect(fx)
	var beats := _beats(_run(st, "~ start\nsave Constitution DC 30 party unless resists fire -> ok | bad\n~ ok\n| Fine.\n~ bad\nexhaust +1 failed\n"))
	assert_true(str(beats[0]["text"]).contains("passes (Fire Resistance)"), str(beats[0]))
	assert_eq([st.party[0].exhaustion, st.party[1].exhaustion], [0, 1], "only the one without it failed")


func test_a_condition_for_a_while_on_those_who_failed() -> void:
	var st := _st()
	st.party[0].add_effect(Effect.new("Test Ward", &"feature", "test_ward").with_modifier("resistance", {"value": "fire"}))
	var beats := _beats(_run(st, "~ start\nsave Constitution DC 30 party unless resists fire -> ok | bad\n~ ok\n| Fine.\n~ bad\ncondition Poisoned 60 failed\n"))
	assert_true(beats.any(func(b: Dictionary) -> bool: return str(b.get("text", "")).contains("Poisoned for 1 hour")), str(beats))
	assert_false(st.party[0].has_condition(&"poisoned"), "the one who passed")
	assert_true(st.party[1].has_condition(&"poisoned"), "the one who failed")
	st.advance_minutes(59)
	assert_true(st.party[1].has_condition(&"poisoned"))
	st.advance_minutes(1)
	assert_false(st.party[1].has_condition(&"poisoned"), "an hour on, it's gone")


func test_a_twist_of_fate_from_the_story_and_spent_in_a_fight() -> void:
	var st := _st()
	_beats(_run(st, "~ start\ntwist +1\ntwist +1 party\n"))
	assert_eq([st.party[0].twists(), st.party[1].twists()], [2, 1])
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var c := e.add(st.party[0], &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 100)
	TestCombat.start_with(e, c)
	var ids := e.feature_actions.list(c).map(func(f: Dictionary) -> String: return str(f["id"]))
	assert_true("feat:twist:20" in ids and "feat:twist:1" in ids, "both on the hotbar")
	assert_true(e.feature_actions.perform(c, "twist:1", foe, Vector2.INF).ok)
	assert_eq(st.party[0].twists(), 1, "one spent")
	assert_eq(foe.creature.roll_save(e.dice, &"dex", 10).kept, 1, "its next d20 shows a 1")


func test_an_attack_roll_check() -> void:
	var st := _st()
	var ch := st.party[0]
	ch.add_item("dart", 5)
	var p := DialogueRunner.attack_for(ch, "ranged_attack")
	assert_true(p != null and (not p.melee or p.thrown), "a weapon that reaches")
	_beats(_run(st, "~ start\ncheck Ranged Attack DC 1 -> hit | miss\n~ hit\n| Bullseye.\n~ miss\n| Wide.\n"))
	assert_true(st.last_check, "DC 1 is hit")
	_beats(_run(st, "~ start\ncheck Ranged Attack DC 40 -> hit | miss\n~ hit\n| Bullseye.\n~ miss\n| Wide.\n"))
	assert_false(st.last_check, "DC 40 isn't")


func test_schedule_counters_and_flag_fills() -> void:
	var st := StoryState.new()
	st.set_flag("test_days_left", 5)
	Schedule.use([{"id": "test_tick", "hour": 6, "add": {"test_days_left": -1}}] as Array[Dictionary])
	Schedule.memory(st)
	st.advance_minutes(3 * 24 * 60)
	Schedule.catch_up(st, "")
	assert_eq(int(st.get_flag("test_days_left")), 4, "once however long the wait, as any event")
	st.advance_minutes(24 * 60)
	Schedule.catch_up(st, "")
	assert_eq(int(st.get_flag("test_days_left")), 3)
	Schedule.use([] as Array[Dictionary])
	assert_eq(CampaignModule.fill_flags("{flag.test_days_left} days, {flag.test_unset} more", st), "3 days, 0 more")
	assert_eq(CampaignModule.new().fill("Left: {flag.test_days_left}", st), "Left: 3", "the base module fills them")


func test_twists_for_a_chosen_hero() -> void:
	var st := _st()
	var second := st.party[1]
	_beats(_run(st, "~ start\ntwist +2 hero:2\ntwist +1 name:%s\ntwist +1 hero:9\n" % second.id))
	assert_eq([st.party[0].twists(), second.twists()], [0, 3], "the second hero, by place and by name; no ninth")
