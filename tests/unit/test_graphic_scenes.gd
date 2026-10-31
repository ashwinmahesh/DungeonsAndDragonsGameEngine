extends TestCase
## The player's `graphic_scenes` option (on unless switched off; docs/reference/ui/cutscenes.md and
## docs/contracts/dialogue.md): a cutscene marked graphic shows its tame one or is skipped, a graphic take is passed
## over, and conversations follow it with the `graphic` condition.

const DIALOGUE := """
~ scene
if graphic
Narrator: The blood runs down the walls.
else
Narrator: Something dark runs down the walls.
endif
"""


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/graphic"))
	Cutscenes.register({"id": "test_gore", "graphic": true, "tame": "test_gore_tame", "trigger": "examine:test_altar",
		"images": [{"image": "test_gore", "when": ""}]})
	Cutscenes.register({"id": "test_gore_tame", "images": [{"image": "test_gore_soft", "when": ""}]})
	Cutscenes.register({"id": "test_gore_alone", "graphic": true, "images": [{"image": "test_gore_b", "when": ""}]})
	Cutscenes.register({"id": "test_takes", "images": [{"image": "test_take_gory", "when": "", "graphic": true},
		{"image": "test_take_mild", "when": ""}]})


func after_each() -> void:
	Cutscenes.clear_cache()


func _line(st: StoryState) -> String:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/graphic:scene"))
	return str(r.next()["text"])


func test_on_by_default_everything_shows() -> void:
	var st := StoryState.new()
	assert_true(Cutscenes.graphic_ok(st))
	assert_eq(Cutscenes.image("test_gore", st), Cutscenes.ART % "test_gore")
	assert_eq(Cutscenes.image("test_takes", st), Cutscenes.ART % "test_take_gory", "the first take that fits")
	assert_eq(_line(st), "The blood runs down the walls.")


func test_off_the_tame_versions_show_and_the_rest_is_skipped() -> void:
	var st := StoryState.new()
	st.options["graphic_scenes"] = false
	assert_eq(Cutscenes.image("test_gore", st), Cutscenes.ART % "test_gore_soft", "its tame picture")
	assert_eq(Cutscenes.for_trigger("examine:test_altar", st), "test_gore", "its trigger still plays it, tamely")
	assert_eq(Cutscenes.image("test_gore_alone", st), "", "none to swap in: skipped")
	assert_eq(Cutscenes.image("test_takes", st), Cutscenes.ART % "test_take_mild", "a graphic take is passed over")
	assert_eq(_line(st), "Something dark runs down the walls.", "conversations follow it with `graphic`")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_false(Cutscenes.graphic_ok(back), "a save keeps the choice")
