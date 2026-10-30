extends TestCase
## Game feel (GameFeel, Visual Polish Plan E39-E41 and the AI methods report's FX1/FX2): a game that names no
## "game_feel" plays as before; one that does gets a hit-stop by weight, a camera kick that springs back, a slow beat on
## crits and kills, a white flash and a sway on its figures, brighter spell lights and drawn shapes on twos.


func after_each() -> void:
	GameFeel.use(null)
	Campaign.use_config(null)
	CombatImpact.headless_too = false
	Engine.time_scale = 1.0


func test_defaults_change_nothing() -> void:
	GameFeel.use({})
	assert_false(GameFeel.stops(), "no hit-stop table: the engine's one heavy freeze")
	assert_eq(GameFeel.stop_seconds("heavy"), 0.0, "no stop")
	assert_eq(GameFeel.num("kick"), 0.0, "no kick")
	assert_eq(GameFeel.num("flash"), 0.0, "no flash")
	for k: String in ["knockback", "breath", "spell_light", "spell_reach"]:
		assert_eq(GameFeel.num(k), 1.0, "%s as it was" % k)
	assert_false(FxShapes.on(), "no shapes")


func test_unknown_keys_are_ignored() -> void:
	GameFeel.use({"kick": 0.2, "nonsense": 4})
	assert_eq(GameFeel.num("kick"), 0.2, "a known key is read")
	assert_false(GameFeel.settings().has("nonsense"), "an unknown key is dropped")


func test_a_blows_weight() -> void:
	assert_eq(GameFeel.weight(1, 40, false, false), "light", "a scratch")
	assert_eq(GameFeel.weight(6, 40, false, false), "medium", "a fair hit")
	assert_eq(GameFeel.weight(15, 40, false, false), "heavy", "a third of its Hit Points")
	assert_eq(GameFeel.weight(1, 40, true, false), "crit", "a critical hit")
	assert_eq(GameFeel.weight(1, 40, true, true), "kill", "a kill outweighs a critical hit")


func test_hit_stop_frames_by_weight() -> void:
	GameFeel.use({"hit_stop": {"light": 2, "heavy": 6, "kill": 10}})
	assert_true(GameFeel.stops(), "the game's table")
	assert_between(GameFeel.stop_seconds("light"), 2.0 / 60.0 - 0.001, 2.0 / 60.0 + 0.001, "two frames")
	assert_eq(GameFeel.stop_seconds("medium"), 0.0, "a weight it doesn't name stops nothing")
	assert_between(GameFeel.stop_seconds("crit"), 0.099, 0.101, "a crit it doesn't name stops as heavy")
	assert_between(GameFeel.stop_seconds("kill"), 0.166, 0.168, "ten frames")


func test_a_heavy_blow_stops_the_fight_by_the_table() -> void:
	GameFeel.use({"hit_stop": {"light": 3, "heavy": 6}})
	CombatImpact.headless_too = true
	var rig := CameraRig.new()
	add_child(rig)
	var impact := CombatImpact.new(rig)
	add_child(impact)
	var target := Node3D.new()
	add_child(target)
	impact.hit(target, 2, 40, false, false, false)
	assert_true(Engine.time_scale < 0.1, "even a light blow holds the fight with a table")
	impact.free()
	assert_eq(Engine.time_scale, 1.0, "time comes back when the view closes")
	target.free()
	rig.free()


func test_the_kick_springs_back() -> void:
	var rig := CameraRig.new()
	add_child(rig)
	rig.snap_to_target()
	rig.impulse(Vector2.RIGHT, 0.1)
	assert_between(rig.kick.x, -0.101, -0.099, "the camera moves against the way the picture is knocked")
	var crossed := false
	for i in 120:
		rig._shake(1.0 / 60.0)
		crossed = crossed or rig.kick.x > 0.0
	assert_true(crossed, "it overshoots a little")
	assert_between(rig.kick.length(), 0.0, 0.001, "and settles")
	assert_between(rig.camera.h_offset, -0.001, 0.001, "the view is back where it was")
	rig.free()


func test_screen_direction_of_a_blow() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 10))
	var d := GameFeel.screen_dir(cam, Vector3(-1, 0, 0), Vector3(1, 0, 0))
	assert_between(d.x, 0.99, 1.01, "a blow to the right goes right on the screen")
	assert_eq(GameFeel.screen_dir(cam, Vector3.INF, Vector3.ZERO), Vector2.ZERO, "no attacker, no direction")
	cam.free()


