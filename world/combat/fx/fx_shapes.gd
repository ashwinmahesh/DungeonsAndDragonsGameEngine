class_name FxShapes
extends RefCounted
## Drawn effect shapes over blows and impacts (GameFeel's `shapes`, after the AI methods report's FX1): a slash
## crescent across a melee hit, a burst star where a missile lands, speed lines round a critical hit, an ink splash on
## a kill, a sigil where a spell is cast. Each is one flat picture (art/vfx/shapes/<kind>.png, the game's first, else
## one drawn here in code) animated on twos: it grows, holds and is eaten away in steps of 1/shape_fps seconds, boiling
## a little each step, coloured by the effect's flavour with an ink line (shaders/fx/fx_shape.gdshader). The image model
## draws good single shapes and poor flipbooks, so the motion is all here.

const SHADER := preload("res://addons/dnd_core/shaders/fx/fx_shape.gdshader")
const DIR := "art/vfx/shapes/"
const KINDS: Array[String] = ["slash", "burst", "speed", "splash", "sigil", "spark"]
## Each kind's life in seconds (at the combat speed), how big it grows from and to (times its size) and how it turns.
const MOTION := {
	"slash": {"time": 0.28, "from": 0.7, "to": 1.15, "turn": 0.25},
	"burst": {"time": 0.32, "from": 0.4, "to": 1.2, "turn": 0.4},
	"speed": {"time": 0.36, "from": 1.3, "to": 0.9, "turn": 0.0},
	"splash": {"time": 0.5, "from": 0.6, "to": 1.1, "turn": 0.0},
	"sigil": {"time": 0.6, "from": 0.8, "to": 1.05, "turn": 0.6},
	"spark": {"time": 0.22, "from": 0.5, "to": 1.3, "turn": 0.0},
}
## Procedural fallbacks are drawn at this size (pixels).
const SIDE := 256

static var _textures: Dictionary = {}
## Cosmetic randomness (never the dice).
static var rng := RandomNumberGenerator.new()


static func on() -> bool:
	return GameFeel.flag("shapes")


## Plays shape `kind` at `at` under `parent`, `size` world units across, coloured by `cols` (an effect's colours:
## core, glow), turned by `angle` radians on the screen. Nothing when the game has shapes off.
static func play(parent: Node3D, kind: String, at: Vector3, cols: Dictionary, size: float = 1.0, angle: float = 0.0,
		pace: float = 1.0) -> MeshInstance3D:
	if not on() or parent == null or not parent.is_inside_tree() or not MOTION.has(kind):
		return null
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.render_priority = FxKit.PRIORITY
	m.set_shader_parameter("shape_tex", texture(kind))
	m.set_shader_parameter("fill", cols.get("core", Color.WHITE))
	m.set_shader_parameter("body", cols.get("glow", Color.ORANGE))
	m.set_shader_parameter("ink", Look.color("void"))
	m.set_shader_parameter("spin", angle)
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	var mo := MOTION[kind] as Dictionary
	var s := size * GameFeel.num("shape_size")
	var fps := maxf(1.0, GameFeel.num("shape_fps"))
	var steps := maxi(2, roundi(float(mo["time"]) * pace * fps))
	var turn := float(mo["turn"]) * (1.0 if rng.randf() < 0.5 else -1.0)
	# On twos: one held drawing per step, not a smooth tween.
	var tw := mi.create_tween()
	for i in steps + 1:
		var k := float(i) / float(steps)
		tw.tween_callback(func() -> void:
			var grow := lerpf(float(mo["from"]), float(mo["to"]), 1.0 - pow(1.0 - minf(k * 1.6, 1.0), 3.0))
			mi.scale = Vector3.ONE * s * grow
			m.set_shader_parameter("life", k)
			m.set_shader_parameter("step_no", float(i) + rng.randf())
			m.set_shader_parameter("spin", angle + turn * k))
		tw.tween_interval(1.0 / fps)
	tw.tween_callback(mi.queue_free)
	return mi


