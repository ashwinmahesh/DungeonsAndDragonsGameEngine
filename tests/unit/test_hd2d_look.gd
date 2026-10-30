extends TestCase
## The HD-2D options a game turns on under data/campaign.json's "hd2d" (Look.HD2D): depth of field and tilt-shift,
## bloom, brighter lamps and drifting motes of light. Off by default, so a game that names none looks as before.

var _was := ""


func before_each() -> void:
	_was = Look.style()


func after_each() -> void:
	Campaign.use_config(null)
	Look.set_style(_was, false)


func test_a_game_that_names_none_keeps_the_picture() -> void:
	Campaign.use_config({"module": "res://nowhere.gd"})
	var h := Look.hd2d_settings()
	assert_eq(float(h["focus"]), 0.0, "no depth of field")
	assert_eq(float(h["tilt_shift"]), 0.0, "no tilt-shift")
	assert_eq(float(h["bloom"]), 1.0, "the engine's glow")
	assert_eq(float(h["bloom_threshold"]), 0.9, "blooming from the same brightness")
	assert_eq(float(h["bloom_spread"]), 0.02, "the same soft wash")
	for k: String in ["lamp_energy", "lamp_reach", "lamp_haze"]:
		assert_eq(float(h[k]), 1.0, "%s as before" % k)
	assert_eq(int(h["motes"]), 0, "no motes")
	for k: String in ["focus_fight", "focus_talk", "bloom_wide"]:
		assert_eq(float(h[k]), 1.0, "%s as before" % k)


func test_a_game_sets_its_own_and_unknown_keys_are_left_out() -> void:
	Campaign.use_config({"hd2d": {"focus": 0.8, "tilt_shift": 0.5, "motes": 30, "sparkle": 9}})
	var h := Look.hd2d_settings()
	assert_eq(float(h["focus"]), 0.8, "its depth of field")
	assert_eq(float(h["tilt_shift"]), 0.5, "its tilt-shift")
	assert_eq(int(h["motes"]), 30, "its motes")
	assert_eq(float(h["focus_range"]), float(Look.HD2D["focus_range"]), "the rest from the engine")
	assert_false(h.has("sparkle"), "no unknown keys")


func test_the_screen_pass_starts_with_focus_and_tilt_off() -> void:
	var post := Look.make_post_process()
	var mat := (post.mesh as QuadMesh).material as ShaderMaterial
	for n: String in ["focus_blur", "tilt_shift"]:
		var v: Variant = mat.get_shader_parameter(n)   # null: never set, the shader's own 0
		assert_true(v == null or float(v) == 0.0, "%s off" % n)
	post.free()


func test_motes_drift_and_glow() -> void:
	var parent := Node3D.new()
	add_child(parent)
	var w := AtmosphereWeather.new()
	w._parent = parent
	w._motes({"amount": 25, "core": "void", "rim": "void", "night_only": true})
	var p := parent.get_node_or_null("Motes") as GPUParticles3D
	assert_true(p != null, "a cloud of motes")
	assert_eq(p.amount, 25, "as many as asked")
	assert_true(p in w.follow, "they follow the camera")
	assert_true(p in w.night_only, "only after dark when asked")
	var mat := (p.draw_pass_1 as QuadMesh).material as ShaderMaterial
	assert_true(bool(mat.get_shader_parameter("glow")), "they glow in the dark")
	parent.free()


func test_moths_flutter_round_the_lamps_not_the_fires() -> void:
	var view := Node3D.new()
	add_child(view)
	var lamp := CandleFlicker.new()
	lamp.light_color = Look.color("candle")
	lamp.position = Vector3(2, 1, 3)
	view.add_child(lamp)
	var fire := CandleFlicker.new()
	fire.light_color = Look.color("flame")
	view.add_child(fire)
	var w := AtmosphereWeather.new()
	w._parent = view
	w._moths(view, {"amount": 4})
	var moths := view.find_children("Moths*", "GPUParticles3D", true, false)
	assert_eq(moths.size(), 1, "one swarm, at the lamp only")
	assert_eq((moths[0] as GPUParticles3D).amount, 4, "as many as asked")
	assert_eq((moths[0] as Node3D).position, lamp.position, "at the lamp")
	view.free()