func test_figures_flash_and_sway_only_when_asked() -> void:
	var m := ShaderMaterial.new()
	m.shader = DirectionalSprite.CRISP
	var cam := Camera3D.new()
	add_child(cam)
	GameFeel.use({})
	SpriteFeel.apply(m, cam, 1.6, 0.0, 1.0)
	assert_eq(m.get_shader_parameter("feel_flash"), null, "untouched without a flash setting")
	GameFeel.use({"flash": 0.8, "sway": 0.05})
	SpriteFeel.set_place({"mist": {"wind": [1.0, 0.0]}}, true)
	SpriteFeel.apply(m, cam, 1.6, 0.3, 1.0)
	assert_between(float(m.get_shader_parameter("feel_flash")), 0.79, 0.81, "a struck figure flashes")
	var sway := m.get_shader_parameter("feel_sway") as Vector2
	assert_true(absf(sway.x) > 0.0, "a wind across the view leans the figure")
	SpriteFeel.set_place({"mist": {"wind": [1.0, 0.0]}}, false)
	SpriteFeel.apply(m, cam, 1.6, 0.3, 0.0)
	assert_eq(m.get_shader_parameter("feel_sway"), Vector2.ZERO, "still air indoors")
	cam.free()


func test_spell_lights_scale() -> void:
	var root := Node3D.new()
	add_child(root)
	GameFeel.use({"spell_reach": 2.0, "spell_shadows": true})
	var big := FxKit.flash(root, Vector3.ZERO, Color.ORANGE, 6.0, 3.0)
	var small := FxKit.flash(root, Vector3.ZERO, Color.ORANGE, 2.0, 3.0)
	assert_eq(big.omni_range, 6.0, "twice the reach")
	assert_true(big.shadow_enabled, "a big flash throws shadows")
	assert_false(small.shadow_enabled, "a small one doesn't")
	GameFeel.use({})
	var plain := FxKit.flash(root, Vector3.ZERO, Color.ORANGE, 6.0, 3.0)
	assert_eq(plain.omni_range, 3.0, "as it was")
	assert_false(plain.shadow_enabled, "no shadows")
	root.free()


func test_shapes_are_drawn_and_play_on_twos() -> void:
	for kind: String in FxShapes.KINDS:
		var img := FxShapes.drawn(kind)
		var solid := 0
		for y in range(0, FxShapes.SIDE, 8):
			for x in range(0, FxShapes.SIDE, 8):
				if img.get_pixel(x, y).a > 0.5:
					solid += 1
		assert_true(solid > 4, "%s has a shape" % kind)
		assert_true(solid < 900, "%s isn't a filled square" % kind)
	var root := Node3D.new()
	add_child(root)
	GameFeel.use({})
	assert_eq(FxShapes.play(root, "burst", Vector3.ZERO, {}), null, "off by default")
	GameFeel.use({"shapes": true, "shape_fps": 12.0})
	var mi := FxShapes.play(root, "burst", Vector3.ZERO, {"core": Color.WHITE, "glow": Color.ORANGE})
	assert_true(mi != null, "on when the game asks")
	root.free()


func test_spells_and_falls_mark_the_ground_through_ground_marks() -> void:
	assert_eq(SpellMarks.kind_for({"flavour": "fire"}), "scorch", "fire scorches")
	assert_eq(SpellMarks.kind_for({"flavour": "cold"}), "frost", "cold frosts")
	assert_eq(SpellMarks.kind_for({"flavour": "steel"}), "", "a plain blade leaves nothing")
	Campaign.use_config({"painted": {"marks": 6, "marks_fade": 0}})
	# A fight that closed freed the marks it left; the next fight still leaves its own.
	var gone := Node3D.new()
	add_child(gone)
	SpellMarks.spot(gone, {"flavour": "fire"}, Vector3.ZERO)
	gone.free()
	var parent := Node3D.new()
	add_child(parent)
	var before := GroundMarks.count()
	SpellMarks.spot(parent, {"flavour": "steel"}, Vector3.ZERO)
	SpellMarks.spot(parent, {"flavour": "cold"}, Vector3.ZERO)
	var body := Creature.new()
	body.creature_type = &"undead"
	var ghoul := Combatant.new(body, &"enemy", Vector2i.ZERO)
	SpellMarks.fall(parent, ghoul, Vector3(1, 0, 0))
	await get_tree().process_frame
	if Look.modern():
		assert_eq(GroundMarks.count() - before, 2, "frost and ichor, nothing for the blade")
		var last := parent.get_child(parent.get_child_count() - 1) as Decal
		assert_true(last.modulate.is_equal_approx(Look.color("bog")), "the undead leave ichor")
	parent.free()