## The shape's picture: the game's or the engine's art/vfx/shapes/<kind>.png, else one drawn in code.
static func texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind] as Texture2D
	var tex: Texture2D = null
	var rel := DIR + kind + ".png"
	if ArtPaths.exists(rel):
		tex = load(ArtPaths.of(rel)) as Texture2D
	if tex == null:
		var img := drawn(kind)
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	_textures[kind] = tex
	return tex


## A shape drawn in code (white, its alpha the shape: 1 in its solid middle, falling off toward its thin parts).
static func drawn(kind: String) -> Image:
	var img := Image.create(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = hash(kind)
	var spikes: Array[float] = []
	for i in 12:
		spikes.append(r.randf_range(0.55, 1.0))
	for y in SIDE:
		for x in SIDE:
			var p := Vector2(x, y) / float(SIDE) * 2.0 - Vector2.ONE
			var a := _alpha(kind, p, spikes)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return img


static func _alpha(kind: String, p: Vector2, spikes: Array[float]) -> float:
	var rad := p.length()
	var ang := atan2(p.y, p.x)
	match kind:
		"slash":
			# A crescent: the band between two offset circles, thickest in its middle, tapering to points.
			var outer := 0.85 - rad
			var inner := (p - Vector2(0.18, -0.12)).length() - 0.7
			var band := minf(outer, inner)
			var taper := clampf(1.0 - absf(angle_difference(ang, atan2(0.12, -0.18))) / 1.9, 0.0, 1.0)
			return band * 9.0 * taper
		"burst", "spark":
			# A star: n points of their own lengths round a solid middle.
			var n := 8 if kind == "burst" else 4
			var f := fposmod(ang / TAU * n, 1.0)
			var i := int(floor(fposmod(ang / TAU * n, float(n))))
			var reach := (spikes[i % spikes.size()] if kind == "burst" else 1.0) * 0.95
			var spike := reach * pow(1.0 - absf(f - 0.5) * 2.0, 2.2)
			var core := 0.32 if kind == "burst" else 0.12
			return (maxf(core, spike) - rad) * 6.0 + (0.6 if rad < core * 0.7 else 0.0)
		"speed":
			# Speed lines: thin wedges out from a clear middle.
			var w := fposmod(ang / TAU * 28.0, 1.0)
			var lit := spikes[int(floor(fposmod(ang / TAU * 28.0, 28.0))) % spikes.size()] > 0.7
			var wedge := 1.0 - absf(w - 0.5) * 2.0
			return (wedge - 0.75) * 6.0 * (1.0 if lit else 0.0) * smoothstep(0.35, 0.6, rad) * (1.0 - smoothstep(0.85, 1.0, rad))
		"splash":
			# An ink splash: a lumpy blot with droplets round it.
			var lump := 0.45 + 0.12 * sin(ang * 5.0 + spikes[0] * 6.0) + 0.06 * sin(ang * 11.0 + spikes[1] * 6.0)
			var blot := (lump - rad) * 7.0
			for k in 6:
				var c := Vector2(cos(k * 1.1 + spikes[k] * 3.0), sin(k * 1.1 + spikes[k] * 3.0)) * (0.62 + spikes[k + 6] * 0.25)
				blot = maxf(blot, (0.07 * spikes[k] + 0.03 - (p - c).length()) * 14.0)
			return blot
		"sigil":
			# A ring with marks round it and a cross through it.
			var ring := (0.05 - absf(rad - 0.75)) * 16.0
			var ticks := (0.04 - absf(rad - 0.9)) * 16.0 * (1.0 if fposmod(ang / TAU * 16.0, 1.0) >= 0.5 else 0.0)
			var cross := (0.035 - minf(absf(p.x), absf(p.y))) * 20.0 * (1.0 if rad <= 0.6 else 0.0)
			return maxf(ring, maxf(ticks, cross))
	return 0.0
