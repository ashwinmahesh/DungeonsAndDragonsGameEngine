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
