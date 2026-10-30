extends TestCase
## A game's painted finish (Look.PAINTED, PaintedFinish): gouache strokes and values, the boughs' shadows, the moon in
## the water, and strings of lantern bulbs (LightString). Off by default, so a game that names none looks as before.

var _was := ""
var _preset := ""


func before_each() -> void:
	_was = Look.style()
	_preset = Graphics.preset()
	Look.set_style("modern", false)


func after_each() -> void:
	Campaign.use_config(null)
	Look.set_style(_was, false)
	Graphics.set_preset(_preset, false)


func _post() -> ShaderMaterial:
	var post := Look.make_post_process()
	var mat := (post.mesh as QuadMesh).material as ShaderMaterial
	post.free()
	return mat


func _f(mat: ShaderMaterial, n: String) -> float:
	var v: Variant = mat.get_shader_parameter(n)   # null: never set, the shader's own default
	return 0.0 if v == null else float(v)


func test_a_game_that_names_none_keeps_the_picture() -> void:
	Campaign.use_config({"module": "res://nowhere.gd"})
	var mat := _post()
	PaintedFinish.apply(mat, Look.painted_settings())
	for n: String in ["paint_amount", "paint_ramp_amount", "paint_brush", "paint_edges", "paint_lines", "paint_black",
			"branch_strength", "moon_water"]:
		assert_eq(_f(mat, n), 0.0, "%s off" % n)


func test_the_game_sets_it_and_a_mood_changes_it() -> void:
	Campaign.use_config({"painted": {"strokes": 0.6, "ramp": ["void", "wick"], "ramp_amount": 0.7, "sparkle": 3}})
	var s := Look.painted_settings({"ramp_amount": 0.2, "boughs": 0.5})
	assert_eq(float(s["strokes"]), 0.6, "the game's strokes")
	assert_eq(float(s["ramp_amount"]), 0.2, "the mood's own over the game's")
	assert_eq(float(s["boughs"]), 0.5, "the mood's boughs")
	assert_eq(float(s["edges"]), float(Look.PAINTED["edges"]), "the rest from the engine")
	assert_false(s.has("sparkle"), "no unknown keys")
	var mat := _post()
	PaintedFinish.apply(mat, s)
	assert_eq(_f(mat, "paint_ramp_amount"), 0.2, "the ramp drawn")
	assert_true(mat.get_shader_parameter("paint_ramp") is GradientTexture1D, "through the game's colours")
	assert_eq(_f(mat, "branch_strength"), 0.5, "the boughs' shadows")
	assert_true(mat.get_shader_parameter("branch_tex") is ImageTexture, "from the engine's own boughs")


func test_brush_strokes_only_on_high() -> void:
	Campaign.use_config({"painted": {"strokes": 0.6, "ramp": ["void", "wick"], "ramp_amount": 0.7}})
	var mat := _post()
	Graphics.set_preset("medium", false)
	PaintedFinish.apply(mat, Look.painted_settings())
	assert_eq(_f(mat, "paint_amount"), 0.0, "no strokes on Medium")
	assert_eq(_f(mat, "paint_ramp_amount"), 0.7, "but its values and colours")
	Graphics.set_preset("high", false)
	PaintedFinish.apply(mat, Look.painted_settings())
	assert_eq(_f(mat, "paint_amount"), 0.6, "strokes on High")


func test_classic_draws_none_of_it() -> void:
	Campaign.use_config({"painted": {"strokes": 0.6, "ramp": ["void", "wick"], "ramp_amount": 0.7, "boughs": 0.5}})
	Look.set_style("classic", false)
	var mat := _post()
	PaintedFinish.apply(mat, Look.painted_settings())
	for n: String in ["paint_amount", "paint_ramp_amount", "branch_strength"]:
		assert_eq(_f(mat, n), 0.0, "%s off in Classic" % n)


func test_the_moon_lies_in_the_water_the_camera_sees_at_night() -> void:
	Campaign.use_config({"painted": {"moon_water": 1.5}})
	var s := Look.painted_settings()
	var mat := _post()
	PaintedFinish.apply(mat, s)
	var cam := Camera3D.new()
	add_child(cam)
	cam.rotation_degrees = Vector3(-30, 45, 0)
	mat.set_shader_parameter("sky_moon", 0.0)
	PaintedFinish.aim_moon(mat, s, cam)
	assert_eq(_f(mat, "moon_water"), 0.0, "no moon in the sky, none in the water")
	mat.set_shader_parameter("sky_moon", 1.0)
	PaintedFinish.aim_moon(mat, s, cam)
	assert_eq(_f(mat, "moon_water"), 1.5, "the moon out, in the water")
	var d := mat.get_shader_parameter("moon_water_dir") as Vector3
	assert_true(d.y > 0.3, "up in the sky, where the camera's gaze bounces off the water")
	cam.free()


func test_a_string_of_bulbs_lights_a_few_lamps() -> void:
	var parent := Node3D.new()
	add_child(parent)
	var s := LightString.hang(parent, Vector3(0, 2, 0), Vector3(6, 2, 0), func(_p: Vector3) -> float: return 0.0)
	var lights := s.find_children("*", "OmniLight3D", true, false)
	var bulbs := 0
	for m in s.find_children("*", "MultiMeshInstance3D", true, false):
		if (m as MultiMeshInstance3D).multimesh.mesh is SphereMesh:
			bulbs = (m as MultiMeshInstance3D).multimesh.instance_count
	assert_true(bulbs >= 10, "a bulb every half square or so (%d)" % bulbs)
	assert_true(lights.size() >= 2 and lights.size() <= bulbs / 4, "one real light in several bulbs (%d)" % lights.size())
	for l in lights:
		assert_eq(str(l.get_meta("light_kind")), "lantern", "a lantern to the atmosphere")
		assert_true(bool(l.get_meta("no_shadow")), "kept out of the lamp shadows")
	assert_eq(s.find_children("*", "Decal", true, false).size(), bulbs, "a pool of light under every bulb")
	parent.free()
