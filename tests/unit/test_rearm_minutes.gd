extends TestCase
## A fight that comes back after a while (an encounter's `rearm_minutes`, LocationFights.rearm): won, it waits out its
## minutes on the clock and is then not done any more; a fight without it stays won.

const LOC := {"id": "test_square", "encounters": [
	{"id": "test_mob", "trigger": "enter_area:square", "rearm_minutes": 240, "monsters": []},
	{"id": "test_once", "trigger": "enter_area:square", "monsters": []}]}


func _won(st: StoryState, id: String, rearm: bool) -> void:
	(st.loc_state("test_square")["encounters"] as Dictionary)[id] = true
	if rearm:
		st.loc_state("test_square")["rearm"] = {id: st.total_minutes()}


func test_a_won_fight_comes_back_after_its_minutes() -> void:
	var st := StoryState.new()
	_won(st, "test_mob", true)
	_won(st, "test_once", false)
	st.advance_minutes(200)
	assert_false(LocationFights.rearm(st, "test_square", LOC), "not yet")
	assert_true(bool((st.loc_state("test_square")["encounters"] as Dictionary).get("test_mob", false)))
	st.advance_minutes(40)
	assert_true(LocationFights.rearm(st, "test_square", LOC), "four hours on")
	var done := st.loc_state("test_square")["encounters"] as Dictionary
	assert_false(done.has("test_mob"), "the mob is back")
	assert_true(bool(done.get("test_once", false)), "a fight without rearm_minutes stays won")
	assert_false(LocationFights.rearm(st, "test_square", LOC), "once")
