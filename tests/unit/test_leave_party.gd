extends TestCase
## A hero who leaves the party changed (`leave_party <who> becomes <monster>`; DialogueRunner, StoryConditions
## `became:`): gone for good, kept among the fallen with what they became, never the last one standing.


func _st() -> StoryState:
	var st := StoryState.new()
	for id: String in ["hedda_ironvow", "thistle"]:
		var ch := TestChars.pregen(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	return st


func _run(st: StoryState, text: String) -> DialogueRunner:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.file = DialogueFile.parse(text, "test/leave")
	r.start("start")
	r.speaker = st.party[0]
	for i in 20:
		if str(r.next().get("kind", "")) == "end":
			break
	return r


func test_the_speaker_leaves_changed() -> void:
	var st := _st()
	var hedda := st.party[0]
	_run(st, "~ start\nleave_party speaker becomes test_wyrm\n")
	assert_eq(st.party.size(), 1, "gone from the party")
	assert_false(hedda in st.party)
	assert_eq(str((st.fallen[-1] as Dictionary)["becomes"]), "test_wyrm")
	assert_true(st.last_check)
	assert_true(StoryConditions.check("became:test_wyrm", st))
	assert_false(StoryConditions.check("became:test_other", st))


func test_a_selector_and_never_the_last_one() -> void:
	var st := _st()
	_run(st, "~ start\nleave_party name:thistle becomes test_wyrm\n")
	assert_eq(st.party.size(), 1)
	assert_true(StoryConditions.check("fallen:thistle", st), "kept among the fallen")
	_run(st, "~ start\nleave_party speaker becomes test_wyrm\n")
	assert_eq(st.party.size(), 1, "the last hero standing stays")
	assert_false(st.last_check)
