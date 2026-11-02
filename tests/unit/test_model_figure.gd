extends TestCase
## 3D figures (FigureModels, ModelFigure): an art id with a model draws it wherever its sprite would be, sized to its
## height, its walk held in place and paced to the ground, its attack landing its blow, its fall laying it down; an art
## id without one keeps its sprite. The model here is made in code, as an exporter's would be: a skeleton whose root bone
## a walk carries forward, a mesh one unit tall, and clips named the way Tripo names them ("walk.001").

const ID := "test_figure"


func after_each() -> void:
	FigureModels.unregister(ID)
	FigureModels.unregister(ID + "_still")
	FigureModels.unregister(ID + "_dressed")
	for id: String in [ID + "_coming", ID + "_coming_dressed"]:
		FigureModels.manifest().erase(id)
	FigureModels._entries.clear()


## A model one unit tall: Armature > Skeleton3D (Hips > Spine) > a box mesh, and an AnimationPlayer with idle, walk (Hips
## carried 1.2 units forward over its second, bobbing twice), and slash. `combat` adds Tripo's combat preset as Tripo
## makes it: a run that starts half a unit ahead of the feet and carries the Hips 2.4 units in half a second, a fall
## that carries them 0.7 to the side as they drop, and a hit. `only_walk`: a walk and nothing else (Tripo's "Other" rig on
## a crawler). The body is painted with a small texture of its own.
static func model(combat := false, only_walk := false) -> PackedScene:
	var root := Node3D.new()
	root.name = "Model"
	var arm := Node3D.new()
	arm.name = "Armature"
	root.add_child(arm)
	arm.owner = root
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	arm.add_child(sk)
	sk.owner = root
	sk.add_bone("mixamorig_Hips")
	sk.add_bone("mixamorig_Spine")
	sk.set_bone_parent(1, 0)
	sk.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)))
	sk.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)))
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 1.0, 0.2)
	mi.mesh = box
	mi.position.y = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.3, 0.2)
	mat.albedo_texture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	mi.set_surface_override_material(0, mat)
	sk.add_child(mi)
	mi.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var lib := AnimationLibrary.new()
	lib.add_animation(&"walk.001", _clip(1.0, Vector3(0, 0, 1.2), 0.04))
	if not only_walk:
		lib.add_animation(&"idle.001", _clip(2.0, Vector3.ZERO, 0.0))
		lib.add_animation(&"slash.001", _clip(1.0, Vector3.ZERO, 0.0))
	if combat:
		lib.add_animation(&"run.001", _clip(0.5, Vector3(0, 0, 2.4), 0.03, Vector3(0, 0, 0.5)))
		lib.add_animation(&"fall.001", _clip(1.0, Vector3(0.7, -0.35, 0), 0.0))
		lib.add_animation(&"hit_to_body_01.001", _clip(0.6, Vector3.ZERO, 0.02))
	player.add_animation_library(&"", lib)
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


## A clip `length` seconds long whose Hips start `start` from their rest, move by `drift` and bob `bob` units twice.
static func _clip(length: float, drift: Vector3, bob: float, start := Vector3.ZERO) -> Animation:
	var a := Animation.new()
	a.length = length
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath("Armature/Skeleton3D:mixamorig_Hips"))
	for k in 9:
		var f := float(k) / 8.0
		a.position_track_insert_key(t, f * length, Vector3(0, 0.5 - bob * (0.5 + 0.5 * cos(f * TAU * 2.0)), 0) + start + drift * f)
	return a


func _figure(height: float, entry: Dictionary = {}, combat := false) -> ModelFigure:
	FigureModels.register(ID, entry, model(combat))
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for(ID), height) as ModelFigure
	add_child(fig)
	return fig


