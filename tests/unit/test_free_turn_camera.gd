extends TestCase
## Free turning (a campaign's "camera": {"free_turn": true}): the camera turns to any heading, smoothly or by a drag,
## and the sprites pick their frame from the real heading. A game that says nothing turns in quarter turns.


func before_each() -> void:
	InputActions.ensure()


func after_each() -> void:
	Campaign.use_config(null)


func _rig() -> CameraRig:
	var rig := CameraRig.new()
	add_child(rig)
	rig.snap_to_target()
	return rig


func _press(rig: CameraRig, action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	rig._unhandled_input(ev)


func test_quarter_turns_without_the_setting() -> void:
	Campaign.use_config({})
	var rig := _rig()
	assert_false(rig.free_turn, "quarter turns")
	_press(rig, &"camera_rotate_right")
	rig.snap_to_target()
	assert_between(rad_to_deg(rig.rotation.y), 134.9, 135.1, "a quarter turn on a press")
	rig.free()


func test_free_turning_reaches_any_heading() -> void:
	Campaign.use_config({"camera": {"free_turn": true}})
	var rig := _rig()
	assert_true(rig.free_turn, "free turning")
	_press(rig, &"camera_rotate_right")
	rig.snap_to_target()
	assert_between(rad_to_deg(rig.rotation.y), 44.9, 45.1, "a press alone doesn't jump a quarter turn")
	rig.turn_by(30.0)
	rig.snap_to_target()
	assert_between(rad_to_deg(rig.rotation.y), 74.9, 75.1, "turned 30 degrees")
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	drag.relative = Vector2(100, 0)
	rig._unhandled_input(drag)
	rig.snap_to_target()
	assert_between(rad_to_deg(rig.rotation.y), 74.9 + 100 * CameraRig.DRAG_TURN, 75.1 + 100 * CameraRig.DRAG_TURN, "dragged with the middle button")
	rig.free()


func test_sprites_pick_their_frame_at_any_heading() -> void:
	# A figure facing north, seen from a camera turned in 10 degree steps: the frame turns with the heading, the nearest
	# of the eight each time.
	var seen := {}
	for step in 36:
		var cam := Basis(Vector3.UP, deg_to_rad(step * 10.0)) * Basis(Vector3.RIGHT, deg_to_rad(-30.0))
		seen[DirectionalSprite.direction_for(Vector3(0, 0, -1), cam)] = true
	assert_eq(seen.size(), 8, "all eight frames come round")


func test_tilt_stays_in_the_campaigns_range() -> void:
	Campaign.use_config({"camera": {"pitch": 30, "free_turn": true, "tilt": [22, 38]}})
	var rig := _rig()
	assert_eq(rig.tilt_range, Vector2(22, 38), "the range")
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	drag.relative = Vector2(0, 1000)
	rig._unhandled_input(drag)
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -38.01, -37.99, "dragged down, no steeper than 38")
	drag.relative = Vector2(0, -2000)
	rig._unhandled_input(drag)
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -22.01, -21.99, "dragged up, no flatter than 22")
	rig.free()


func test_no_tilt_without_the_setting() -> void:
	Campaign.use_config({"camera": {"pitch": 30, "free_turn": true}})
	var rig := _rig()
	rig.tilt_by(10.0)
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -30.01, -29.99, "the pitch stays")
	rig.free()


func _held(action: StringName) -> void:
	Input.action_press(action)


func test_tilt_keys_held_tilt_within_the_range() -> void:
	Campaign.use_config({"camera": {"pitch": 40, "tilt": [30, 50]}})
	var rig := _rig()
	_held(&"camera_tilt_down")
	rig._process(10.0)
	Input.action_release(&"camera_tilt_down")
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -50.01, -49.99, "held down, no steeper than 50")
	_held(&"camera_tilt_up")
	rig._process(10.0)
	Input.action_release(&"camera_tilt_up")
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -30.01, -29.99, "held up, no flatter than 30")
	rig.free()


func test_tilt_keys_do_nothing_without_a_range() -> void:
	Campaign.use_config({"camera": {"pitch": 40}})
	var rig := _rig()
	_held(&"camera_tilt_down")
	rig._process(1.0)
	Input.action_release(&"camera_tilt_down")
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -40.01, -39.99, "the pitch stays")
	rig.free()


func test_reset_puts_the_angle_and_heading_back() -> void:
	Campaign.use_config({"camera": {"pitch": 40, "free_turn": true, "tilt": [30, 50]}})
	var rig := _rig()
	rig.rotate_step(-1)   # (a location view starts a quarter round)
	rig.turn_by(77.0)
	rig.tilt_by(9.0)
	_press(rig, &"camera_reset")
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -40.01, -39.99, "the campaign's pitch")
	assert_between(rad_to_deg(rig.rotation.y), -45.1, -44.9, "the heading the view started on")
	rig.free()


func test_the_tilt_keys_are_in_the_keys_page() -> void:
	var listed: Array[StringName] = []
	for c: Array in InputActions.COMMANDS:
		listed.append(c[0] as StringName)
	for a: StringName in [&"camera_tilt_up", &"camera_tilt_down", &"camera_reset"]:
		assert_true(a in listed, "%s can be rebound" % a)
		assert_true(InputMap.has_action(a), "%s is registered" % a)
