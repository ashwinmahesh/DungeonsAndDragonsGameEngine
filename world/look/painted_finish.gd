class_name PaintedFinish
extends RefCounted
## A game's painted finish (Look.PAINTED, data/campaign.json's "painted" and a mood's own) handed to the screen pass
## (shaders/post/painted.gdshaderinc): gouache strokes and values, dry brush, pigment edges and ink, the shadows of
## boughs overhead, and the moon in the water. Atmosphere applies it when a place opens and aims the moon each frame.


## Sets the screen pass `post` for `s` (Look.painted_settings), or turns every part off (Classic, or a game that names
## none): the shader's own defaults draw nothing.
static func apply(post: ShaderMaterial, s: Dictionary) -> void:
	if post == null:
		return
	var on := Look.modern()
	var strokes := float(s["strokes"]) if on and Graphics.paint_strokes() else 0.0
	post.set_shader_parameter("paint_amount", strokes)
	post.set_shader_parameter("paint_radius", float(s["stroke_radius"]))
	post.set_shader_parameter("paint_sharpness", float(s["stroke_sharpness"]))
	var ramp := ramp_texture(s["ramp"] as Array) if on and not (s["ramp"] as Array).is_empty() else null
	post.set_shader_parameter("paint_ramp", ramp)
	post.set_shader_parameter("paint_ramp_amount", float(s["ramp_amount"]) if ramp != null else 0.0)
	post.set_shader_parameter("paint_steps", float(s["steps"]))
	post.set_shader_parameter("paint_step_edge", float(s["step_edge"]))
	post.set_shader_parameter("paint_keep_hue", float(s["keep_hue"]))
	post.set_shader_parameter("paint_keep_light", float(s["keep_light"]))
	post.set_shader_parameter("paint_black", float(s["ink_below"]) if ramp != null else 0.0)
	post.set_shader_parameter("paint_ink", Look.color(str(s["ink"])))
	post.set_shader_parameter("paint_brush", float(s["brush"]) if ramp != null else 0.0)
	post.set_shader_parameter("paint_brush_scale", float(s["brush_scale"]))
	post.set_shader_parameter("paint_edges", float(s["edges"]) if on else 0.0)
	post.set_shader_parameter("paint_lines", float(s["lines"]) if on else 0.0)
	var boughs := float(s["boughs"]) if on else 0.0
	post.set_shader_parameter("branch_strength", boughs)
	if boughs > 0.0:
		post.set_shader_parameter("branch_tex", bough_texture())
		post.set_shader_parameter("branch_height", float(s["bough_height"]))
		post.set_shader_parameter("branch_scale", float(s["bough_scale"]))
		post.set_shader_parameter("branch_sway", float(s["bough_sway"]))
		post.set_shader_parameter("use_branch_mask", bool(s["boughs_by_trees"]))
	post.set_shader_parameter("moon_water", 0.0)   # (aim_moon sets it each frame, at night)
	post.set_shader_parameter("moon_water_size", float(s["moon_water_size"]))
	post.set_shader_parameter("moon_water_bite", float(s["moon_water_bite"]))
	post.set_shader_parameter("moon_water_ripple", float(s["moon_water_ripple"]))


## The moon in the water, each frame: where a level mirror under the camera's gaze looks, so the crescent lies in the
## water the camera sees whichever way it turns; as bright as the moon in tonight's sky (the screen pass's sky_moon),
## in its colour. The bough shadows fall away from the moon too.
static func aim_moon(post: ShaderMaterial, s: Dictionary, cam: Camera3D) -> void:
	if post == null or cam == null or float(s["moon_water"]) <= 0.0 or not Look.modern():
		return
	var fwd := -cam.global_basis.z
	post.set_shader_parameter("moon_water_dir", Vector3(fwd.x, -fwd.y, fwd.z).normalized())
	var sky: Variant = post.get_shader_parameter("sky_moon")
	post.set_shader_parameter("moon_water", float(s["moon_water"]) * clampf(float(sky) if sky != null else 0.0, 0.0, 1.0))
	var colour: Variant = post.get_shader_parameter("sky_moon_colour")
	if colour is Color:
		post.set_shader_parameter("moon_water_colour", colour)


## A value ramp from palette names, darkest first.
static func ramp_texture(names: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colours := PackedColorArray()
	for i in names.size():
		offsets.append(float(i) / maxf(names.size() - 1, 1))
		colours.append(Look.color(str(names[i])))
	g.offsets = offsets
	g.colors = colours
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


static var _boughs: ImageTexture


## Bare boughs as a tiling silhouette (white sky, black wood): a few limbs forking into twigs, made once.
static func bough_texture() -> ImageTexture:
	if _boughs != null:
		return _boughs
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 6:
		_limb(img, rng, Vector2(rng.randf() * size, rng.randf() * size), rng.randf() * TAU, size * 0.32, 5.0, 0)
	img.generate_mipmaps()
	_boughs = ImageTexture.create_from_image(img)
	return _boughs


static func _limb(img: Image, rng: RandomNumberGenerator, p: Vector2, a: float, length: float, width: float,
		depth: int) -> void:
	var size := img.get_width()
	var steps := int(length)
	for i in steps:
		a += rng.randf_range(-0.12, 0.12)
		p += Vector2(cos(a), sin(a))
		var w := maxi(int(round(width * (1.0 - 0.5 * float(i) / steps))), 1)
		var at := Vector2i(posmod(int(p.x), size), posmod(int(p.y), size))
		img.fill_rect(Rect2i(at - Vector2i(w / 2, w / 2), Vector2i(w, w)).intersection(Rect2i(0, 0, size, size)), Color.BLACK)
	if depth < 4 and width > 0.8:
		for k in rng.randi_range(2, 3):
			_limb(img, rng, p, a + rng.randf_range(-0.9, 0.9), length * 0.62, width * 0.6, depth + 1)