func test_an_art_id_with_a_model_draws_it_and_one_without_keeps_its_sprite() -> void:
	assert_false(FigureModels.has(ID), "no model yet")
	var fig := _figure(1.3)
	assert_true(FigureModels.has(ID), "registered")
	assert_true(fig is ModelFigure, "the stand-in frames make a 3D figure")
	assert_true(DirectionalSprite.has_attack(fig.sprite_frames), "the frames answer for the model's attack")
	assert_true(DirectionalSprite.has_anim(fig.sprite_frames, "down"), "and for lying down, which the figure does itself")
	assert_eq(fig.layers, 0, "its own sprite draws nothing")
	var box := ModelFigure.rest_box(fig.model)
	assert_between(box.size.y * fig.model.scale.y, 1.29, 1.31, "the model stands as tall as the figure is drawn")
	assert_between(fig.model.position.y, -0.001, 0.001, "its feet on the ground")
	assert_true(fig._meshes[0].get_surface_override_material(0) is ShaderMaterial, "its surfaces in the figure material")
	assert_eq((fig._meshes[0].get_surface_override_material(0) as ShaderMaterial).render_priority,
		DirectionalSprite.RENDER_PRIORITY, "drawn after the screen pass, as the sprites are")
	fig.free()
	assert_false(FigureModels.has("no_such_figure"), "an art id without a model")
	assert_false(DirectionalSprite.frames_for("no_such_figure") != null and DirectionalSprite.frames_for("no_such_figure").has_meta(FigureModels.META),
		"keeps whatever sprite it has")


func test_clip_names_are_read_plainly() -> void:
	var names := PackedStringArray(["idle.001", "Armature|walk", "preset:quadruped:run.002", "greet_01"])
	assert_eq(ModelFigure.clip_named(names, "idle"), "idle.001", "an exporter's number")
	assert_eq(ModelFigure.clip_named(names, "walk"), "Armature|walk", "a take's armature")
	assert_eq(ModelFigure.clip_named(names, "run"), "preset:quadruped:run.002", "a preset's path")
	assert_eq(ModelFigure.clip_named(names, "greet_01"), "greet_01", "a name as it is")
	assert_eq(ModelFigure.clip_named(names, "slash"), "", "none")


func test_a_walk_that_carries_the_model_forward_is_held_in_place_and_paces_the_legs() -> void:
	var fig := _figure(1.0)
	var walk := fig._player.get_animation(&"walk.001")
	var t := 0
	for i in walk.get_track_count():
		if walk.track_get_type(i) == Animation.TYPE_POSITION_3D:
			t = i
	var first := walk.track_get_key_value(t, 0) as Vector3
	var last := walk.track_get_key_value(t, walk.track_get_key_count(t) - 1) as Vector3
	assert_between(Vector2(last.x - first.x, last.z - first.z).length(), 0.0, 0.001, "the drift taken out")
	assert_between(float(walk.get_meta("figure_stride")), 1.19, 1.21, "the distance it covered kept as its stride")
	assert_eq(walk.loop_mode, Animation.LOOP_LINEAR, "a walk loops")
	assert_eq((walk.get_meta("figure_steps") as PackedFloat32Array).size(), 2, "two footfalls where the body is lowest")
	# Its own pace: 1.2 units a second at this size. A square every 1/1.2 s plays it as made; twice as fast, twice the rate.
	fig.set_step_time(1.0 / 1.2)
	assert_between(fig.walk_speed, 0.99, 1.01, "at its own pace")
	fig.set_step_time(1.0 / 2.4)
	assert_between(fig.walk_speed, 1.99, 2.01, "twice as fast")
	fig.set_step_time(0.05)
	assert_eq(fig.walk_speed, ModelFigure.MAX_WALK_RATE, "never past the rate where the feet skate")
	# A second copy of the model doesn't take the drift out again.
	var again := DirectionalSprite.create(DirectionalSprite.frames_for(ID), 1.0) as ModelFigure
	add_child(again)
	assert_between(float(again._player.get_animation(&"walk.001").get_meta("figure_stride")), 1.19, 1.21, "the stride stays")
	again.free()
	fig.free()


