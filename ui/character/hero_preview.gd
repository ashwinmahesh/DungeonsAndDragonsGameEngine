class_name HeroPreview
extends Control
## The custom hero's live sprite in the creator (docs/ui/character_creation.md, Appearance): the paper doll as the
## game puts it together (HeroLook), standing in a gothic arch and slowly turning through the 8 directions, or
## walking, or swinging its attack once. Taller picks stand taller in the arch.
##
## A look with a 3D body (HeroLook.figure_for) shows that figure instead, on a turntable in a little stage of its own
## (a SubViewport): it turns slowly while standing, can be dragged round, walks, runs, swings, casts and greets with
## the figure's own clips, and wears the parts it is given (`gear`, its starting gear: FigureModels.gear_for).

signal turned(dir: String)

const ARCH := Vector2(270, 380)
const TURN_EVERY := 1.1
const WALK_CELL := 384.0

var appearance: Dictionary = {}
var species := "human"
var dir_index := 0
## "turn" (standing, turning), "walk" (the cycle, facing one way) or "attack" (once, then back to standing).
var mode := "turn"
var _frames: Array[Texture2D] = []
var _durations: Array[float] = []
var _frame := 0
var _clock := 0.0
var _turn_clock := 0.0
var _pic: TextureRect
var _note: Label
## The 3D stage: the viewport, the turntable the figure stands on, and the figure (null for the paper doll).
var _view: SubViewportContainer
var _port: SubViewport
var _table: Node3D
var _camera: Camera3D
var _fig: ModelFigure
var _fig_body := ""
var _fig_build := ""
## The art id the preview registers the shown look's figure under (HeroLook.figure_entry).
const PREVIEW_ID := "hero_preview_look"
## Parts the 3D figure wears (its starting gear).
var gear: Array = []
## Radians a second the standing figure turns, and how far a drag of one pixel turns it.
const SPIN := 0.45
const DRAG_TURN := 0.012
## How fast the figure walks and runs, in squares a second (ModelFigure paces its clips to it).
const WALK_PACE := 1.3
const RUN_PACE := 3.6


func _init() -> void:
	custom_minimum_size = ARCH + Vector2(0, 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pic)
	_note = UiKit.label("", 13, "parchment", ARCH.x - 40.0)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.position = Vector2(20, ARCH.y * 0.42)
	_note.size = Vector2(ARCH.x - 40.0, 80)
	add_child(_note)


func show_look(app: Dictionary, species_id: String) -> void:
	appearance = app.duplicate()
	species = species_id
	var body := HeroLook.figure_for(appearance, species)
	if body != "":
		# The look's own figure (its build's breadth on the body), under one id for whichever look is shown.
		FigureModels.register(PREVIEW_ID, HeroLook.figure_entry(appearance, species))
		_show_figure(body)
		return
	_drop_figure()
	_reload()


## Whether the hero is shown as a 3D figure.
func is_figure() -> bool:
	return _fig != null


## The parts the 3D figure wears (its starting gear), put on at once.
func wear(parts: Array) -> void:
	gear = parts.duplicate()
	if _fig != null:
		_fig.wear(gear)
		_ink()


## The figure's line as wide on the turntable as it is in play: the line is set in pixels at 1080 lines of the screen
## it is drawn on, and this stage is only as tall as the arch.
func _ink() -> void:
	var px := float(Look.figure_settings().get("ink", 0.0))
	if px > 0.0 and _view != null:
		_fig.set_ink_width(px * 1080.0 / maxf(_view.size.y, 1.0) * 0.6)


func dir() -> String:
	return DirectionalSprite.DIRECTIONS[dir_index]


func turn(step: int) -> void:
	if _fig != null:
		_table.rotation.y += float(step) * PI / 4.0
		return
	dir_index = posmod(dir_index + step, 8)
	_turn_clock = 0.0
	_reload()
	turned.emit(dir())


func set_mode(m: String) -> void:
	mode = m
	if _fig != null:
		_figure_mode()
		return
	_reload()


# --- The 3D figure -------------------------------------------------------------------------------------------------

## The stage, made the first time a figure is shown: a transparent viewport inside the arch with its own world, a
## camera a little above the figure's middle looking slightly down, a key light from the front left, a cool rim from
## behind and soft ambient light, and a turntable for the figure.
func _stage() -> void:
	if _view != null:
		return
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.position = Vector2(10, 40)
	_view.size = ARCH - Vector2(20, 46)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_drag)
	add_child(_view)
	move_child(_view, 0)
	_port = SubViewport.new()
	_port.transparent_bg = true
	_port.own_world_3d = true
	_port.msaa_3d = Viewport.MSAA_4X
	_port.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_view.add_child(_port)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Look.color("parchment")
	env.ambient_light_energy = 0.22
	_camera = Camera3D.new()
	_camera.environment = env
	_camera.fov = 30.0
	_port.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.25
	key.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-62.0), 0.0)   # from the front left, so half the figure is in shade
	_port.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.6
	rim.light_color = Color(0.62, 0.7, 0.95)
	rim.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(160.0), 0.0)
	_port.add_child(rim)
	_table = Node3D.new()
	_table.name = "Turntable"
	_port.add_child(_table)


