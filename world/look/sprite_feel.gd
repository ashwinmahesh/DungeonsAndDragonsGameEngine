class_name SpriteFeel
extends RefCounted
## A figure's game feel (GameFeel's flash and sway; shaders/world/sprite_feel.gdshaderinc): DirectionalSprite hands its
## material here each frame. The flash fades out over its seconds; the sway follows the wind the place's plants move in
## (Flora sets `wind` as it dresses a place), turned to the screen: a wind blowing across the view leans the figures
## downwind, one blowing along it only stirs them.

## The place's wind: x and y its direction on the ground (x east, y south), z its strength (0 still to 1 a gale).
static var wind := Vector3(0.9, 0.35, 0.3)


## The wind of a place in `mood` (its mist's wind, stronger in rain and storms, as Flora's plants), or still air
## indoors.
static func set_place(mood: Dictionary, outdoors: bool) -> void:
	var w := (mood.get("mist", {}) as Dictionary).get("wind", [0.35, 0.12]) as Array
	var dir := Vector2(float(w[0]), float(w[1])) if w.size() >= 2 else Vector2(0.35, 0.12)
	var strength := 0.12 + 0.38 * dir.length()
	for e: Variant in mood.get("weather", []) as Array:
		if (str((e as Dictionary).get("kind", "")) if e is Dictionary else str(e)) == "rain":
			strength += 0.1
	if bool(mood.get("lightning", false)):
		strength += 0.1
	wind = Vector3(dir.x, dir.y, clampf(strength, 0.08, 1.0) if outdoors else 0.0)


## Sets the feel uniforms of `m` for a figure `height` world units tall with its own `phase`, flashing at `flash`
## (0 to 1), seen by `cam`.
static func apply(m: ShaderMaterial, cam: Camera3D, height: float, phase: float, flash: float) -> void:
	var white := clampf(GameFeel.num("flash"), 0.0, 1.0)
	var sway := GameFeel.num("sway")
	if white <= 0.0 and sway <= 0.0:
		return   # a game without either: the shader's defaults, untouched
	m.set_shader_parameter("feel_flash", clampf(flash, 0.0, 1.0) * white)
	if sway <= 0.0:
		m.set_shader_parameter("feel_sway", Vector2.ZERO)
		return
	var right := cam.global_basis.x
	var across := Vector2(wind.x, wind.y).normalized().dot(Vector2(right.x, right.z).normalized()) if Vector2(wind.x, wind.y).length() > 0.01 else 0.0
	var strength := clampf(wind.z, 0.0, 1.0) / 0.3
	var flutter := sway * 0.35 * (0.4 + strength) if strength > 0.0 else 0.0
	m.set_shader_parameter("feel_sway", Vector2(sway * strength * across, flutter))
	m.set_shader_parameter("feel_height", height)
	m.set_shader_parameter("feel_phase", phase)