func test_it_walks_and_stands_and_turns_to_face() -> void:
	var fig := _figure(1.0)
	fig.facing = Vector3(1, 0, 0)
	await get_tree().process_frame
	assert_between(fig._turn.rotation.y, PI / 2.0 - 0.01, PI / 2.0 + 0.01, "the first facing at once")
	fig.facing = Vector3(0, 0, 1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(fig._turn.rotation.y < PI / 2.0 - 0.01 and fig._turn.rotation.y > 0.01, "a new one turned to, not jumped")
	fig.moving = true
	await get_tree().process_frame
	assert_eq(str(fig._player.current_animation), "walk.001", "walking")
	fig.moving = false
	await get_tree().process_frame
	assert_eq(str(fig._player.current_animation), "idle.001", "standing")
	fig.free()


func test_the_attack_lands_its_blow_and_finishes() -> void:
	var fig := _figure(1.0, {"clips": {"attack": {"clip": "slash", "from": 0.2, "to": 0.6, "hit": 0.4, "speed": 2.0}}})
	var seen := []
	fig.struck.connect(func() -> void: seen.append("struck"))
	fig.attack_finished.connect(func() -> void: seen.append("finished"))
	assert_true(fig.attack(), "a model with an attack clip swings")
	assert_true(fig.is_attacking(), "swinging")
	assert_between(fig._player.current_animation_position, 0.19, 0.21, "from the window's start")
	var waited := 0
	while seen.size() < 2 and waited < 120:
		await get_tree().process_frame
		waited += 1
	assert_eq(seen, ["struck", "finished"], "the blow lands, then the swing ends")
	assert_false(fig.is_attacking(), "done")
	fig.free()
	FigureModels.register(ID + "_still", {"clips": {"attack": "none_such"}}, model())
	var still := DirectionalSprite.create(DirectionalSprite.frames_for(ID + "_still"), 1.0) as ModelFigure
	add_child(still)
	assert_false(still.attack(), "a model without an attack clip plays none, so the token lunges instead")
	still.free()


func test_it_falls_and_lies_on_its_back_then_gets_up() -> void:
	var fig := _figure(1.2)
	assert_true(fig.die(), "it falls")
	assert_true(fig.is_dying(), "falling")
	assert_false(fig.die(), "not twice")
	var waited := 0
	while fig.is_dying() and waited < 120:
		await get_tree().process_frame
		waited += 1
	assert_eq(fig.pose, "down", "lying")
	var up := fig._posture.basis * Vector3.UP
	assert_between(up.y, -0.01, 0.01, "on its back: its up runs along the ground")
	assert_between((fig._posture.transform * Vector3(0, 0.6, 0)).z, -0.02, 0.02, "its middle over its square")
	fig.pose = ""
	waited = 0
	while fig._lie > 0.0 and waited < 120:
		await get_tree().process_frame
		waited += 1
	assert_between((fig._posture.basis * Vector3.UP).y, 0.99, 1.01, "standing again")
	fig.free()


func test_a_fast_figure_runs_over_its_own_square_and_a_slow_or_sneaking_one_walks() -> void:
	var fig := _figure(1.0, {}, true)
	var run := fig._player.get_animation(&"run.001")
	var t := _hips_track(run)
	var mid := Vector3.ZERO
	for k in run.track_get_key_count(t):
		mid += run.track_get_key_value(t, k) as Vector3
	mid /= run.track_get_key_count(t)
	assert_between(Vector2(mid.x, mid.z).length(), 0.0, 0.01, "the run's half-square start taken out: it runs over the feet's rest")
	assert_between(float(run.get_meta("figure_stride")), 2.39, 2.41, "its stride kept")
	# The walk covers 1.2 units a second and the run 4.8.
	fig.set_step_time(1.0 / 2.4)
	assert_eq(str(fig.get_meta("walk_role")), "walk", "walking while the walk keeps up with the ground")
	assert_between(fig.walk_speed, 1.99, 2.01, "its legs at twice their pace")
	fig.set_step_time(1.0 / 4.8)
	assert_eq(str(fig.get_meta("walk_role")), "run", "running once the walk would skate")
	assert_between(fig.walk_speed, 0.99, 1.01, "the run at its own pace")
	fig.moving = true
	await get_tree().process_frame
	assert_eq(str(fig._player.current_animation), "run.001", "the run plays")
	fig.pose = "sneak"
	fig.set_step_time(1.0 / 4.8)
	assert_eq(str(fig.get_meta("walk_role")), "walk", "never running while sneaking")
	fig.free()


func test_a_fall_clip_lays_it_down_on_its_own_square() -> void:
	var fig := _figure(1.0, {"clips": {"die": {"clip": "fall", "speed": 2.0}}}, true)
	var fall := fig._player.get_animation(&"fall.001")
	var t := _hips_track(fall)
	var last := fall.track_get_key_value(t, fall.track_get_key_count(t) - 1) as Vector3
	assert_between(Vector2(last.x, last.z).length(), 0.0, 0.001, "the sideways slide taken out: the Hips stay over the square")
	assert_between(last.y, 0.14, 0.16, "and still drop")
	assert_true(fig.die(), "it falls")
	assert_true(fig._fell_by_clip, "by its clip, not tipping over")
	var waited := 0
	while fig.is_dying() and waited < 120:
		await get_tree().process_frame
		waited += 1
	assert_eq(fig.pose, "down", "lying")
	assert_false(fig._player.is_playing(), "still, in the clip's last frame")
	fig.free()


func test_after_a_fall_clip_it_gets_up_by_playing_the_fall_back() -> void:
	var fig := _figure(1.0, {"clips": {"die": {"clip": "fall", "from": 0.2, "speed": 4.0}}}, true)
	assert_true(fig.die(), "it falls")
	var waited := 0
	while fig.is_dying() and waited < 120:
		await get_tree().process_frame
		waited += 1
	fig.pose = ""
	await get_tree().process_frame
	assert_eq(str(fig._player.current_animation), "fall.001", "getting up is the fall")
	assert_true(fig._player.get_playing_speed() < 0.0, "played backwards")
	assert_eq(fig._rise_to, 0.2, "to where the fall began")
	assert_false(fig.gesture("talk"), "busy getting up")
	waited = 0
	while fig._rise_to >= 0.0 and waited < 240:
		await get_tree().process_frame
		waited += 1
	assert_true(waited < 240, "it gets up")
	assert_eq(str(fig._player.current_animation), "idle.001", "then the idle")
	fig.free()


func test_a_model_without_an_idle_stands_still_and_breathes() -> void:
	var packed := model()
	var scene := packed.instantiate()
	var player := scene.get_node("AnimationPlayer") as AnimationPlayer
	player.get_animation_library(&"").remove_animation(&"idle.001")
	var walk_only := PackedScene.new()
	walk_only.pack(scene)
	scene.free()
	FigureModels.register(ID, {}, walk_only)
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for(ID), 1.0) as ModelFigure
	add_child(fig)
	assert_false(fig.has_role("idle"), "a walk-only rig")
	fig.moving = true
	await get_tree().process_frame
	assert_eq(str(fig._player.current_animation), "walk.001", "it walks")
	fig.moving = false
	await get_tree().process_frame
	assert_false(fig._player.is_playing(), "standing, it doesn't walk on the spot")
	var heights := {}
	for i in 40:
		fig._time += ModelFigure.BREATH_PERIOD / 40.0
		heights[snappedf(fig._breath().y.y, 0.0001)] = true
	assert_true(heights.size() > 5, "it breathes")
	fig.free()
	var with_idle := _figure(1.0)
	assert_eq(with_idle._breath(), Basis.IDENTITY, "a model with an idle clip breathes in its clip")
	with_idle.free()


