extends TestCase
## Rigs (FigureModels "rigs", docs/reference/art/figures.md): a body made on a skeleton that names its bones its own way
## (Quaternius's neck_01, hand_r, no head-top bone) says so in its entry, and the engine's lookups (a head made apart
## fitted to the neck, a part held on a hand, the entry's `bones`) go through the rig's names; a figure on no rig is
## found by the engine's own names as before. The body is made in code: a pelvis at 0.5, spine_01 at 0.7, neck_01 at 0.8,
## Head at 0.85 (its top, the 1.0 of a unit-tall body, no bone) and a hand_r.

const Layers := preload("res://addons/dnd_core/tests/unit/test_figure_layers.gd")
const ID := "test_packed"
const RIG := "test_pack_rig"
const HEAD := "test_pack_head"
const SWORD := "test_pack_sword"

const BONES := {"Hips": "pelvis", "Spine": "spine_01", "Neck": "neck_01", "RightHand": "hand_r", "HeadTop_End": ""}


func after_each() -> void:
	FigureModels.unregister(ID)
	FigureModels.unregister_rig(RIG)
	for p: String in [HEAD, SWORD]:
		FigureModels.unregister_part(p)


## The unit-tall body on the pack's bone names.
static func _packed_body(top := 1.0) -> PackedScene:
	var root := Node3D.new()
	root.name = "Model"
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	sk.owner = root
	var at := 0.0
	for pair: Array in [["pelvis", 0.5], ["spine_01", 0.7], ["neck_01", 0.8], ["Head", 0.85]]:
		var i := sk.get_bone_count()
		sk.add_bone(str(pair[0]))
		if i > 0:
			sk.set_bone_parent(i, i - 1)
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, Vector3(0, float(pair[1]) - at, 0)))
		at = float(pair[1])
	sk.add_bone("hand_r")
	sk.set_bone_parent(4, 1)
	sk.set_bone_rest(4, Transform3D(Basis.IDENTITY, Vector3(0.3, 0.0, 0)))
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	var box := BoxMesh.new()
	box.size = Vector3(0.4, top, 0.2)
	mi.mesh = box
	mi.position.y = top / 2.0
	sk.add_child(mi)
	mi.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _figure(entry: Dictionary) -> ModelFigure:
	FigureModels.register(ID, entry, _packed_body())
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for(ID), 1.0) as ModelFigure
	add_child(fig)
	return fig


