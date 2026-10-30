class_name GroundMarks
extends RefCounted
## Marks a fight leaves on the ground (a game's Visual Polish Plan E49; Look.PAINTED `marks`, how many stay at once, 0
## none): blood where a creature fell, scorch and frost where spells burst, acid and rot stains. Each is a splat decal
## in its kind's colour pressed into the ground; the oldest goes when the cap is reached, and every mark fades away
## over `marks_fade` seconds after it is left (0: it stays until the place closes).

## Each kind's colour (a palette name), how much of the ground's own colour shows through, and its glow (scorch smoulders).
const KINDS := {
	"blood": {"colour": "blood_deep", "mix": 0.85, "glow": 0.0},
	"ichor": {"colour": "bog", "mix": 0.8, "glow": 0.0},
	"scorch": {"colour": "void", "mix": 0.9, "glow": 0.15},
	"frost": {"colour": "frost", "mix": 0.7, "glow": 0.0},
	"stain": {"colour": "sickly", "mix": 0.75, "glow": 0.1},
	"rot": {"colour": "ink", "mix": 0.85, "glow": 0.0},
}

static var _left: Array[Decal] = []
static var _splats: Array[Texture2D] = []


## Leaves a mark of `kind` on the ground at `at` (a point on the ground), `radius` world units across, under `parent`.
## Does nothing unless the game turns marks on, or for a kind it doesn't know.
static func leave(parent: Node3D, at: Vector3, kind: String, radius: float = 0.6) -> void:
	var s := Look.painted_settings()
	var cap := int(s["marks"])
	if cap <= 0 or not KINDS.has(kind) or parent == null or not Look.modern():
		return
	_left = _live()
	while _left.size() >= cap:
		var old := _left.pop_front() as Decal
		old.queue_free()
	var spec := KINDS[kind] as Dictionary
	var d := Decal.new()
	d.name = "Mark"
	var tex := _splat(_left.size() + int(at.x * 7.0 + at.z * 13.0))
	d.texture_albedo = tex
	d.modulate = Look.color(str(spec["colour"]))
	d.albedo_mix = float(spec["mix"])
	if float(spec["glow"]) > 0.0:
		d.texture_emission = tex
		d.emission_energy = float(spec["glow"])
	d.size = Vector3(radius * 2.0, 1.0, radius * 2.0)
	d.normal_fade = 0.4
	d.cull_mask = 1
	parent.add_child(d)
	d.global_position = at + Vector3(0, 0.3, 0)
	d.rotation.y = fmod(at.x * 3.7 + at.z * 1.3, TAU)
	_left.append(d)
	var fade := float(s["marks_fade"])
	if fade > 0.0:
		var tw := d.create_tween()
		tw.tween_interval(fade * 0.6)
		tw.tween_property(d, "modulate:a", 0.0, fade * 0.4)
		tw.tween_callback(d.queue_free)


## How many marks are on the ground now (tests).
static func count() -> int:
	return _live().size()


## The marks still on the ground: a place or fight that closed freed its own, and a freed one can't even be passed to a
## typed check, so each is looked at untyped.
static func _live() -> Array[Decal]:
	var out: Array[Decal] = []
	for d: Variant in _left:
		if is_instance_valid(d):
			out.append(d as Decal)
	return out


## A splat: a blot with a ragged edge and a few drops round it (white on clear; the decal tints it). Four kept.
static func _splat(i: int) -> Texture2D:
	if _splats.is_empty():
		for k in 4:
			_splats.append(_make_splat(k))
	return _splats[posmod(i, _splats.size())]


static func _make_splat(seed_: int) -> Texture2D:
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 101 + seed_
	var lobes: Array[float] = []
	for k in 9:
		lobes.append(rng.randf_range(0.7, 1.15))
	for y in n:
		for x in n:
			var p := Vector2(x - n / 2.0, y - n / 2.0) / (n * 0.3)
			var a := fposmod(p.angle(), TAU) / TAU * lobes.size()
			var r := lerpf(lobes[int(a) % lobes.size()], lobes[(int(a) + 1) % lobes.size()], a - floorf(a))
			var alpha := clampf((r - p.length()) * 6.0, 0.0, 1.0)
			if alpha > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	for k in 6:
		var c := Vector2(n / 2.0, n / 2.0) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(n * 0.36, n * 0.46)
		img.fill_rect(Rect2i(Vector2i(c) - Vector2i(2, 2), Vector2i(4, 4)).intersection(Rect2i(0, 0, n, n)), Color.WHITE)
	return ImageTexture.create_from_image(img)
