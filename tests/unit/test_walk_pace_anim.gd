extends TestCase
## WalkPace.anim: how fast every figure animates, from the campaign's `anim_speed` (1 by default), with a tool's live
## override on top.


func after_each() -> void:
	Campaign.use_config(null)
	WalkPace.speed_override = -1.0


func test_one_by_default() -> void:
	Campaign.use_config({})
	assert_eq(WalkPace.anim(), 1.0)


func test_the_campaign_sets_it() -> void:
	Campaign.use_config({"anim_speed": 1.5})
	assert_eq(WalkPace.anim(), 1.5)


func test_an_override_wins() -> void:
	Campaign.use_config({"anim_speed": 1.5})
	WalkPace.speed_override = 2.0
	assert_eq(WalkPace.anim(), 2.0)
	WalkPace.speed_override = -1.0
	assert_eq(WalkPace.anim(), 1.5)