## Shows `body` as the hero: a fresh figure when the body changes, the same one resized when only the height does.
func _show_figure(body: String) -> void:
	_stage()
	_pic.visible = false
	_note.text = ""
	var h := HeroLook.height_units(appearance, species)
	var build := str(appearance.get("build", ""))
	if _fig == null or _fig_body != body or _fig_build != build or not is_equal_approx(float(_fig.get_meta("drawn_height", 0.0)), h):
		if _fig != null:
			_fig.queue_free()
		_fig = DirectionalSprite.create(FigureModels.frames(PREVIEW_ID), h) as ModelFigure
		_fig.set_meta("drawn_height", h)
		_fig_body = body
		_fig_build = build
		_table.add_child(_fig)
		_fig.attack_finished.connect(func() -> void: set_mode("turn"))
		_fig.wear(gear)
		_ink()
	# Framed so the tallest figure fills the arch: the camera backs off with the height, a little above its middle.
	var fit := maxf(h, 1.0) * 1.18
	var dist := fit * 0.5 / tan(deg_to_rad(_camera.fov * 0.5))
	var target := Vector3(0.0, h * 0.5, 0.0)
	var eye := target + Vector3(0.0, dist * sin(deg_to_rad(12.0)), dist * cos(deg_to_rad(12.0)))
	_camera.transform = Transform3D(Basis.looking_at(target - eye), eye)   # works before the stage is in the tree
	_figure_mode()


func _drop_figure() -> void:
	if _fig != null:
		_fig.queue_free()
		_fig = null
		_fig_body = ""
		_fig_build = ""
	if _view != null:
		_view.queue_free()
		_view = null
	_pic.visible = true


## The figure does what the mode asks: stands (turning), walks or runs on the spot at a pace its clips match, or
## swings, casts or greets once and then stands again.
func _figure_mode() -> void:
	_fig.moving = mode in ["walk", "run"]
	if _fig.moving:
		_fig.set_step_time(1.0 / (RUN_PACE if mode == "run" else WALK_PACE))
	match mode:
		"attack":
			if not _fig.attack():
				mode = "turn"
		"cast":
			if not _fig.cast() and not _fig.attack():
				mode = "turn"
			else:
				_back_to_standing()
		"greet":
			_fig.gesture("greet")
			_back_to_standing()


## After a cast or a greeting (which say nothing when they end), standing again once the clip has played.
func _back_to_standing() -> void:
	var was := mode
	await get_tree().create_timer(2.2).timeout
	if mode == was and is_instance_valid(_fig):
		set_mode("turn")


func _drag(e: InputEvent) -> void:
	if _table == null:
		return
	if e is InputEventMouseMotion and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_table.rotation.y += (e as InputEventMouseMotion).relative.x * DRAG_TURN
		_turn_clock = -1.5   # a dragged figure stays where it was put for a moment


func _reload() -> void:
	var kind := "walk" if mode == "walk" else ("attack" if mode == "attack" else "idle")
	_frames = HeroLook.preview_frames(appearance, kind, dir())
	_durations.clear()
	if kind == "attack" and not _frames.is_empty():
		_durations = HeroLook.attack_timing(appearance)
	_frame = 0
	_clock = 0.0
	_note.text = "" if not _frames.is_empty() else "This look's art is still being drawn."
	_layout()
	_show_frame()


## The figure fills the arch at the tallest height pick; shorter picks stand lower and smaller, feet on one line.
func _layout() -> void:
	var tallest := 0.0
	for o: Variant in HeroLook.options("heights"):
		tallest = maxf(tallest, float((o as Dictionary)["scale"]))
	var k := float(HeroLook.option("heights", str(appearance.get("height", "average"))).get("scale", 1.0)) / tallest
	var tex := _frames[0] if not _frames.is_empty() else null
	var cell := tex.get_size() if tex != null else Vector2(WALK_CELL, WALK_CELL)
	# render_walk.py frames a figure at 1.12x its height round 0.52 of it, so in a walk cell the feet are 0.964 of
	# the way down and the figure is 0.893 of the cell tall. Attack cells share the walk cell's centre and scale.
	var scale_px := (ARCH.y - 64.0) / (0.893 * WALK_CELL) * k
	var feet := cell.y / 2.0 + 0.464 * WALK_CELL
	_pic.size = cell * scale_px
	_pic.position = Vector2(ARCH.x / 2.0 - cell.x * scale_px / 2.0, ARCH.y - 14.0 - feet * scale_px)


func _show_frame() -> void:
	_pic.texture = _frames[_frame] if _frame < _frames.size() else null


func _process(delta: float) -> void:
	if _fig != null:
		_turn_clock += delta
		if mode == "turn" and _turn_clock > 0.0:
			_table.rotation.y += SPIN * delta
		return
	if _frames.is_empty():
		return
	match mode:
		"turn":
			_turn_clock += delta
			if _turn_clock >= TURN_EVERY:
				turn(1)
		"walk":
			_clock += delta
			if _clock >= 0.1:
				_clock = 0.0
				_frame = (_frame + 1) % _frames.size()
				_show_frame()
		"attack":
			_clock += delta
			var d := _durations[_frame] if _frame < _durations.size() else 0.08
			if _clock >= d:
				_clock = 0.0
				_frame += 1
				if _frame >= _frames.size():
					set_mode("turn")
					return
				_show_frame()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, ARCH)
	var pts := UiParts.arch_points(r, 70.0)
	UiParts.gradient_fill(self, pts, Look.color("ui_wine"), Look.color("ui_black"))
	# A pale pool of light where the figure stands.
	draw_set_transform(Vector2(ARCH.x / 2.0, ARCH.y - 12.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, ARCH.x * 0.32, Color(Look.color("parchment"), 0.09))
	draw_set_transform(Vector2.ZERO)
	UiParts.closed_line(self, pts, Look.color("gilt"), 2.0)
	var inner := UiParts.arch_points(Rect2(Vector2(7, 7), ARCH - Vector2(14, 12)), 64.0)
	UiParts.closed_line(self, inner, Color(Look.color("gilt"), 0.5), 1.0)
	UiParts.crest(self, Vector2(ARCH.x / 2.0, 0.0), 10.0)
	UiParts.brackets(self, Rect2(Vector2(4, 70), ARCH - Vector2(8, 74)), 14.0)
