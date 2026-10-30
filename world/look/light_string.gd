class_name LightString
extends Node3D
## A string of lantern bulbs hung between two points, sagging (a game's Visual Polish Plan E35): every bulb
## glows (so the bloom catches it) and lays a warm pool on the ground below, but only one real light in every
## `per_light` bulbs lights the figures, so a street can carry dozens of bulbs for the price of a few lamps.

## The bulbs' and the light's colour, how bright a bulb glows, and how far its light and pool reach (world units).
var colour := Color("#ff7a1a")
var glow := 6.0
var reach := 1.1


## Hangs a string from `a` to `b` (world positions of its two ends), sagging `sag` units at the middle, a bulb every
## `spacing` units and a real light every `per_light` bulbs; `floor_at` gives the ground's height under a point.
static func hang(parent: Node3D, a: Vector3, b: Vector3, floor_at: Callable, sag := 0.4, spacing := 0.45,
		per_light := 5, colour_ := Color("#ff7a1a")) -> LightString:
	var s := LightString.new()
	s.name = "LightString"
	s.colour = colour_
	parent.add_child(s)
	s._build(a, b, floor_at, sag, spacing, per_light)
	return s


func _build(a: Vector3, b: Vector3, floor_at: Callable, sag: float, spacing: float, per_light: int) -> void:
	var n := maxi(int(a.distance_to(b) / spacing), 2)
	var points: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		points.append(a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0))
	# The wire: thin dark segments between the bulbs.
	var wire := MultiMeshInstance3D.new()
	var wm := MultiMesh.new()
	wm.transform_format = MultiMesh.TRANSFORM_3D
	var seg := CylinderMesh.new()
	seg.top_radius = 0.008
	seg.bottom_radius = 0.008
	seg.height = 1.0
	seg.radial_segments = 4
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.03, 0.025, 0.03)
	seg.material = wire_mat
	wm.mesh = seg
	wm.instance_count = n
	for i in n:
		var p0 := points[i]
		var p1 := points[i + 1]
		var mid := (p0 + p1) * 0.5
		var up := (p1 - p0).normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var basis := Basis(side, up * p0.distance_to(p1), side.cross(up))
		wm.set_instance_transform(i, Transform3D(basis, mid))
	wire.multimesh = wm
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wire)
	# The bulbs, glowing past white so the bloom takes them.
	var bulbs := MultiMeshInstance3D.new()
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	var bulb := SphereMesh.new()
	bulb.radius = 0.035
	bulb.height = 0.08
	bulb.radial_segments = 8
	bulb.rings = 4
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = colour
	bulb_mat.emission_enabled = true
	bulb_mat.emission = colour
	bulb_mat.emission_energy_multiplier = glow
	bulb.material = bulb_mat
	bm.mesh = bulb
	bm.instance_count = n - 1
	for i in range(1, n):
		bm.set_instance_transform(i - 1, Transform3D(Basis(), points[i] + Vector3(0, -0.07, 0)))
	bulbs.multimesh = bm
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulbs)
	# A warm pool on the ground under every bulb, and a real light (no shadow) under every `per_light`th one.
	var pool_tex := _pool_texture()
	for i in range(1, n):
		var p := points[i]
		var ground := float(floor_at.call(p))
		var d := Decal.new()
		d.size = Vector3(reach, maxf(p.y - ground, 0.5) + 1.0, reach)
		d.texture_albedo = pool_tex
		d.texture_emission = pool_tex
		d.emission_energy = 0.35
		d.albedo_mix = 0.0
		d.modulate = colour
		d.upper_fade = 0.05
		d.lower_fade = 0.3
		d.cull_mask = 1
		add_child(d)
		d.global_position = Vector3(p.x, (p.y + ground) * 0.5 - 0.3, p.z)
		if i % per_light == per_light / 2:
			var l := OmniLight3D.new()
			l.light_color = colour
			l.light_energy = 1.4
			l.omni_range = reach * 3.0
			l.omni_attenuation = 1.6
			l.shadow_enabled = false
			# A lantern to the atmosphere, left out of the lamp shadows' budget (Atmosphere._update_lamp_shadows).
			l.set_meta("light_kind", "lantern")
			l.set_meta("no_shadow", true)
			add_child(l)
			l.global_position = p + Vector3(0, -0.15, 0)
			LightFlicker.give(l, "lantern")


static var _pool: Texture2D


## A soft round pool of light, brightest in the middle (white on clear; the decal tints it).
static func _pool_texture() -> Texture2D:
	if _pool != null:
		return _pool
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	# Fading in colour as well as alpha: a decal's emission reads the colour alone.
	g.colors = PackedColorArray([Color(0.6, 0.6, 0.6, 0.6), Color(0.2, 0.2, 0.2, 0.2), Color(0, 0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_pool = t
	return _pool


## A place's own strings (a location's "light_strings": {from, to: [x, z] squares; height_ft, the ends' height above
## the ground, 9; sag_ft at the middle, 2; colour, a palette name, "flame"; every, a real light every so many bulbs,
## 5}), hung on `board`.
static func hang_all(board: ArenaBoard, strings: Array) -> Array[LightString]:
	var out: Array[LightString] = []
	var floor_at := func(p: Vector3) -> float: return board.floor_y(Vector2i(floori(p.x), floori(p.z)))
	for v: Variant in strings:
		var d := v as Dictionary
		if d == null or not d.has("from") or not d.has("to"):
			continue
		var ends: Array[Vector3] = []
		for key: String in ["from", "to"]:
			var c := d[key] as Array
			var p := board.cell_center(Vector2i(int(c[0]), int(c[1])))
			p.y = float(floor_at.call(p)) + float(d.get("height_ft", 9.0)) / 5.0
			ends.append(p)
		out.append(hang(board, ends[0], ends[1], floor_at, float(d.get("sag_ft", 2.0)) / 5.0, 0.45,
			maxi(int(d.get("every", 5)), 1), Look.color(str(d.get("colour", "flame")))))
	return out
