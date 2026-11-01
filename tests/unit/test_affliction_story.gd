extends TestCase
## Afflictions in the story (`afflict <id> <+n|-n|clear> [party]`, the condition `affliction.<id>`, the temple's Lesser
## Restoration; docs/contracts/afflictions.md).

const ID := "test_rot"


func before_each() -> void:
	Compendium.shared().table("afflictions")[ID] = {"id": ID, "name": "Test Rot",
		"modifiers": [{"stat": "attack", "per_level": -1}], "cures": [{"ends": "poisoned", "remove": 1}]}


func after_each() -> void:
	Compendium.shared().table("afflictions").erase(ID)


func _st() -> StoryState:
	var st := StoryState.new()
	for id: String in ["hedda_ironvow", "thistle"]:
		var ch := TestChars.pregen(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	return st


func _run(st: StoryState, text: String) -> Array[Dictionary]:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.file = DialogueFile.parse(text, "test/afflict")
	r.start("start")
	r.speaker = st.party[0]
	var out: Array[Dictionary] = []
	for i in 20:
		var b := r.next()
		out.append(b)
		if str(b.get("kind", "")) == "end":
			break
	return out


func test_a_conversation_gives_and_takes_levels() -> void:
	var st := _st()
	var beats := _run(st, "~ start\nafflict test_rot +2\nafflict test_rot +1 party\n")
	assert_eq([Afflictions.level_of(st.party[0], ID), Afflictions.level_of(st.party[1], ID)], [3, 1])
	assert_true(str(beats[0]["text"]).contains("Test Rot is level 2"), str(beats[0]))
	assert_true(StoryConditions.check("affliction.test_rot >= 3", st), "the highest in the party")
	assert_false(StoryConditions.check("affliction.test_rot >= 4", st))
	assert_true(StoryConditions.check("affliction.test_rot", st), "bare: anyone has it")
	_run(st, "~ start\nafflict test_rot clear party\n")
	assert_false(StoryConditions.check("affliction.test_rot", st), "cleared from everyone")


func test_the_temples_lesser_restoration_eases_it() -> void:
	var st := _st()
	var ch := st.party[0]
	st.gold = 1000.0
	var line := {"id": "lesser_restoration"}
	line.merge(Services.KINDS["lesser_restoration"] as Dictionary)
	assert_ne(Services.why_not(st, line, ch), "", "nothing to end yet")
	Afflictions.set_level(ch, ID, 2)
	assert_eq(Services.why_not(st, line, ch), "", "an affliction it eases counts")
	var said := Services.buy(st, "test_priest", line, ch, DiceRoller.new(1))
	assert_eq(Afflictions.level_of(ch, ID), 1, "one level off")
	assert_true(said.contains("Test Rot"), said)
