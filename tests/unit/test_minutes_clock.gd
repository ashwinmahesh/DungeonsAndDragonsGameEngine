extends TestCase
## Clocks by the minute (docs/contracts/dialogue.md, combat.md): `minutes_since.<flag>` counts game minutes from a
## `set <flag> = now`, a quest's `closes` rule can run out on it, a place's `recheck_minutes` re-checks its placements
## that often, and a round event's `until_flag` stops it once the fight sets the flag.

const DIALOGUE := """
~ light
set test_fire = now
"""

var content := FixtureContent.new()


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/minutes"))


func after_each() -> void:
	content.restore()


func _stamped() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.start("test/minutes:light")
	r.next()
	return st


func test_minutes_since_counts_from_the_stamp() -> void:
	var plain := StoryState.new()
	assert_eq(plain.minutes_since("test_fire"), -1, "not stamped")
	assert_false(StoryConditions.check("minutes_since.test_fire >= 0", plain), "false until it is")
	var st := _stamped()
	st.advance_minutes(9)
	assert_eq(st.minutes_since("test_fire"), 9)
	assert_false(StoryConditions.check("minutes_since.test_fire >= 10", st))
	st.advance_minutes(1)
	assert_true(StoryConditions.check("minutes_since.test_fire >= 10", st), "ten minutes on")
	st.advance_minutes(1)
	assert_true(StoryConditions.check("minutes_since.test_fire > 10", st), "eleven")


func test_a_quest_runs_out_on_it() -> void:
	var q := content.add_quest("test_douse", "Douse the Fire", [["burning", ""], ["out", "success"], ["lost", "failure"]])
	(Compendium.shared().get_entry("quests", q) as Dictionary)["closes"] = [{"stage": "lost", "when": "minutes_since.test_fire >= 10"}]
	var st := _stamped()
	st.set_quest_stage(q, "burning")
	st.advance_minutes(9)
	assert_true(QuestClosures.sweep(st).is_empty(), "nine minutes: still burning")
	assert_eq(st.quest_stage(q), "burning")
	st.advance_minutes(1)
	QuestClosures.sweep(st)
	assert_eq(st.quest_stage(q), "lost", "ten: the fire won")


func test_a_place_rechecks_as_often_as_it_says() -> void:
	var plain := {"id": "test_village"}
	assert_false(LocationClock.turns(plain, 61, 62), "a minute passing changes nothing in a place that doesn't ask")
	assert_true(LocationClock.turns(plain, 119, 120), "the hour turning always does")
	var burning := {"id": "test_village", "recheck_minutes": 2}
	assert_true(LocationClock.turns(burning, 61, 62), "every two minutes")
	assert_false(LocationClock.turns(burning, 62, 63))
	assert_true(LocationClock.turns(burning, 63, 64))


func test_a_round_event_stops_once_the_fight_sets_its_flag() -> void:
	var e := TestCombat.open_field(3)
	var ev := {"id": "test_flames", "at": 20, "until_flag": "test_fire_out", "save": {"ability": "dex", "dc": 10}}
	e.legendary.set_round_events([ev])
	assert_true(e.legendary.round_events._in_round(ev, 1), "it burns")
	e.legendary.story_flags["test_fire_out"] = true
	assert_false(e.legendary.round_events._in_round(ev, 2), "put out: it stops")
	assert_true(e.legendary.round_events._in_round({"id": "test_other", "at": 20}, 2), "another event goes on")
