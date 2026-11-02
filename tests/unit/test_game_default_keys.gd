extends TestCase
## A game's own default keys (data/campaign.json "keys"): they take the place of the engine's for the actions they
## name, the Keys page resets to them, and the rest keep the engine's.


func after_each() -> void:
	Campaign.use_config(null)
	InputActions.apply()


func test_a_game_gives_wasd_to_the_camera() -> void:
	Campaign.use_config({"keys": {"move_forward": ["Up"], "move_back": ["Down"], "move_left": ["Left"],
		"move_right": ["Right"], "camera_rotate_left": ["A", "Q"], "camera_tilt_up": ["W", "PageUp"]}})
	assert_eq(InputActions.keys_default(&"move_forward"), [KEY_UP, KEY_NONE] as Array[int], "walking forward is the up arrow")
	assert_eq(InputActions.keys_default(&"camera_rotate_left"), [KEY_A, KEY_Q] as Array[int], "A turns the camera, Q too")
	assert_eq(InputActions.keys_default(&"camera_tilt_up"), [KEY_W, KEY_PAGEUP] as Array[int], "W tilts it up")
	assert_eq(InputActions.keys_default(&"camera_rotate_right"), [KEY_E, KEY_NONE] as Array[int], "an action it doesn't name keeps the engine's")
	assert_eq(InputActions.fill("{walk} walk"), "the arrows walk", "the controls card says the arrows walk")
	InputActions.apply()
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	assert_true(InputMap.action_has_event(&"camera_tilt_up", w), "W is on the tilt")
	assert_false(InputMap.action_has_event(&"move_forward", w), "and not on walking")


func test_without_its_own_keys_a_game_has_the_engines() -> void:
	Campaign.use_config({})
	assert_eq(InputActions.keys_default(&"move_forward"), [KEY_W, KEY_UP] as Array[int], "W walks, as before")
	assert_eq(InputActions.keys_default(&"camera_rotate_left"), [KEY_Q, KEY_NONE] as Array[int], "Q turns the camera")
