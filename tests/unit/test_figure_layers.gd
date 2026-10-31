extends TestCase
## Layers on 3D figures (FigureModels parts, ModelFigure.wear): a rigid piece is held on its bone at its size, a skinned
## layer's meshes join the figure's own skeleton bound by bone name, a part hides the meshes it covers, the entry's own
## layers are always on, and what's no longer worn comes off. The figure is test_model_figure's model, made in code.

const Figure := preload("res://addons/dnd_core/tests/unit/test_model_figure.gd")
const ID := "test_layered"
const LANTERN := "test_lantern"
const CLOAK := "test_cloak"


func after_each() -> void:
	FigureModels.unregister(ID)
	for p: String in [LANTERN, CLOAK, "test_no_bone"]:
		FigureModels.unregister_part(p)


func _figure(entry: Dictionary = {}) -> ModelFigure:
	FigureModels.register(ID, entry, Figure.model())
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for(ID), 1.2) as ModelFigure
	add_child(fig)
	return fig


## A piece two units long on its longest side, its middle at its origin.
static func _lantern() -> PackedScene:
	var root := Node3D.new()
	root.name = "Lantern"
	var mi := MeshInstance3D.new()
	mi.name = "Glass"
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 2.0, 0.5)
	mi.mesh = box
	root.add_child(mi)
	mi.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


