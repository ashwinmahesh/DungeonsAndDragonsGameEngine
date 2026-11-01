extends TestCase
## Losing a fight by being taken (an encounter's `defeat`; DefeatCapture, LocationFights): the fallen come round, the
## flags are stamped, the party is jailed or moved, and the outcome is "captured", not a game over.


func _st() -> StoryState:
	var st := StoryState.new()
	for id: String in ["hedda_ironvow", "thistle"]:
		var ch := TestChars.pregen(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	return st


func test_the_fallen_come_round_and_are_jailed() -> void:
	var st := _st()
	var a := st.party[0]
	var b := st.party[1]
	a.hp = 0
	a.death_failures = 2
	b.hp = 0
	b.stable = true
	b.add_item("dagger", 1)
	var to := DefeatCapture.apply(st, {"jail": "test_cells:bunk", "until": "flag.test_bailed", "set": ["test_taken"], "hp": 2})
	assert_eq(to, {"location": "test_cells", "spawn": "bunk"})
	assert_eq([a.hp, b.hp], [2, 2], "both come round at 2")
	assert_eq(a.death_failures, 0)
	assert_false(b.stable)
	assert_true(st.flags.has("test_taken"), "the flag, stamped")
	assert_eq(int(st.flags["test_taken"]), st.total_minutes())
	assert_true(Jail.held(st), "locked up")
	assert_true(b.entry_of("dagger").is_empty(), "the jailers keep the gear")
	st.set_flag("test_bailed")
	assert_false(Jail.held(st), "let out by its until")


func test_moved_with_gear_and_the_dead_stay_dead() -> void:
	var st := _st()
	var a := st.party[0]
	var b := st.party[1]
	a.hp = 0
	a.dead = true
	b.hp = 0
	b.add_item("dagger", 1)
	var to := DefeatCapture.apply(st, {"move": "test_larder", "set": "test_larder_clock"})
	assert_eq(to, {"location": "test_larder", "spawn": "default"})
	assert_eq(a.hp, 0, "the dead stay dead")
	assert_eq(b.hp, 1, "1 HP by default")
	assert_false(Jail.held(st), "moved, not jailed")
	assert_false(b.entry_of("dagger").is_empty(), "gear and all")
	assert_true(st.flags.has("test_larder_clock"))


func test_no_rule_no_capture() -> void:
	assert_true(DefeatCapture.rule_for({"id": "test_fight"}).is_empty())
	assert_eq(DefeatCapture.rule_for({"defeat": {"jail": "x"}}), {"jail": "x"})
