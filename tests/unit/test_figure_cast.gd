extends TestCase
## A 3D figure casts in parts (ModelFigure's `lead`, `hold`, `after` around the main clip): it gathers, holds, throws on
## the main clip's `hit` and follows through, then stands idle; a part the model lacks is skipped. Its hand bone says
## where the spell leaves from when the game feel asks for it (cast_hands), and a drawn sprite has no hand.

const ID := "test_cast_figure"


func after_each() -> void:
	FigureModels.unregister(ID)
	FigureModels._entries.clear()
	GameFeel.use(null)


## A model one unit tall with a RightHand bone, an idle and four short spell clips named as the Universal Animation
## Library names them; the hand rises over spell_shoot.
static func model() -> PackedScene:
	var root := Node3D.new()
	root.name = "Model"
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	sk.owner = root
	sk.add_bone("mixamorig_Hips")
	sk.add_bone("mixamorig_RightHand")
	sk.set_bone_parent(1, 0)
	sk.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)))
	sk.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0.3, 0.1, 0)))
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 1.0, 0.2)
	mi.mesh = box
	mi.position.y = 0.5
	sk.add_child(mi)
	mi.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var lib := AnimationLibrary.new()
	lib.add_animation(&"Idle_Loop", _clip(1.0, 0.0))
	lib.add_animation(&"Spell_Simple_Enter", _clip(0.2, 0.0))
	lib.add_animation(&"Spell_Simple_Idle_Loop", _clip(0.5, 0.0))
	lib.add_animation(&"Spell_Simple_Shoot", _clip(0.2, 0.3))
	lib.add_animation(&"Spell_Simple_Exit", _clip(0.2, 0.0))
	player.add_animation_library(&"", lib)
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


## A clip `length` seconds long whose hand rises by `rise` over it.
static func _clip(length: float, rise: float) -> Animation:
	var a := Animation.new()
	a.length = length
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath("Skeleton3D:mixamorig_RightHand"))
	a.position_track_insert_key(t, 0.0, Vector3(0.3, 0.1, 0))
	a.position_track_insert_key(t, length, Vector3(0.3, 0.1 + rise, 0))
	return a


const CAST := {"clip": "Spell_Simple_Shoot", "hit": 0.1, "lead": "Spell_Simple_Enter",
	"hold": {"clip": "Spell_Simple_Idle", "seconds": 0.15}, "after": "Spell_Simple_Exit"}


func _figure(cast: Variant) -> ModelFigure:
	FigureModels.register(ID, {"clips": {"idle": "Idle", "cast": cast}}, model())
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for(ID), 1.0) as ModelFigure
	add_child(fig)
	return fig


## Steps frames until `done` says so or `seconds` of real time pass, noting each part the figure plays.
func _watch(fig: ModelFigure, done: Callable, seconds: float = 4.0) -> Array[String]:
	var seen: Array[String] = []
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(done.call()) and Time.get_ticks_msec() < until:
		var phase := str(fig._clip.get("phase", ""))
		if phase != "" and (seen.is_empty() or seen[-1] != phase):
			seen.append(phase)
		await get_tree().process_frame
	return seen


func test_a_cast_gathers_holds_throws_and_follows_through() -> void:
	var fig := _figure(CAST)
	assert_true(fig.cast(), "a model with a cast clip casts")
	assert_true(fig.is_gathering(), "gathering the spell")
	assert_eq(str(fig._player.current_animation), "Spell_Simple_Enter", "it starts with the lead-in")
	var struck_in: Array[String] = []   # a lambda keeps a copy of a plain local
	fig.struck.connect(func() -> void: struck_in.append(str(fig._clip.get("phase", ""))))
	var seen := await _watch(fig, func() -> bool: return fig._one_shot == "")
	assert_eq(seen, ["lead", "hold", "main", "after"] as Array[String], "the parts play in order")
	assert_eq(struck_in, ["main"] as Array[String], "the spell leaves on the main clip's hit, not before")
	assert_false(fig.is_gathering(), "done")
	assert_eq(fig._loop, "idle", "and it stands idle again")
	fig.free()


func test_a_loop_is_found_with_or_without_its_suffix() -> void:
	var names := PackedStringArray(["Spell_Simple_Idle_Loop", "Idle"])
	assert_eq(ModelFigure.clip_named(names, "Spell_Simple_Idle"), "Spell_Simple_Idle_Loop", "as the pack names it")
	assert_eq(ModelFigure.clip_named(names, "Idle_Loop"), "Idle", "as Godot's importer names it")


func test_a_part_the_model_lacks_is_skipped() -> void:
	var cast := CAST.duplicate()
	cast["lead"] = "Spell_Double_Enter"
	cast.erase("after")
	var fig := _figure(cast)
	assert_true(fig.cast(), "it still casts")
	assert_eq(str(fig._player.current_animation), "Spell_Simple_Idle_Loop", "no lead-in of that name: it starts on the hold")
	var seen := await _watch(fig, func() -> bool: return fig._one_shot == "")
	assert_eq(seen, ["hold", "main"] as Array[String], "hold, then the throw, and no follow-through")
	fig.free()
	var plain := _figure("Spell_Simple_Shoot")
	assert_true(plain.cast(), "a plain clip name casts as it always did")
	assert_eq(str(plain._player.current_animation), "Spell_Simple_Shoot", "straight to the throw")
	plain.free()


func test_moving_cuts_a_cast_short() -> void:
	var fig := _figure(CAST)
	fig.cast()
	var fired := [false]
	fig.struck.connect(func() -> void: fired[0] = true)
	fig.moving = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(fig._one_shot, "", "the cast is cut short")
	assert_true(bool(fired[0]), "and its spell still leaves, so a fight waiting on it goes on")
	fig.free()


func test_the_hand_is_the_hand_bone_and_a_sprite_has_none() -> void:
	var fig := _figure(CAST)
	await get_tree().process_frame
	var hand := fig.hand_position()
	assert_true(hand != Vector3.INF, "a figure with a RightHand bone has a hand")
	assert_true(hand.x > fig.global_position.x + 0.01, "off to the figure's side, where its hand is")
	var low := hand.y
	fig.cast()
	await _watch(fig, func() -> bool: return str(fig._clip.get("phase", "")) == "after")
	assert_true(fig.hand_position().y > low + 0.05, "the hand moves with the clip (raised by the throw)")
	fig.free()
	var none := _figure(CAST)
	none._info["cast_hand"] = "LeftHand"
	assert_eq(none.hand_position(), Vector3.INF, "no bone of that name: no hand")
	none.free()
	var sprite := DirectionalSprite.new()
	assert_eq(sprite.hand_position(), Vector3.INF, "a drawn sprite has no hand")
	assert_false(sprite.is_gathering(), "nor gathers")
	sprite.free()


func test_spells_leave_from_the_hand_only_when_the_game_asks() -> void:
	var fig := _figure(CAST)
	var tok := CombatToken.new()
	tok.art_override = ID
	add_child(tok)
	tok.set_process(false)   # a bare token: no creature for its bars and aura
	tok.sprite = fig
	await get_tree().process_frame
	var toward := tok.global_position + Vector3(0, 0, 5)
	GameFeel.use({})
	var plain := SpellFx.hand(tok, toward)
	assert_between(plain.z - tok.global_position.z, 0.29, 0.31, "off: a step toward the target, as before")
	GameFeel.use({"cast_hands": true})
	assert_true(SpellFx.hand(tok, toward).is_equal_approx(fig.hand_position()), "on: from the hand bone")
	tok.sprite = null
	tok.free()
	fig.free()
