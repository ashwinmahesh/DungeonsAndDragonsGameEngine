class_name WindowView
extends RefCounted
## What the windows of a moving place show outside (a train's carriages, a boat's cabins): smoke, cloud or mist streaming
## past every pane at three speeds, so the room reads as moving. A location turns it on in its map:
##   "window_view": {"colours": ["night_deep", "mist_blue", "moonlight"], "streams": [-1, 0], "speed": 1.0,
##                   "strength": 0.9, "rise": 0.05}
## `colours` are palette names from the deepest to the lightest, `streams` the way the outside moves past in world x and
## z (a train heading east sees it stream west: [-1, 0]), `speed` world units a second for the nearest bank. Every
## piece hung on a wall that has a glass decal (a window model's `glass` socket) gets the view over that decal, the
## frame and bars still showing through; a window drawn as a flat picture (its art named "window...") gets it over the
## whole picture's lighter part. Without the key nothing changes. Built by SetDressing when it hangs a piece.

const SHADER := preload("res://addons/dnd_core/shaders/world/window_view.gdshader")
const NODE_NAME := "WindowView"
const DEFAULT_COLOURS := ["night_deep", "mist_blue", "moonlight"]
## How far in front of the glass the view lies, so it never fights the decal for depth.
const LIFT := 0.004


## The place's `window_view` (a board's meta of that name wins, for tests and tools), or {}.
static func spec_of(board: ArenaBoard) -> Dictionary:
	if board == null:
		return {}
	if board.has_meta("window_view"):
		return board.get_meta("window_view") as Dictionary
	if board.place == "":
		return {}
	var loc := Compendium.shared().get_entry("locations", board.place)
	return (loc.get("map", {}) as Dictionary).get("window_view", {}) as Dictionary


## Gives the hung piece `piece` (a model's holder, or a flat picture) the place's view; how many panes got one.
static func dress(board: ArenaBoard, piece: Node3D, art: String = "") -> int:
	var spec := spec_of(board)
	if spec.is_empty() or piece == null:
		return 0
	return dress_with(piece, spec, art)


static func dress_with(piece: Node3D, spec: Dictionary, art: String = "") -> int:
	var count := 0
	for n in piece.find_children("Decal_glass*", "Sprite3D", true, false):
		count += _over(n as Sprite3D, spec, piece.rotation.y + (n as Sprite3D).rotation.y)
	if count == 0 and piece is Sprite3D and art.begins_with("window"):
		count += _over(piece as Sprite3D, spec, piece.rotation.y)
	return count


## The view over one glass sprite, as its child at its place and size; `yaw` is the way the pane faces in the world.
static func _over(glass: Sprite3D, spec: Dictionary, yaw: float) -> int:
	if glass.texture == null:
		return 0
	var tex_size := glass.texture.get_size()
	var region := glass.region_rect if glass.region_enabled else Rect2(Vector2.ZERO, tex_size)
	var size := region.size * glass.pixel_size
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.name = NODE_NAME
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = material(spec, size, yaw, glass.texture, Rect2(region.position / tex_size, region.size / tex_size))
	mi.position = Vector3(glass.offset.x, glass.offset.y, 0.0) * glass.pixel_size + Vector3(0, 0, LIFT)
	glass.add_child(mi)
	return 1


## The view's material: its colours, the way and speed it streams along a pane that faces `yaw`, and the glass mask.
static func material(spec: Dictionary, size: Vector2, yaw: float, mask: Texture2D = null, mask_uv := Rect2(0, 0, 1, 1)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var names := spec.get("colours", DEFAULT_COLOURS) as Array
	var keys := ["deep", "mid", "light"]
	for i in keys.size():
		var name := str(names[mini(i, names.size() - 1)]) if not names.is_empty() else str(DEFAULT_COLOURS[i])
		mat.set_shader_parameter(keys[i], Look.color(name))
	mat.set_shader_parameter("scroll", scroll_along(spec, yaw))
	mat.set_shader_parameter("rise", float(spec.get("rise", 0.05)))
	mat.set_shader_parameter("strength", clampf(float(spec.get("strength", 0.9)), 0.0, 1.0))
	mat.set_shader_parameter("extent", size)
	mat.set_shader_parameter("use_mask", mask != null)
	if mask != null:
		mat.set_shader_parameter("mask", mask)
		mat.set_shader_parameter("mask_region", Vector4(mask_uv.position.x, mask_uv.position.y, mask_uv.size.x, mask_uv.size.y))
	return mat


## How fast the outside moves along the pane's own right (world units a second; negative is to its left) for a pane
## facing `yaw`: the place's `streams` way laid on the pane.
static func scroll_along(spec: Dictionary, yaw: float) -> float:
	var s := spec.get("streams", [-1, 0]) as Array
	var way := Vector2(float(s[0]), float(s[1])) if s.size() == 2 else Vector2(-1, 0)
	if way.length() > 0.0:
		way = way.normalized()
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
	return (way.x * right.x + way.y * right.z) * float(spec.get("speed", 1.0))
