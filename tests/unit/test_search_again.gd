extends TestCase
## A missed hidden find (LocationTraps' `missed:` marks) may be searched for again after a rest only under the campaign's
## `search_again_after_rest` (RestRules.note_short_rest, forget_missed_finds); by default a miss is for good.


func after_each() -> void:
	Campaign.use_config(null)


func _state() -> StoryState:
	var st := StoryState.new()
	var found := st.loc_state("somewhere")["found"] as Dictionary
	found["missed:jar:hero"] = true
	found["jar_two"] = true
	return st


func test_a_miss_is_for_good_by_default() -> void:
	Campaign.use_config({})
	var st := _state()
	RestRules.note_short_rest(st)
	assert_true((st.loc_state("somewhere")["found"] as Dictionary).has("missed:jar:hero"), "the first game's rule")


func test_a_rest_lets_a_hero_search_again_when_the_campaign_says_so() -> void:
	Campaign.use_config({"search_again_after_rest": true})
	var st := _state()
	RestRules.note_short_rest(st)
	var found := st.loc_state("somewhere")["found"] as Dictionary
	assert_false(found.has("missed:jar:hero"), "the miss is forgotten")
	assert_true(bool(found.get("jar_two", false)), "a find made stays made")