func test_a_hit_clip_plays_in_place_of_the_lean() -> void:
	var fig := _figure(1.0, {"clips": {"hurt": "hit_to_body_01"}}, true)
	assert_true(fig.hurt(), "the hit clip plays")
	assert_eq(str(fig._player.current_animation), "hit_to_body_01.001", "hit_to_body_01")
	assert_eq(fig._tilt_v, 0.0, "no lean on top of it")
	assert_true(fig._flash > 0.0, "still the flash")
	fig.free()
	var plain := _figure(1.0)
	assert_false(plain.hurt(), "without a clip")
	assert_true(plain._tilt_v < 0.0, "it leans back from the blow")
	plain.free()


func _hips_track(anim: Animation) -> int:
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			return i
	return -1


func test_a_token_draws_the_model_and_its_fade_reaches_it() -> void:
	FigureModels.register(ID, {}, model())
	var ch := Character.new()
	ch.id = "test_figure_hero"   # not "": CombatToken keeps the art it wears by id, for every later test
	ch.name = "Test Figure"
	var tok := CombatToken.create(Combatant.new(ch, &"party", Vector2i.ZERO), ID)
	add_child(tok)
	assert_true(tok.sprite is ModelFigure, "the token's figure is the model")
	tok.face(Vector2(0, 1), true, 0.3)
	assert_true(tok.sprite.moving, "walking as a token says")
	tok.sprite.modulate = Color(1, 1, 1, 0.5)
	await get_tree().process_frame
	var fig := tok.sprite as ModelFigure
	assert_eq(fig._meshes[0].get_instance_shader_parameter(&"tint"), Vector4(1, 1, 1, 0.5), "a fade reaches the surfaces")
	CombatToken._looks.erase(tok.combatant.id)
	tok.free()


