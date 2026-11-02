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


func test_a_trackpad_pinches_to_zoom_and_swipes_to_turn() -> void:
	Campaign.use_config({"camera": {"free_turn": true}})
	var rig := _rig()
	var start := rig.distance
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.25
	rig._unhandled_input(pinch)
	assert_between(rig.distance, start / 1.25 - 0.01, start / 1.25 + 0.01, "pinching out zooms in")
	var swipe := InputEventPanGesture.new()
	swipe.delta = Vector2(5, 0)
	rig._unhandled_input(swipe)
	rig.snap_to_target()
	assert_between(rad_to_deg(rig.rotation.y), 45.0 + 5 * CameraRig.PAN_TURN - 0.1, 45.0 + 5 * CameraRig.PAN_TURN + 0.1,
		"a swipe across turns it")
	var before := rig.distance
	swipe.delta = Vector2(0, 2)
	rig._unhandled_input(swipe)
	assert_between(rig.distance, before + 2 * CameraRig.PAN_ZOOM - 0.01, before + 2 * CameraRig.PAN_ZOOM + 0.01, "a swipe down zooms out")
	rig.free()


func test_a_game_of_3d_figures_tilts_from_the_ground_to_straight_down() -> void:
	Campaign.use_config({"camera": {"pitch": 30, "free_turn": true, "tilt": [10, 85]}})
	var rig := _rig()
	assert_eq(rig.tilt_range, Vector2(10, 85), "a wide range is kept, not squeezed into the sprites' pitch range")
	rig.tilt_by(200.0)
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -85.01, -84.99, "tilted down, no steeper than 85")
	rig.tilt_by(-200.0)
	rig.snap_to_target()
	assert_between(rig.camera.rotation_degrees.x, -10.01, -9.99, "tilted up, no flatter than 10")
	Campaign.use_config({"camera": {"tilt": [0, 120]}})
	assert_eq(CameraRig.tilt_limits(), CameraRig.TILT_RANGE, "never under the ground or past straight down")
	rig.free()


func test_a_fight_keeps_the_view_steep_enough_for_the_grid() -> void:
	Campaign.use_config({"camera": {"pitch": 30, "free_turn": true, "tilt": [10, 85], "fight_tilt": 25}})
	assert_eq(CameraRig.fight_floor(), 25.0, "the campaign's floor")
	var rig := _rig()
	rig.tilt_by(-200.0)
	assert_eq(rig.pitch_deg, -10.0, "exploring, it goes as low as the game allows")
	rig.tilt_floor = CameraRig.fight_floor()
	rig._process(2.0)
	assert_eq(rig.pitch_deg, -25.0, "a fight eases it up to its floor")
	rig.tilt_by(-200.0)
	assert_eq(rig.pitch_deg, -25.0, "and the player can't tilt under it")
	rig.tilt_by(100.0)
	assert_eq(rig.pitch_deg, -85.0, "but can still look straight down")
	rig.tilt_floor = 0.0
	rig.tilt_by(-200.0)
	assert_eq(rig.pitch_deg, -10.0, "after the fight, low again")
	Campaign.use_config({"camera": {"pitch": 30, "fight_tilt": 25}})
	assert_eq(CameraRig.fight_floor(), 0.0, "no tilt, no floor")
	rig.free()


func test_indoors_the_camera_stays_above_the_walls() -> void:
	Campaign.use_config({"camera": {"pitch": 30, "free_turn": true, "tilt": [10, 85], "fight_tilt": 25, "indoor_tilt": 35}})
	assert_eq(CameraRig.indoor_floor(), 35.0, "the campaign's indoor floor")
	var rig := _rig()
	rig.place_floor = CameraRig.indoor_floor()
	rig._process(2.0)
	assert_eq(rig.pitch_deg, -35.0, "arriving inside on a flat view, it eases up to the floor")
	rig.tilt_floor = CameraRig.fight_floor()
	rig.tilt_by(-200.0)
	assert_eq(rig.pitch_deg, -35.0, "a fight inside keeps the steeper of the two")
	rig.free()


func test_the_free_camera_leaves_the_party_and_comes_back() -> void:
	Campaign.use_config({"camera": {"pitch": 30, "free_turn": true, "free_move": true}})
	var rig := _rig()
	var party := Node3D.new()
	add_child(party)
	party.global_position = Vector3(5, 0, 5)
	rig.follow = party
	rig.bounds = Rect2(0, 0, 10, 10)
	rig.snap_to_target()
	var told: Array[bool] = []
	rig.free_changed.connect(func(on: bool) -> void: told.append(on))
	rig.toggle_free()
	assert_true(rig.free_cam, "on")
	Input.action_press(&"move_right")
	for i in 60:
		rig._process(0.1)
	Input.action_release(&"move_right")
	assert_true(rig.global_position.distance_to(party.global_position) > 3.0, "the walking keys moved the camera off the party")
	assert_between(rig.global_position.x, -0.01, 10.01, "kept over the place")
	assert_between(rig.global_position.z, -0.01, 10.01, "kept over the place")
	rig.toggle_free()
	for i in 60:
		rig._process(0.1)
	assert_true(rig.global_position.distance_to(party.global_position) < 0.05, "off, it comes back to the party")
	assert_eq(told, [true, false] as Array[bool], "it says when it goes on and off")
	party.free()
	rig.free()


func test_no_free_camera_without_the_setting() -> void:
	Campaign.use_config({"camera": {"pitch": 30}})
	var rig := _rig()
	rig.toggle_free()
	assert_false(rig.free_cam, "a game without free_move keeps the camera on the party")
	rig.free()
