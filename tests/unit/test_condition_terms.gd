extends TestCase
## Story condition terms (story/story_conditions.gd, docs/contracts/dialogue.md): the company's size, one flag held
## against another, and the tolerant `flag?.` read of a flag another chapter sets.


func _st() -> StoryState:
	var st := StoryState.new()
	for id: String in ["hedda_ironvow", "thistle", "silvain_aster"]:
		st.party.append(TestChars.pregen(id, 1))
	return st


func test_party_alive_and_party_size() -> void:
	var st := _st()
	assert_true(StoryConditions.check("party_alive == 3", st))
	assert_true(StoryConditions.check("party_size == 3", st))
	st.fallen.append({"id": "test_lost"})
	st.party.pop_back()
	assert_true(StoryConditions.check("party_alive == 2 and party_size == 3", st), "the fallen still count in the size")
	assert_true(StoryConditions.check("party_size > party_alive", st), "somebody fell")
	st.set_flag("test_bargains", 3)
	assert_true(StoryConditions.check("flag.test_bargains >= party_size", st), "a flag held against the company")


func test_one_flag_against_another() -> void:
	var st := _st()
	st.set_flag("test_a", 2)
	st.set_flag("test_b", 5)
	assert_true(StoryConditions.check("flag.test_a <= flag.test_b", st))
	assert_false(StoryConditions.check("flag.test_a > flag.test_b", st))
	assert_true(StoryConditions.check("flag.test_a > flag.test_unset", st), "an unset flag on the right counts 0")
	st.set_flag("test_b", 2)
	assert_true(StoryConditions.check("flag.test_a == flag.test_b", st))


func test_the_tolerant_read_reads_like_a_flag() -> void:
	var st := _st()
	assert_false(StoryConditions.check("flag?.test_other", st), "false while nobody has set it")
	st.set_flag("test_other", 3)
	assert_true(StoryConditions.check("flag?.test_other", st))
	assert_true(StoryConditions.check("flag?.test_other >= 3", st))
	st.set_flag("test_mine", 1)
	assert_true(StoryConditions.check("flag.test_mine < flag?.test_other", st))
