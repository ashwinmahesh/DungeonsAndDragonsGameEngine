extends TestCase
## 2024: a Stable creature at 0 Hit Points regains 1 Hit Point after 1d4 hours (Services.wake_the_stable), under the campaign's
## `stable_wakes`; the first game leaves a downed hero at 0 until healed. The dead stay dead.


func after_each() -> void:
	Campaign.use_config(null)


func _state() -> StoryState:
	var st := StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 2)
		ch.finish_long_rest()
		st.party.append(ch)
	st.party[0].hp = 0
	st.party[0].stable = true
	st.party[1].hp = 0
	st.party[1].dead = true
	return st


func test_a_downed_hero_comes_round_within_four_hours() -> void:
	Campaign.use_config({"stable_wakes": true})
	var st := _state()
	st.advance_minutes(10)
	assert_eq(st.party[0].hp, 0, "not in ten minutes")
	for i in 4:
		st.advance_minutes(60)
	assert_eq(st.party[0].hp, 1, "1 Hit Point within 1d4 hours")
	assert_true(st.party[1].dead and st.party[1].hp == 0, "the dead stay dead")


func test_without_the_setting_they_stay_down() -> void:
	Campaign.use_config({})
	var st := _state()
	for i in 5:
		st.advance_minutes(60)
	assert_eq(st.party[0].hp, 0)