func test_the_rig_says_what_its_bones_are_called() -> void:
	var sk := (_packed_body().instantiate().find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	assert_eq(FigureModels.bone(sk, "Neck"), -1, "no bone is called Neck on this skeleton")
	assert_eq(FigureModels.bone(sk, "Neck", BONES), 2, "the rig says it is neck_01")
	assert_eq(FigureModels.bone(sk, "mixamorig:neck", BONES), 2, "an exporter's prefix and case are still set aside")
	assert_eq(FigureModels.bone(sk, "RightHand", BONES), 4, "hand_r")
	assert_eq(FigureModels.bone(sk, "HeadTop_End", BONES), -1, "an empty name: the rig has no such bone")
	assert_eq(FigureModels.bone(sk, "Head", BONES), 3, "a bone the rig doesn't rename is found as it always was")
	assert_eq(FigureBones.bone_named(sk, "Hips", BONES), 0, "the entry's bones go through the rig too")
	assert_eq(FigureBones.bone_named(sk, "Hips"), -1, "and without it the plain name finds none")
	sk.get_parent().free()


func test_a_figure_on_a_rig_has_the_rigs_bone_names_and_clips_under_its_own() -> void:
	FigureModels.register_rig(RIG, {"bones": BONES, "clips": {"idle": "Idle_Loop", "walk": "Walk_Loop", "attack": "Sword_Attack"}})
	FigureModels.register(ID, {"rig": RIG, "clips": {"walk": "Walk_Formal_Loop"}}, _packed_body())
	assert_eq(FigureModels.rig_bones(ID).get("Neck"), "neck_01", "the figure's rig's bones")
	var clips := FigureModels.info(ID).get("clips", {}) as Dictionary
	assert_eq(clips.get("idle"), "Idle_Loop", "the rig's clips are the figure's")
	assert_eq(clips.get("attack"), "Sword_Attack", "all of them")
	assert_eq(clips.get("walk"), "Walk_Formal_Loop", "the entry's own over the rig's, role by role")
	assert_true(FigureModels.rig_bones("no_such_figure").is_empty(), "a figure with no entry names no rig")
	FigureModels.register("test_unrigged", {}, null)
	assert_true(FigureModels.rig_bones("test_unrigged").is_empty(), "a figure on no rig finds its bones by the engine's names")
	FigureModels.unregister("test_unrigged")


func test_a_head_made_apart_fits_a_body_on_another_rig_the_way_it_fits_one_on_the_engines() -> void:
	FigureModels.register_rig(RIG, {"bones": BONES, "head_top": [0.0, 0.15, 0.0]})
	FigureModels.register_part(HEAD, {"bone": "Head", "follow": "turn", "fit": "head"}, Layers._lantern())
	var fig := _figure({"rig": RIG})
	fig.wear([HEAD])
	var hold := fig._skeleton.find_children("Holds_*", "Node3D", false, false)[0] as Node3D
	var piece := hold.get_child(0) as Node3D
	# Neck_01 to the top of the head is 0.2 (the Head bone and the 0.15 the rig gives), the piece 2 tall: scaled to 0.1,
	# exactly as the engine's own rig's (test_figure_layers) comes out.
	assert_between(piece.scale.y, 0.099, 0.101, "as tall as the body's neck and head")
	var foot := hold.transform * piece.transform * Vector3(0, -1.0, 0)
	assert_between(foot.distance_to(Vector3(0, 0.8, 0)), 0.0, 0.001, "its foot on the neck_01 joint")
	fig.free()


func test_without_a_rig_the_same_body_gets_no_fit() -> void:
	FigureModels.register_part(HEAD, {"bone": "Head", "follow": "turn", "fit": "head", "size": 0.5}, Layers._lantern())
	var fig := _figure({})
	fig.wear([HEAD])
	var holds := fig._skeleton.find_children("Holds_*", "Node3D", false, false)
	assert_eq(holds.size(), 1, "the head bone is called Head, so the part is held")
	var piece := (holds[0] as Node3D).get_child(0) as Node3D
	assert_between(piece.scale.y, 0.2, 0.3, "but with no Neck to fit to it is only sized (0.5 of the figure's height over 2)")
	fig.free()


func test_a_rig_with_no_head_top_says_so_and_the_head_is_left_unfitted() -> void:
	FigureModels.register_rig(RIG, {"bones": BONES})
	FigureModels.register_part(HEAD, {"bone": "Head", "follow": "turn", "fit": "head", "size": 0.5}, Layers._lantern())
	var fig := _figure({"rig": RIG})
	fig.wear([HEAD])
	var hold := fig._skeleton.find_children("Holds_*", "Node3D", false, false)[0] as Node3D
	assert_between((hold.get_child(0) as Node3D).scale.y, 0.2, 0.3, "with no head-top bone or offset the fit is not attempted")
	fig.free()


func test_a_part_is_held_on_the_hand_the_rig_names_and_the_entrys_bones_scale_through_the_rig() -> void:
	FigureModels.register_rig(RIG, {"bones": BONES})
	FigureModels.register_part(SWORD, {"bone": "RightHand", "size": 0.3}, Layers._lantern())
	var fig := _figure({"rig": RIG, "bones": {"Hips": 1.5}})
	fig.wear([SWORD])
	var holds := fig._skeleton.find_children("Holds_*", "Node3D", false, false)
	assert_eq(holds.size(), 1, "the sword is held on hand_r")
	assert_eq((holds[0] as BoneAttachment3D).bone_name, "hand_r", "by the rig's name for RightHand")
	var scaler := fig._skeleton.get_node_or_null("FigureBones") as FigureBones
	assert_true(scaler != null and scaler.scales.has(0) and is_equal_approx(float(scaler.scales[0]), 1.5), "Hips scales pelvis")
	fig.free()
