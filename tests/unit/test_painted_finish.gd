extends TestCase
## A game's painted finish (Look.PAINTED, PaintedFinish): gouache strokes and values, the boughs' shadows, the moon in
## the water, and strings of lantern bulbs (LightString). Off by default, so a game that names none looks as before.

## Any picture will do for the moon's face.
const FACE := "res://addons/dnd_core/art/ui/corner.png"

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


func test_a_game_paints_its_own_moon() -> void:
	Campaign.use_config({"module": "res://nowhere.gd"})
	var mat := _post()
	PaintedFinish.apply(mat, Look.painted_settings())
	assert_false(bool(mat.get_shader_parameter("sky_moon_has_face")), "the plain disc by default")
	Campaign.use_config({"painted": {"moon_face": FACE, "moon_face_size": 0.2}})
	PaintedFinish.apply(mat, Look.painted_settings())
	assert_true(bool(mat.get_shader_parameter("sky_moon_has_face")), "its own moon")
	assert_true(mat.get_shader_parameter("sky_moon_face") is Texture2D, "from its picture")
	assert_eq(_f(mat, "sky_moon_face_size"), 0.2, "at its size")
	Campaign.use_config({"painted": {"moon_face": "res://nowhere/moon.png"}})
	PaintedFinish.apply(mat, Look.painted_settings())
	assert_false(bool(mat.get_shader_parameter("sky_moon_has_face")), "a missing picture keeps the disc")


func test_a_close_strike_flashes_a_cut_out() -> void:
	var a := Atmosphere.new()
	a.painted = Look.painted_settings({"lightning_cutout": 0.9})
	var mat := _post()
	a.set("_post", mat)
	a.set("_flash", 1.0)
	a._flash_cutout()
	assert_eq(_f(mat, "flash_silhouette"), 0.9, "the strike's first instant")
	a.set("_flash", 0.5)
	a._flash_cutout()
	assert_eq(_f(mat, "flash_silhouette"), 0.0, "gone as the flash fades")
	a.free()


func test_the_nearest_figures_are_handed_on_walking_or_standing() -> void:
	var figures: Array[Node3D] = []
	for i in 10:
		var n := Node3D.new()
		add_child(n)
		n.global_position = Vector3(float(i), 0.0, 0.0)
		figures.append(n)
	var last := {}
	var feet := FigureWake.feet_of(figures, last, 0.1, Vector3.ZERO)
	assert_eq(feet.size(), FigureWake.MAX, "at most eight")
	assert_eq(feet[0].x, 0.0, "the nearest first")
	assert_eq(feet[0].w, 0.0, "standing at first sight")
	figures[0].global_position = Vector3(0.0, 0.0, 0.2)
	feet = FigureWake.feet_of(figures, last, 0.1, Vector3.ZERO)
	assert_eq(feet[0].w, 1.0, "walking once it moves")
	assert_eq(feet[1].w, 0.0, "the rest still standing")
	for n in figures:
		n.free()


func test_wakes_and_parting_plants_only_when_the_game_asks() -> void:
	Campaign.use_config({"module": "res://nowhere.gd"})
	var a := Atmosphere.new()
	add_child(a)
	assert_true(FigureWake.build(a, Look.painted_settings()) == null, "none by default")
	var w := FigureWake.build(a, Look.painted_settings({"wakes": 1.0}))
	assert_true(w != null and w.get_parent() == a, "rings in the water when asked")
	a.free()


func test_a_lit_window_throws_its_panes_outside() -> void:
	var s := AtmosphereWeather.window_frame_light(Vector3(0, 0, 1), 1.0)
	assert_true(s.light_projector != null, "through a picture of the frame")
	var aim := -s.basis.z
	assert_true(aim.z > 0.3 and aim.y < -0.3, "out of the house and down onto the ground (%s)" % aim)
	assert_false(s.shadow_enabled, "no shadow map of its own")
	s.free()


func test_bats_flit_low_over_a_place() -> void:
	var parent := Node3D.new()
	add_child(parent)
	var w := AtmosphereWeather.new()
	w._parent = parent
	w._crows({"amount": 6}, true)
	var b := parent.get_node_or_null("Bats") as MultiMeshInstance3D
	assert_true(b != null, "a flock of bats")
	assert_eq(b.multimesh.instance_count, 6, "as many as asked")
	assert_true(b.position.y < 7.5, "lower than the crows")
	assert_true(bool((b.multimesh.mesh.surface_get_material(0) as ShaderMaterial).get_shader_parameter("bat")), "bat-winged")
	assert_true(b in w.follow, "they follow the camera")
	parent.free()
