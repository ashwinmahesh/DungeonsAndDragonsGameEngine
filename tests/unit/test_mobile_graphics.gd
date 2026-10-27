extends TestCase
## A saved desktop High setting or the Classic finish must not enable effects absent from Mobile.


func test_every_mobile_preset_clamps_unsupported_effects_without_mutating_desktop() -> void:
	var presets: Array[Dictionary] = [Graphics.CLASSIC]
	for key: String in Graphics.PRESETS:
		presets.append(Graphics.SPECS[key] as Dictionary)
	for source in presets:
		var before := source.duplicate(true)
		var mobile := Graphics.for_renderer(source, true)
		for key: String in ["ao", "bounce"]:
			assert_eq(int(mobile[key]), -1, key)
		for key: String in ["haze", "reflections", "swaying"]:
			assert_eq(int(mobile[key]), 0, key)
		assert_false(bool(mobile["sun_soft"]))
		assert_true(int(mobile["lamp_atlas"]) <= 2048)
		assert_true(int(mobile["sun_map"]) <= 2048)
		assert_true(int(mobile["lamp_shadows"]) <= 2)
		assert_eq(source, before, "mobile keeps the shared desktop presets intact")
		assert_eq(Graphics.for_renderer(source, false), before, "Forward+ keeps every setting")


func test_mobile_bounds_fill_cost_even_with_a_saved_desktop_high_setting() -> void:
	for key: String in Graphics.PRESETS:
		var source := (Graphics.SPECS[key] as Dictionary).duplicate(true)
		var mobile := Graphics.for_renderer(source, true)
		assert_eq(int(mobile["msaa"]), Viewport.MSAA_DISABLED)
		assert_eq(int(mobile["edge_aa"]), Viewport.SCREEN_SPACE_AA_FXAA)
		assert_true(float(mobile["scale"]) <= 0.75)
		assert_eq(Graphics.for_renderer(source, false), source, "desktop keeps its selected quality")


func test_retina_world_budget_uses_physical_pixels_and_preserves_smaller_requests() -> void:
	for pixels: Vector2i in [Vector2i(2532, 1170), Vector2i(1170, 2532), Vector2i(2732, 2064), Vector2i(2048, 1536), Vector2i(844, 390)]:
		var scale := Graphics.world_scale(1.0, pixels, true)
		assert_true(float(pixels.x) * pixels.y * scale * scale <= Graphics.MOBILE_WORLD_PIXELS + 1.0, str(pixels))
		assert_true(scale <= 0.75)
		assert_eq(Graphics.world_scale(1.0, pixels, false), 1.0, "desktop is never subject to the phone/tablet budget")
	assert_eq(Graphics.world_scale(0.4, Vector2i(2532, 1170), true), 0.4, "an already cheaper capture stays cheaper")
	assert_eq(Graphics.world_scale(1.0, Vector2i.ZERO, true), 0.75, "background geometry cannot divide by zero")


func test_mobile_capabilities_apply_to_capture_overrides_too() -> void:
	var source := (Graphics.SPECS["low"] as Dictionary).duplicate()
	source.merge({"haze": 64, "reflections": 64, "bounce": 3, "sun_soft": true}, true)
	var mobile := Graphics.for_renderer(source, true)
	assert_eq(int(mobile["haze"]), 0)
	assert_eq(int(mobile["reflections"]), 0)
	assert_eq(int(mobile["bounce"]), -1)


func test_simulator_blended_ground_reserves_texture_units_without_changing_desktop_or_device() -> void:
	var desktop := Look.blend_shader(false)
	var software := Look.blend_shader(true)
	assert_eq(desktop, Look.LIT_BLEND_SHADER, "desktop/device keep the original shader resource")
	assert_true(software != desktop, "the constrained shader is isolated to the software simulator")
	assert_eq(Look.blend_shader(true), software, "all ground patches share one compiled variant")
	var full: Array[String] = []
	var limited: Array[String] = []
	for uniform: Dictionary in desktop.get_shader_uniform_list():
		full.append(str(uniform["name"]))
	for uniform: Dictionary in software.get_shader_uniform_list():
		limited.append(str(uniform["name"]))
	for k: String in ["a", "b", "c", "d"]:
		assert_true("orm_" + k in full, "desktop/device retain their ORM texture")
		assert_false("orm_" + k in limited, "the simulator omits four sampler bindings")
		for prefix: String in ["albedo_", "normal_", "tile_", "tint_", "light_", "layers_"]:
			assert_true(prefix + k in limited, "all painted layers, scale, normals and light values remain")
	for shared: String in ["control", "grid_size", "difficult", "macro_tex"]:
		assert_true(shared in limited, "the simulator keeps blended edges, difficult ground and macro texture")
	assert_eq(Look.blend_shader(false), desktop, "building the simulator shader never replaces the original")
