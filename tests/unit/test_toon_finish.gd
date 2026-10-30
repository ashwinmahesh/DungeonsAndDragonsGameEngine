extends TestCase
## The Toon finish (plan E27): a third finish beside Modern and Classic, offered only by a game that names it in
## data/campaign.json ("finishes"), drawn on Modern's natural world with hard light bands and ink on the world.

var _was := ""


func before_each() -> void:
	_was = Look.style()


func after_each() -> void:
	Campaign.use_config(null)
	Look.forget_toon_settings()
	Look.set_style(_was, false)


func test_a_game_that_names_no_finishes_offers_modern_and_classic() -> void:
	Campaign.use_config({"module": "res://nowhere.gd"})
	assert_eq(Look.finishes(), [Look.DEFAULT_STYLE, "classic"] as Array[String], "the two finishes, Modern first")


func test_a_game_names_its_finishes_its_default_first() -> void:
	Campaign.use_config({"finishes": ["toon", "modern", "classic", "sepia", "toon"]})
	assert_eq(Look.finishes(), ["toon", "modern", "classic"] as Array[String], "known finishes, once each, in its order")


func test_toon_is_drawn_on_the_modern_world() -> void:
	Look.set_style("toon", false)
	assert_true(Look.toon(), "toon")
	assert_true(Look.modern(), "the natural, lit world (shores, woods, haze, bloom) is Modern's")
	assert_eq(float(Look.LOOK_SOFT[Look.style()]), 2.0, "the shaders read Toon (look_soft)")
	Look.set_style("modern", false)
	assert_false(Look.toon(), "Modern is not Toon")
	assert_eq(float(Look.LOOK_SOFT[Look.style()]), 1.0, "Modern's soft light as before")


func test_the_screen_pass_inks_the_world_only_in_toon() -> void:
	var post := Look.make_post_process()
	var mat := (post.mesh as QuadMesh).material as ShaderMaterial
	Look.set_style("modern", false)
	Look.style_post(mat)
	assert_false(bool(mat.get_shader_parameter("outlines")), "Modern draws no ink on the world")
	Look.set_style("toon", false)
	Look.style_post(mat)
	assert_true(bool(mat.get_shader_parameter("outlines")), "Toon inks the world")
	assert_true(bool(mat.get_shader_parameter("outline_ink")), "with the smooth, screen-sized ink")
	assert_false(bool(mat.get_shader_parameter("quantize")), "no palette snap")
	assert_true(bool(mat.get_shader_parameter("keep_hdr")), "flames and lanterns still bloom")
	post.free()


func test_godot_lit_shaders_take_toon_light_in_toon_only() -> void:
	var foliage := load("res://addons/dnd_core/shaders/atmosphere/foliage.gdshader") as Shader
	Campaign.use_config({"toon": {"bands": 3}})   # banded light, whatever the host game's own Toon asks
	Look.forget_toon_settings()
	Look.set_style("modern", false)
	assert_eq(Look.toon_shader(foliage), foliage, "Modern keeps the shader")
	Look.set_style("toon", false)
	var toon := Look.toon_shader(foliage)
	assert_ne(toon, foliage, "a variant")
	assert_true(toon.code.contains("diffuse_toon") and toon.code.contains("specular_toon"), "toon light")
	assert_false(toon.code.contains("diffuse_lambert_wrap"), "its own diffuse replaced")
	assert_true(toon.code.contains("world_vertex_coords") and toon.code.contains("cull_disabled"), "its other modes kept")
	assert_eq(Look.toon_shader(foliage), toon, "made once")


func test_settings_offers_the_games_finishes() -> void:
	Campaign.use_config({"finishes": ["toon", "modern", "classic"]})
	for f: String in Look.finishes():
		assert_true(Look.STYLE_NAMES.has(f) and Look.STYLE_TIPS.has(f), "%s is named and explained" % f)


func test_a_game_tunes_the_finish_in_its_data() -> void:
	Campaign.use_config({"toon": {"bands": 2, "flat": 0.4, "ink_width": 3.0, "nonsense": 1}})
	Look.forget_toon_settings()
	var t := Look.toon_settings()
	assert_eq(int(t["bands"]), 2, "its band count")
	assert_eq(float(t["flat"]), 0.4, "its flatness")
	assert_eq(float(t["vivid"]), float(Look.TOON["vivid"]), "the rest are the engine's")
	assert_false(t.has("nonsense"), "unknown keys are left out")
	Look.set_style("toon", false)
	var m := Look.cel("bone")
	assert_eq(int(m.get_shader_parameter("toon_band_count")), 2, "materials carry the bands")
	assert_between((m.get_shader_parameter("toon_fills") as Vector3).x, 0.399, 0.401, "and the flatness")


func test_a_painted_world_has_no_ink_and_soft_light() -> void:
	Campaign.use_config({"toon": {"bands": 0, "ink_strength": 0.0}})
	Look.forget_toon_settings()
	Look.set_style("toon", false)
	var post := Look.make_post_process()
	var mat := (post.mesh as QuadMesh).material as ShaderMaterial
	Look.style_post(mat)
	assert_false(bool(mat.get_shader_parameter("outlines")), "no ink on the world: only the characters keep theirs")
	var foliage := load("res://addons/dnd_core/shaders/atmosphere/foliage.gdshader") as Shader
	assert_eq(Look.toon_shader(foliage), foliage, "soft light keeps Godot's own on the trees")
	post.free()
