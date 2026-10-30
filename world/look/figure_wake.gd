class_name FigureWake
extends Node
## Figures that touch the world (a game's Visual Polish Plan E42, E43; Look.PAINTED `wakes` and `plants_part`): rings
## spread across the water round anyone standing in it, with foam at their legs, and reeds, grass and bushes lean
## aside as they walk through. Hands the nearest eight figures' feet to the water (lit_water.gdshader) and to the
## plants' wind (wind.gdshaderinc) each frame. Made by Atmosphere only when the game asks for either.

const MAX := 8
## Seconds between looks for the place's figures (they come and go with fights and conversations).
const SCAN_EVERY := 0.4
## How far a figure moves in a second to count as walking (world units).
const WALKING := 0.3

var atmosphere: Atmosphere
var wakes := 0.0
var part := 0.0
var _figures: Array[Node3D] = []
var _last: Dictionary = {}   ## figure -> where it stood last frame
var _scan := 0.0


static func build(atmo: Atmosphere, settings: Dictionary) -> FigureWake:
	var w := float(settings.get("wakes", 0.0))
	var p := float(settings.get("plants_part", 0.0)) if Graphics.world_touch() else 0.0
	if (w <= 0.0 and p <= 0.0) or not Look.modern():
		return null
	var f := FigureWake.new()
	f.name = "FigureWake"
	f.atmosphere = atmo
	f.wakes = w
	f.part = p
	atmo.add_child(f)
	return f


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN_EVERY
		_find_figures()
	var feet := feet_of(_figures, _last, delta, _centre())
	_hand_out(feet)


## Every figure drawn in the place (8-direction sprites) that is shown.
func _find_figures() -> void:
	_figures.clear()
	var view := atmosphere.get_parent()
	if view == null:
		return
	for n in view.find_children("*", "AnimatedSprite3D", true, false):
		if n is DirectionalSprite and (n as Node3D).is_visible_in_tree():
			_figures.append(n as Node3D)


## Where the camera looks, so the eight nearest it are the ones handed on.
func _centre() -> Vector3:
	var cam := atmosphere.get_viewport().get_camera_3d() if atmosphere.is_inside_tree() else null
	if cam == null:
		return Vector3.ZERO
	var fwd := -cam.global_basis.z
	var t := -cam.global_position.y / fwd.y if absf(fwd.y) > 0.01 else 0.0
	return cam.global_position + fwd * maxf(t, 0.0)


## The feet of the `MAX` figures nearest `centre`, each Vector4(x, y, z, 1 walking / 0 standing), remembering where
## each stood in `last`.
static func feet_of(figures: Array[Node3D], last: Dictionary, delta: float, centre: Vector3) -> PackedVector4Array:
	var near := figures.filter(func(f: Node3D) -> bool: return is_instance_valid(f))
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(centre) < b.global_position.distance_squared_to(centre))
	var out := PackedVector4Array()
	for f: Node3D in near.slice(0, MAX):
		var p := f.global_position
		var walking := 0.0
		if last.has(f) and delta > 0.0:
			walking = 1.0 if (last[f] as Vector3).distance_to(p) / delta > WALKING else 0.0
		last[f] = p
		out.append(Vector4(p.x, p.y, p.z, walking))
	return out


func _hand_out(feet: PackedVector4Array) -> void:
	var padded := feet.duplicate()
	padded.resize(MAX)
	if wakes > 0.0 and atmosphere.water != null:
		_feed(atmosphere.water, padded, feet.size(), "figure_wake", wakes)
	if part > 0.0:
		for m: ShaderMaterial in Flora.materials():
			_feed(m, padded, feet.size(), "figure_part", part)


static func _feed(m: ShaderMaterial, feet: PackedVector4Array, count: int, strength_name: String, strength: float) -> void:
	m.set_shader_parameter("figures", feet)
	m.set_shader_parameter("figure_count", count)
	m.set_shader_parameter(strength_name, strength)
