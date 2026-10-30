extends TestCase
## The play camera's pitch comes from the campaign (data/campaign.json "camera" "pitch"); a game that says nothing
## keeps Curse of Strahd's 40 degrees.


func after_each() -> void:
	Campaign.use_config(null)


func _rig() -> CameraRig:
	var rig := CameraRig.new()
	add_child(rig)
	rig.snap_to_target()
	return rig


func test_no_camera_key_keeps_forty_degrees() -> void:
	Campaign.use_config({"module": "res://nowhere.gd"})
	var rig := _rig()
	assert_eq(rig.pitch_deg, CameraRig.PITCH_DEG, "the default pitch")
	assert_between(rig.camera.rotation_degrees.x, -40.01, -39.99, "the camera looks 40 degrees down")
	rig.free()


func test_a_campaign_pitch_moves_the_play_camera() -> void:
	Campaign.use_config({"camera": {"pitch": 30}})
	var rig := _rig()
	assert_between(rig.camera.rotation_degrees.x, -30.01, -29.99, "30 degrees down")
	# The camera sits back along its own line of sight to the party: lower and further out than at 40 degrees.
	var at := rig.camera.position
	assert_between(rad_to_deg(atan2(at.y - 0.6, at.z)), 29.9, 30.1, "the eye on the 30 degree line")
	rig.free()


func test_pitch_is_held_to_a_sane_range() -> void:
	Campaign.use_config({"camera": {"pitch": 5}})
	assert_eq(CameraRig.play_pitch(), -CameraRig.PITCH_RANGE.x, "too flat comes up to the range")
	Campaign.use_config({"camera": {"pitch": -85}})
	assert_eq(CameraRig.play_pitch(), -CameraRig.PITCH_RANGE.y, "a sign either way, too steep comes down")


func test_tactical_view_still_reaches_its_own_pitch() -> void:
	Campaign.use_config({"camera": {"pitch": 30}})
	var rig := _rig()
	rig.tactical = true
	rig.tactical_shown = 1.0
	rig._apply()
	assert_between(rig.camera.rotation_degrees.x, CameraRig.TACTICAL_PITCH_DEG - 0.01, CameraRig.TACTICAL_PITCH_DEG + 0.01,
		"the tactical view")
	rig.free()


func test_sun_shadow_reach_stretches_for_a_flatter_camera() -> void:
	assert_between(Atmosphere.shadow_reach(CameraRig.PITCH_DEG, 32.0), 0.9999, 1.0001, "unchanged at 40 degrees")
	assert_between(Atmosphere.shadow_reach(-30.0, 32.0), 1.2, 1.45, "about 1.3 times as far at 30")
