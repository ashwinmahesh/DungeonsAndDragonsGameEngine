class_name BuildingMorph
extends RefCounted
## A place's buildings warping on screen (the Crooked House turning from a tidy manor into its true ruined shape). The catalog's
## building_kit.bend.morph names the place ({"<place>": {"tidy": 0.2}}): its houses are built with a second, tidier bend held as a
## blend shape on their walls and roofs (BuildingKit.merge_morph). The weight is 0 for the houses as built (their bend, with
## everything hung on their walls where it belongs) and 1 for the tidy shape. A campaign asks for a weight through `follow`
## (from CampaignLook.refresh); a change plays as a warp that overshoots and settles. A place with no morph in the catalog has
## no blend shapes, and nothing here does anything.

const META_WEIGHT := &"building_morph_weight"
const META_TARGET := &"building_morph_target"
const META_NONE := &"building_morph_none"


## Every house mesh of `board` that carries the blend shape.
static func meshes(board: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if board == null:
		return out
	for n in board.find_children("*", "MeshInstance3D", true, false):
		if n.has_meta("morph"):
			out.append(n as MeshInstance3D)
	return out


static func has_morph(board: Node) -> bool:
	return not meshes(board).is_empty()


## The weight now (0 as built, 1 tidy).
static func weight(board: Node) -> float:
	return float(board.get_meta(META_WEIGHT, 0.0)) if board != null else 0.0


## Sets every house's weight at once (not clamped: past 0 the houses lean further than built, past 1 they are straighter than tidy).
static func set_weight(board: Node, w: float) -> void:
	if board == null:
		return
	board.set_meta(META_WEIGHT, w)
	for mi in meshes(board):
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0:
			mi.set_blend_shape_value(0, w)


## Plays the weight from where it is to `to` over `seconds`: an elastic ease, so the houses overshoot and wobble before they settle.
## Returns the tween (null where nothing can morph).
static func play(board: Node, to: float, seconds: float) -> Tween:
	if board == null or not board.is_inside_tree() or not has_morph(board):
		set_weight(board, to)
		return null
	var tween := board.create_tween()
	tween.tween_method(func(w: float) -> void: set_weight(board, w), weight(board), to, seconds) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween


## Asks the buildings to be at weight `target`: the first time at once (a place built after its change is already settled), then
## whenever the target changes, as a warp over `seconds`. Call it as often as you like (CampaignLook.refresh).
static func follow(board: Node, target: float, seconds: float = 2.5) -> void:
	if board == null or board.has_meta(META_NONE):
		return
	if not board.has_meta(META_TARGET):
		if not has_morph(board):
			board.set_meta(META_NONE, true)   # (a place without a morph is asked once)
			return
		board.set_meta(META_TARGET, target)
		set_weight(board, target)
		return
	if not is_equal_approx(float(board.get_meta(META_TARGET)), target):
		board.set_meta(META_TARGET, target)
		play(board, target, seconds)
