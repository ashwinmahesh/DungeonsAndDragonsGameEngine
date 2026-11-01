extends TestCase
## A place's rest rule that changes with the story (`rest_when`, RestRules.rule_of): the first entry whose condition
## holds replaces `rest` and `rest_text`.

const LOC := {"id": "test_house", "map": {"rows": ["...."]}, "rest": "no", "rest_text": "The house won't have you.",
	"rest_when": [
		{"when": "flag.hunt_on and not flag.hunt_over", "rest": "safe"},
		{"when": "flag.house_burnt", "rest": "no", "rest_text": "Ashes."}]}

var _locations: Dictionary = {}


func before_each() -> void:
	var locs := Compendium.shared().table("locations")
	_locations = locs.duplicate()
	locs["test_house"] = LOC
	Compendium.shared().tables["locations"] = locs


func after_each() -> void:
	Compendium.shared().tables["locations"] = _locations


func test_the_first_entry_that_holds_sets_the_rule() -> void:
	var st := StoryState.new()
	st.location = "test_house"
	assert_eq(RestRules.rule_of(LOC, st), "no")
	assert_eq(RestRules.long_rest_refusals(st), ["The house won't have you."] as Array[String])
	st.flags["hunt_on"] = true
	assert_eq(RestRules.rule_of(LOC, st), "safe")
	assert_eq(RestRules.long_rest_refusals(st), [] as Array[String])
	assert_false(CampSite.makes_camp(LOC, st), "a safe roof keeps the rest screen")
	st.flags["hunt_over"] = true
	st.flags["house_burnt"] = true
	assert_eq(RestRules.long_rest_refusals(st), ["Ashes."] as Array[String])


func test_without_rest_when_or_a_story_the_place_keeps_its_own() -> void:
	assert_eq(RestRules.rule_of({"rest": "safe"}, StoryState.new()), "safe")
	assert_eq(RestRules.rule_of({}, StoryState.new()), "risky")
	assert_eq(RestRules.rule_of(LOC, null), "no")
	assert_true(CampSite.makes_camp({"map": {}}))