## A layer made on its own rig, as an exporter writes one: a Skeleton3D whose bones are named its own way ("Hips",
## without the figure's prefix) and one skinned mesh whose skin binds by the names in the file ("mixamorig:Hips").
static func _cloak() -> PackedScene:
	var root := Node3D.new()
	root.name = "Cloak"
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	sk.owner = root
	sk.add_bone("Hips")
	sk.add_bone("Spine")
	sk.set_bone_parent(1, 0)
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [Vector3(-0.2, 0.2, -0.1), Vector3(0.2, 0.2, -0.1), Vector3(0, 0.9, -0.1)]:
		st.set_bones(PackedInt32Array([0 if v.y < 0.5 else 1, 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "Cloth"
	mi.mesh = st.commit()
	var skin := Skin.new()
	skin.add_named_bind("mixamorig:Hips", Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)))
	skin.add_named_bind("mixamorig:Spine", Transform3D(Basis.IDENTITY, Vector3(0, -0.7, 0)))
	mi.skin = skin
	sk.add_child(mi)
	mi.owner = root
	mi.skeleton = NodePath("..")
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func test_bone_names_match_across_rigs() -> void:
	for name: String in ["mixamorig:RightHand", "mixamorig_RightHand", "RightHand", "mixamorig1_RightHand", "Armature|mixamorig:righthand"]:
		assert_eq(FigureModels.bone_key(name), "righthand", name)
	var fig := _figure()
	assert_eq(FigureModels.bone(fig._skeleton, "Spine"), 1, "a bone named without the rig's prefix")
	assert_eq(FigureModels.bone(fig._skeleton, "mixamorig:Spine"), 1, "and with a file's colon")
	assert_eq(FigureModels.bone(fig._skeleton, "LeftHand"), -1, "a bone the skeleton lacks")
	fig.free()


func test_a_rigid_piece_is_held_on_its_bone_at_its_size() -> void:
	FigureModels.register_part(LANTERN, {"bone": "Spine", "size": 0.25, "offset": [0.1, 0, 0]}, _lantern())
	var fig := _figure()
	var before := fig._meshes.size()
	fig.wear([LANTERN])
	assert_eq(fig.worn_parts(), [LANTERN], "worn")
	var holds := fig._skeleton.find_children("Holds_*", "BoneAttachment3D", false, false)
	assert_eq(holds.size(), 1, "held by an attachment on the skeleton")
	assert_eq(str((holds[0] as BoneAttachment3D).bone_name), "mixamorig_Spine", "on the bone the part names, by the figure's name for it")
	var piece := (holds[0] as Node3D).get_child(0) as Node3D
	# Longest side 2 units, a quarter of a figure 1 unit tall at rest: scaled to 0.125; drawn 1.2 tall, it is 0.3.
	assert_between(piece.scale.y, 0.124, 0.126, "a quarter of the figure's height at rest")
	assert_between(2.0 * piece.scale.y * fig.model.scale.y, 0.29, 0.31, "a quarter of the height it is drawn at")
	assert_between(piece.position.x, 0.099, 0.101, "offset in figure heights")
	assert_eq(fig._meshes.size(), before + 1, "its mesh lit and inked with the figure's")
	assert_true(fig._meshes[-1].get_surface_override_material(0) is ShaderMaterial, "in the figure material")
	fig.set_glow(0.5)
	assert_eq(fig._meshes[-1].get_instance_shader_parameter(&"glow"), 0.5, "and its state")
	fig.wear([])
	assert_eq(fig.worn_parts(), [], "taken off")
	assert_eq(fig._meshes.size(), before, "its mesh no longer the figure's")
	await get_tree().process_frame
	assert_eq(fig._skeleton.find_children("Holds_*", "BoneAttachment3D", false, false).size(), 0, "and gone")
	fig.free()


func test_a_skinned_layer_joins_the_figures_skeleton() -> void:
	FigureModels.register_part(CLOAK, {}, _cloak())
	var fig := _figure()
	fig.set_ghost(0.25)
	fig.wear([CLOAK])
	var worn := fig._skeleton.find_children("Wears_*", "MeshInstance3D", false, false)
	assert_eq(worn.size(), 1, "the layer's mesh moved onto the figure's skeleton")
	var mi := worn[0] as MeshInstance3D
	assert_eq(mi.skeleton, NodePath(".."), "skinned to it")
	assert_eq(str(mi.skin.get_bind_name(0)), "mixamorig_Hips", "its binds named by the figure's bones")
	assert_eq(str(mi.skin.get_bind_name(1)), "mixamorig_Spine", "every one")
	assert_eq(mi.get_instance_shader_parameter(&"ghost"), 0.25, "with the figure's state so far")
	var fresh := _cloak().instantiate()
	assert_eq(str(((fresh.find_children("*", "MeshInstance3D", true, false)[0]) as MeshInstance3D).skin.get_bind_name(0)),
		"mixamorig:Hips", "the layer's own model keeps its skin")
	fresh.free()
	fig.free()


func test_a_part_hides_what_it_covers_and_the_entrys_layers_are_always_on() -> void:
	FigureModels.register_part(CLOAK, {"hides": ["Body"]}, _cloak())
	FigureModels.register_part(LANTERN, {"bone": "Hips", "size": 0.2}, _lantern())
	var fig := _figure({"layers": [LANTERN]})
	assert_eq(fig.worn_parts(), [LANTERN], "the entry's own layer on from the start")
	var body := fig._own_meshes[0]
	assert_true(body.visible, "the body shows")
	fig.wear([CLOAK])
	assert_eq(fig.worn_parts(), [LANTERN, CLOAK], "worn over the entry's own")
	assert_false(body.visible, "covered")
	fig.wear([])
	assert_eq(fig.worn_parts(), [LANTERN], "the entry's own stays on")
	assert_true(body.visible, "shown again")
	fig.free()


func test_a_part_without_a_model_or_a_bone_is_left_off() -> void:
	FigureModels.register_part("test_no_bone", {"bone": "LeftHand"}, _lantern())
	var fig := _figure()
	fig.wear(["test_no_bone", "test_no_such_part"])
	assert_eq(fig.worn_parts(), [], "nothing to hold it, and no model")
	assert_eq(fig._skeleton.find_children("Holds_*", "BoneAttachment3D", false, false).size(), 0, "nothing added")
	fig.free()


func test_the_other_hand_holds_a_part_mirrored() -> void:
	var m := FigureModels.mirrored({"bone": "mixamorig_RightHand", "offset": [0.1, 0.2, 0.3], "turn": [10, 20, 30], "grip": [0.5, 0, 0]})
	assert_eq(str(m["bone"]), "mixamorig_LeftHand", "the other hand")
	assert_eq(m["offset"], [-0.1, 0.2, 0.3], "across the middle")
	assert_eq(m["turn"], [10, -20.0, -30.0], "turned the other way")
	assert_eq(m["grip"], [-0.5, 0, 0], "held at the same point")


func test_a_characters_figure_wears_what_they_hold_and_changes_with_it() -> void:
	FigureModels.register_part(LANTERN, {"bone": "Spine", "size": 0.25}, _lantern())
	FigureModels.manifest()
	FigureModels._gear["hooded_lantern"] = LANTERN
	FigureModels.register(ID, {"gear": ["main_hand", "off_hand"]}, Figure.model())
	var ch := Character.new()
	ch.name = "Test Figure"
	ch.inventory.append({"id": "hooded_lantern", "qty": 1, "slot": "off_hand"})
	ch.inventory.append({"id": "longsword", "qty": 1, "slot": "main_hand"})
	assert_eq(FigureModels.gear_for(ID, ch), [LANTERN + FigureModels.OFF_HAND],
		"the lantern, in the other hand; a longsword with no part shows nothing")
	var tok := CombatToken.create(Combatant.new(ch, &"party", Vector2i.ZERO), ID)
	add_child(tok)
	var fig := tok.sprite as ModelFigure
	assert_eq(fig.worn_parts(), [LANTERN + FigureModels.OFF_HAND], "the token's figure wears it")
	ch.inventory[0]["slot"] = ""
	await get_tree().process_frame
	assert_eq(fig.worn_parts(), [], "put away, it comes off")
	tok.free()
	FigureModels.forget()
	FigureModels.register(ID + "_drawn", {}, Figure.model())
	assert_eq(FigureModels.gear_for(ID + "_drawn", ch), [], "a figure with its things drawn on shows no gear")
	FigureModels.unregister(ID + "_drawn")


func test_an_upright_piece_follows_its_bone_but_stands_as_the_figure_does() -> void:
	FigureModels.register_part(LANTERN, {"bone": "Spine", "size": 0.25, "upright": true, "grip": [0, 1, 0]}, _lantern())
	var fig := _figure()
	fig.wear([LANTERN])
	var holds := fig._skeleton.find_children("Holds_*", "Node3D", false, false)
	assert_eq(holds.size(), 1, "held")
	assert_false(holds[0] is BoneAttachment3D, "not turned by the bone")
	var hold := holds[0] as Node3D
	var piece := hold.get_child(0) as Node3D
	assert_between(piece.position.y, -0.126, -0.124, "hung from its grip, the top of it")
	fig._skeleton.set_bone_pose_rotation(1, Quaternion(Vector3.FORWARD, 1.2))
	fig._skeleton.set_bone_pose_position(1, Vector3(0.3, 0.2, 0))
	fig._follow_bones()
	var at := fig._skeleton.get_bone_global_pose(1).origin
	assert_between(hold.position.distance_to(at), 0.0, 0.0001, "where the bone is")
	assert_between(hold.basis.get_euler().length(), 0.0, 0.0001, "standing as the figure stands, whatever the bone's turn")
	fig.wear([])
	assert_true(fig._upright.is_empty(), "no longer followed once off")
	fig.free()
