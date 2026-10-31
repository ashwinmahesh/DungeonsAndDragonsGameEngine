extends TestCase
## 3D figures (FigureModels, ModelFigure): an art id with a model draws it wherever its sprite would be, sized to its
## height, its walk held in place and paced to the ground, its attack landing its blow, its fall laying it down; an art
## id without one keeps its sprite. The model here is made in code, as an exporter's would be: a skeleton whose root bone
## a walk carries forward, a mesh one unit tall, and clips named the way Tripo names them ("walk.001").

const ID := "test_figure"


func after_each() -> void:
	FigureModels.unregister(ID)
	FigureModels.unregister(ID + "_still")


## A model one unit tall: Armature > Skeleton3D (Hips > Spine) > a box mesh, and an AnimationPlayer with idle, walk (Hips
## carried 1.2 units forward over its second, bobbing twice), and slash.
static func model() -> PackedScene:
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
	mi.set_surface_override_material(0, mat)
	sk.add_child(mi)
	mi.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle.001", _clip(2.0, Vector3.ZERO, 0.0))
	lib.add_animation(&"walk.001", _clip(1.0, Vector3(0, 0, 1.2), 0.04))
	lib.add_animation(&"slash.001", _clip(1.0, Vector3.ZERO, 0.0))
	player.add_animation_library(&"", lib)
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


## A clip `length` seconds long whose Hips move by `drift` and bob `bob` units twice.
static func _clip(length: float, drift: Vector3, bob: float) -> Animation:
	var a := Animation.new()
	a.length = length
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath("Armature/Skeleton3D:mixamorig_Hips"))
	for k in 9:
		var f := float(k) / 8.0
		a.position_track_insert_key(t, f * length, Vector3(0, 0.5 - bob * (0.5 + 0.5 * cos(f * TAU * 2.0)), 0) + drift * f)
	return a


func _figure(height: float, entry: Dictionary = {}) -> ModelFigure:
	FigureModels.register(ID, entry, model())
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


func test_a_token_draws_the_model_and_its_fade_reaches_it() -> void:
	FigureModels.register(ID, {}, model())
	var ch := Character.new()
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
	tok.free()