func test_a_creature_with_only_a_walk_that_idles_from_it_stirs_on_it_when_standing() -> void:
	FigureModels.register(ID, {"idle_from_walk": true}, model(false, true))
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for(ID), 0.5) as ModelFigure
	add_child(fig)
	await get_tree().process_frame
	assert_true(fig.has_role("idle"), "the walk stands in for the idle")
	assert_eq(str(fig._player.current_animation), "walk.001", "so it isn't left in its bind pose")
	assert_between(fig._player.speed_scale, 0.29, 0.31, "slowed to a stir (ModelFigure.IDLE_STIR)")
	fig.set_step_time(1.0 / 0.6)   # half a unit tall: its 1.2-unit stride is 0.6 at this size
	fig.moving = true
	await get_tree().process_frame
	assert_between(fig._player.speed_scale, 0.99, 1.01, "walking, at its own pace")
	assert_false(fig.attack(), "no attack clip: the token lunges")
	fig.free()


func test_a_dressing_wears_its_base_body_and_its_own_paint() -> void:
	FigureModels.register(ID, {"scale": 1.1, "clips": {"attack": {"clip": "slash", "hit": 0.3}}}, model())
	FigureModels.register(ID + "_dressed", {"base": ID, "albedo": "art/ui/corner.png", "clips": {"talk": ["slash"]}})
	var info := FigureModels.info(ID + "_dressed")
	assert_eq(float(info.get("scale", 0.0)), 1.1, "its base's size")
	assert_true((info["clips"] as Dictionary).has("attack") and (info["clips"] as Dictionary).has("talk"),
		"its base's clips with its own merged in")
	assert_true(FigureModels.has(ID + "_dressed"), "drawn as a model")
	assert_eq(FigureModels.scene(ID + "_dressed"), FigureModels.scene(ID), "the same body")
	var plain := DirectionalSprite.create(DirectionalSprite.frames_for(ID), 1.0) as ModelFigure
	var dressed := DirectionalSprite.create(DirectionalSprite.frames_for(ID + "_dressed"), 1.0) as ModelFigure
	add_child(plain)
	add_child(dressed)
	var paint := (dressed._meshes[0].get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("albedo_tex") as Texture2D
	assert_eq(paint.resource_path, ArtPaths.of("art/ui/corner.png"), "painted with its own texture")
	assert_ne(plain._meshes[0].get_surface_override_material(0), dressed._meshes[0].get_surface_override_material(0),
		"its own material; the plain body keeps the model's")
	plain.free()
	dressed.free()


func test_a_tint_multiplies_the_surfaces_and_no_tint_changes_nothing() -> void:
	FigureModels.register(ID, {}, model())
	FigureModels.register(ID + "_dressed", {"base": ID, "tint": "#80c0ff"})
	assert_eq(FigureModels.tint_of(ID), Color.WHITE, "no tint: white, no change")
	assert_eq(FigureModels.tint_of(ID + "_dressed"), Color("#80c0ff"), "a hex colour")
	FigureModels.register(ID + "_still", {"base": ID, "tint": "moonlight"})
	assert_eq(FigureModels.tint_of(ID + "_still"), Look.color("moonlight"), "or a palette name")
	var plain := DirectionalSprite.create(DirectionalSprite.frames_for(ID), 1.0) as ModelFigure
	var dressed := DirectionalSprite.create(DirectionalSprite.frames_for(ID + "_dressed"), 1.0) as ModelFigure
	add_child(plain)
	add_child(dressed)
	plain._show_modulate()
	dressed._show_modulate()
	var p: Vector4 = plain._meshes[0].get_instance_shader_parameter("tint")
	var t: Vector4 = dressed._meshes[0].get_instance_shader_parameter("tint")
	assert_eq(Vector3(p.x, p.y, p.z), Vector3.ONE, "the plain body is untinted")
	assert_between(t.x, 0.49, 0.51, "the dressing's red is halved")
	assert_between(t.y, 0.74, 0.76, "its green is three quarters")
	assert_eq(t.z, 1.0, "its blue is full")
	dressed.modulate = Color(1, 1, 1, 0.5)   # a fade on top (CombatToken) keeps the tint
	dressed._show_modulate()
	t = dressed._meshes[0].get_instance_shader_parameter("tint")
	assert_between(t.w, 0.49, 0.51, "the fade still reaches it")
	assert_between(t.x, 0.49, 0.51, "and the tint stays")
	plain.free()
	dressed.free()


func test_a_figure_still_to_come_wears_its_stand_in_sprite() -> void:
	FigureModels.manifest()[ID + "_coming"] = {"file": "art/figures/no_such_model.glb", "sprite": "specter"}
	FigureModels.manifest()[ID + "_coming_dressed"] = {"base": ID + "_coming", "albedo": "art/ui/corner.png"}
	assert_false(FigureModels.has(ID + "_coming"), "no model yet")
	assert_eq(FigureModels.stand_in(ID + "_coming"), "specter", "its stand-in")
	assert_eq(DirectionalSprite.frames_for(ID + "_coming"), DirectionalSprite.frames_for("specter"), "wears the sprite meanwhile")
	assert_eq(DirectionalSprite.frames_for(ID + "_coming_dressed"), DirectionalSprite.frames_for("specter"),
		"and so do its dressings, by their base")
	assert_eq(FigureModels.stand_in("specter"), "", "a sprite with no entry stands in for nothing")


func test_bones_grow_on_top_of_the_clip() -> void:
	var fig := _figure(1.0, {"bones": {"spine": 1.3, "no_such_bone": 2.0}})
	var fb: FigureBones = null
	for c in fig._skeleton.get_children():
		if c is FigureBones:
			fb = c as FigureBones
	assert_true(fb != null, "a bone modifier on the skeleton")
	assert_eq(fb.scales, {1: 1.3}, "Spine found by its plain name (mixamorig_Spine); an unknown bone left out")
	assert_eq(FigureBones.bone_named(fig._skeleton, "HIPS"), 0, "names ignore case")
	fig._skeleton.set_bone_pose_scale(1, Vector3.ONE)
	fb._process_modification_with_delta(0.016)
	assert_between(fig._skeleton.get_bone_pose_scale(1).x, 1.29, 1.31, "grown on top of the pose")
	fig.free()
	var plain := _figure(1.0)
	assert_true(plain._skeleton.get_children().all(func(c: Node) -> bool: return not c is FigureBones), "none without bones")
	plain.free()


func test_a_ghost_look_reaches_its_surfaces() -> void:
	var fig := _figure(1.0, {"ghost": {"wash": 0.5, "colour": "silver", "glow": 0.3, "see_through": 0.4, "rim": 0.6, "pulse": 0.2}})
	var mi := fig._meshes[0]
	var silver := Look.color("silver")
	assert_eq(mi.get_instance_shader_parameter(&"ghost"), 0.5, "washed")
	assert_eq(mi.get_instance_shader_parameter(&"ghost_colour"), Vector4(silver.r, silver.g, silver.b, silver.a), "in its colour")
	assert_eq(mi.get_instance_shader_parameter(&"glow"), 0.3, "its own light")
	assert_eq(mi.get_instance_shader_parameter(&"see_through"), 0.4, "seen through")
	assert_eq(mi.get_instance_shader_parameter(&"ghost_rim"), 0.6, "its edge glowing")
	assert_eq(mi.get_instance_shader_parameter(&"pulse"), 0.2, "throbbing")
	var depth := mi.get_surface_override_material(0) as ShaderMaterial
	assert_eq(depth.shader, ModelFigure.DEPTH, "seen through softly: its depth first")
	assert_eq(depth.render_priority, DirectionalSprite.RENDER_PRIORITY, "at the figures' priority")
	var body := depth.next_pass as ShaderMaterial
	assert_eq(body.shader, ModelFigure.SHADER, "then its surfaces")
	assert_true(bool(body.get_shader_parameter("soft_through")), "blended, not dithered")
	assert_eq(body.render_priority, DirectionalSprite.RENDER_PRIORITY + 1, "after every figure's depth")
	fig.free()
	var glow_only := _figure(1.0, {"ghost": {"glow": 0.8, "rim": 0.5}})
	assert_eq((glow_only._meshes[0].get_surface_override_material(0) as ShaderMaterial).shader, ModelFigure.SHADER,
		"a ghost nobody sees through keeps the solid material")
	glow_only.free()


func test_a_game_can_draw_a_figure_with_its_own_shader() -> void:
	var fig := _figure(1.0, {"shader": "shaders/world/figure_ink.gdshader"})
	var m := fig._meshes[0].get_surface_override_material(0) as ShaderMaterial
	assert_eq(m.shader, ModelFigure.INK, "the entry's shader in place of lit_figure")
	fig.free()
	var plain := _figure(1.0)
	assert_eq((plain._meshes[0].get_surface_override_material(0) as ShaderMaterial).shader, ModelFigure.SHADER, "else the engine's")
	plain.free()
