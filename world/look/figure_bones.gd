class_name FigureBones
extends SkeletonModifier3D
## A 3D figure's bones grown or shrunk on top of whatever clip it plays (a manifest entry's "bones", ModelFigure):
## one rigged body worn by several creatures can still differ in build, as a boy's bigger head on a grown body scaled
## down. Each bone's scale carries its children and the skin weighted to them, about the bone's own joint.

## bone index -> how many times its size
var scales: Dictionary = {}


## The skeleton's bone called `bone`, ignoring case and a library or armature prefix (mixamorig:Head, which Godot's
## import makes mixamorig_Head; Armature|Head), or -1; `rig_bones`, a figure's rig's names (FigureModels.rig_bones), first.
static func bone_named(skel: Skeleton3D, bone: String, rig_bones: Dictionary = {}) -> int:
	if not rig_bones.is_empty():   # what the figure's rig calls it (FigureModels.rig_bones), when it says
		var mapped := FigureModels.bone(skel, bone, rig_bones)
		if mapped >= 0:
			return mapped
	var want := bone.to_lower()
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i).to_lower()
		if n == want or n.ends_with(":" + want) or n.ends_with("|" + want) or n.ends_with("_" + want):
			return i
	return -1


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	for i: int in scales:
		skel.set_bone_pose_scale(i, skel.get_bone_pose_scale(i) * float(scales[i]))
