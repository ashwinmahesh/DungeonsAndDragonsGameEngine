extends TestCase
## A quest stage that waits on a later part of the story (a stage's `waits: {until, text}`; QuestLog.journal,
## docs/contracts/locations.md): until `until` holds the journal shows the line in place of its objectives and hint,
## and nothing follows it; then it reads as any other stage.

var content := FixtureContent.new()


func before_each() -> void:
	content.add("quests", {"id": "test_thread", "name": "The Test Thread", "summary": "A thread that picks up later.", "kind": "side",
		"stages": [
			{"id": "met", "journal": "You met the stranger.", "objectives": ["Hear the stranger out"], "hint": "The square."},
			{"id": "later", "journal": "The stranger will find you again.", "objectives": ["Meet the stranger at the old mill"],
				"hint": "The mill.", "waits": {"until": "flag.test_chapter_two", "text": "This picks up when you reach the mill country."}},
			{"id": "done", "journal": "Done.", "objectives": [], "ends": "success"}]})


func after_each() -> void:
	content.restore()


func _entry(st: StoryState) -> Dictionary:
	for q in QuestLog.journal(st):
		if str(q["id"]) == "test_thread":
			return q
	return {}


func test_a_waiting_stage_shows_its_line_and_nothing_to_do() -> void:
	var st := StoryState.new()
	st.set_quest_stage("test_thread", "met")
	assert_eq(str(_entry(st)["waiting"]), "", "an ordinary stage doesn't wait")
	assert_eq(_entry(st)["objectives"], ["Hear the stranger out"])
	st.set_quest_stage("test_thread", "later")
	QuestLog.track(st, "test_thread")
	var q := _entry(st)
	assert_eq(str(q["status"]), "active", "still an open thread")
	assert_eq(str(q["waiting"]), "This picks up when you reach the mill country.")
	assert_eq(q["objectives"], [], "no objective meanwhile, so the HUD passes it by")
	assert_eq(str(q["hint"]), "")
	assert_false(bool(q["tracked"]), "and it can't be followed")
	assert_eq(QuestLog.tracked(st), "")
	assert_true((q["entries"] as Array).has("The stranger will find you again."), "its journal text still reads")


func test_once_the_story_gets_there_it_reads_as_any_other() -> void:
	var st := StoryState.new()
	st.set_quest_stage("test_thread", "met")
	st.set_quest_stage("test_thread", "later")
	st.set_flag("test_chapter_two")
	var q := _entry(st)
	assert_eq(str(q["waiting"]), "")
	assert_eq(q["objectives"], ["Meet the stranger at the old mill"])
	assert_eq(str(q["hint"]), "The mill.")
	st.set_quest_stage("test_thread", "done")
	assert_eq(str(_entry(st)["waiting"]), "", "a finished quest never waits")
