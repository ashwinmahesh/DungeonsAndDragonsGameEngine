extends TestCase
## A game's own sunbeams (data/campaign.json "sun_shafts", SunShafts.settings): a game that names none keeps the beams
## as the engine draws them; one that does gets fainter, wider, softer beams with fainter streaks, and fewer of them.


func after_each() -> void:
	Campaign.use_config(null)
	SunShafts.forget_settings()


func _use(own: Variant) -> void:
	var cfg := {"module": "res://nowhere.gd"}
	if own != null:
		cfg["sun_shafts"] = own
	Campaign.use_config(cfg)
	SunShafts.forget_settings()


## An open field w x d with a wood round its edge two squares deep, so every square inside has some shade round it.
func _clearing(w: int, d: int) -> CombatGrid:
	var g := CombatGrid.new(w, d)
	for z in d:
		for x in w:
			if x < 2 or z < 2 or x >= w - 2 or z >= d - 2 or (x % 6 == 0 and z % 6 == 0):
				g.set_flag(Vector2i(x, z), CombatGrid.WALL)
	return g


func test_a_game_that_names_none_keeps_the_beams() -> void:
	_use(null)
	assert_eq(SunShafts.settings(), SunShafts.SETTINGS, "the engine's beams")
	var m := SunShafts._material(0.5, false)
	assert_eq(float(m.get_shader_parameter("ray_amount")), 1.0, "streaks as drawn")
	assert_eq(float(m.get_shader_parameter("core_power")), 3.0, "edges as drawn")


func test_a_game_softens_its_own() -> void:
	_use({"strength": 0.6, "rays": 0.2, "soft": 2.0, "most": 4, "glare": 9})
	var s := SunShafts.settings()
	assert_eq(float(s["strength"]), 0.6, "its brightness")
	assert_eq(float(s["width"]), 1.0, "the rest the engine's")
	assert_false(s.has("glare"), "no unknown keys")
	var m := SunShafts._material(0.5, false)
	assert_between(float(m.get_shader_parameter("ray_amount")), 0.199, 0.201, "fainter streaks")
	assert_between(float(m.get_shader_parameter("core_power")), 5.999, 6.001, "sides fading further in")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var few := SunShafts.spots(_clearing(60, 60), rng).size()
	assert_true(few >= SunShafts.FEWEST and few <= 4, "no more than its most (%d)" % few)
	_use(null)
	rng.seed = 1
	assert_true(SunShafts.spots(_clearing(60, 60), rng).size() > 4, "the engine's would have more")
