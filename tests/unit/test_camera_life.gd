extends TestCase
## The camera's life of its own for a game that asks (data/campaign.json "camera": drift, fight_sweep, letterbox; the
## Visual Polish Plan's E50): off by default, so a game that names none keeps its still camera.


func after_each() -> void:
	Campaign.use_config(null)


func test_a_game_that_names_none_keeps_a_still_camera() -> void:
	Campaign.use_config({"module": "res://nowhere.gd"})
	var rig := CameraRig.new()
	assert_eq(rig.drift, 0.0, "no drift")
	assert_eq(CameraRig.fight_sweep(), 0.0, "no opening sweep")
	assert_false(CameraRig.letterbox(), "no letterbox")
	rig.free()


func test_the_view_breathes_once_the_party_stands_still() -> void:
	Campaign.use_config({"camera": {"drift": 1.0}})
	var rig := CameraRig.new()
	add_child(rig)
	assert_eq(rig.drift, 1.0, "the game's drift")
	for i in 80:
		rig._breathe(0.1)
	assert_true(rig.drift_shown() > 0.95, "breathing after standing still (%.2f)" % rig.drift_shown())
	rig.global_position += Vector3(1, 0, 0)
	rig._breathe(0.1)
	assert_eq(rig.drift_shown(), 0.0, "settled as soon as the party moves")
	rig.free()


func test_a_sweep_starts_off_the_heading_and_comes_round() -> void:
	var rig := CameraRig.new()
	add_child(rig)
	rig.sweep(30.0, 0.2)
	assert_eq(rig.sweep_deg, 30.0, "starts off its heading")
	await get_tree().create_timer(0.3).timeout
	assert_eq(rig.sweep_deg, 0.0, "comes round onto it")
	rig.free()
