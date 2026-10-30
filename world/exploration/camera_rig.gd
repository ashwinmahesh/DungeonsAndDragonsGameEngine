class_name CameraRig
extends Node3D
## Fixed-pitch exploration camera (plan §4.1): about 40 degrees down, rotates in 90 degree steps,
## zooms, and follows a target smoothly. Sprites are rendered for these 8 headings.

## Curse of Strahd's pitch, the default. A game sets its own in data/campaign.json ("camera": {"pitch": 30}, degrees
## down; play_pitch), and its sprites are drawn for that angle.
const PITCH_DEG := -40.0
## The pitches a campaign may ask for (degrees down): flatter shows the sky, steeper turns into a map.
const PITCH_RANGE := Vector2(20.0, 60.0)
const ZOOM_MIN := 7.0
const ZOOM_MAX := 22.0
## Past the farthest zoom, the wheel tilts the camera toward the horizon over HORIZON_STEPS more steps (owner pick
## 2026-10-07, Improvement Ideas W13): it comes down to HORIZON_HEIGHT, just over the treetops and roofs, and its
## pitch rises to HORIZON_PITCH_DEG, so it looks out over the party (low in the frame) to the sky and the vistas past
## the map's edge across the top. Play zoom is unchanged, distances a tool sets directly never tilt it, and the
## Classic look (frozen) never tilts.
const HORIZON_STEPS := 4
const HORIZON_PITCH_DEG := -8.0
const HORIZON_HEIGHT := 9.0
const HORIZON_BACK := 25.0
const HORIZON_FAR := 900.0
## The tactical view (owner pick 2026-10-09, after Baldur's Gate 3's): steeper and further back, to plan a fight or a
## sneak from above; camera_tactical (O) switches it, eased in and out over about a third of a second.
const TACTICAL_PITCH_DEG := -66.0
const TACTICAL_ZOOM := 1.45
## How far a full shake (shake = 1) jolts the view, in world units, and how fast it dies away (shake per second).
const SHAKE_MAX := 0.16
const SHAKE_FADE := 3.0

var follow: Node3D
var camera: Camera3D
## This rig's play pitch (degrees, negative: down), the campaign's (play_pitch) unless a tool sets another.
var pitch_deg := PITCH_DEG
## Free turning (a campaign's "camera": {"free_turn": true}): the camera turns to any heading, not in quarter turns.
## Holding the turn keys (Q and E) turns it smoothly, dragging with the middle mouse button turns it with the mouse, and
## the pad's right stick turns it as far as it leans. The 8-direction sprites pick their frame from the real heading
## (DirectionalSprite.direction_for), so they stay right at any angle. Off, the camera turns in quarter turns as before.
var free_turn := false
## Free turning's speeds: degrees a second with a key held or the stick fully over, and degrees per pixel dragged.
const TURN_SPEED := 120.0
const DRAG_TURN := 0.3
var _free_yaw := 0.0
## How far the player may tilt the camera (degrees down, lowest and highest): a campaign's "camera": {"tilt": [22, 38]},
## dragged up and down with the middle mouse button. Kept close to the pitch the sprites are drawn for, past which flat
## figures look squashed or stretched. Zero (the default): no tilt, the pitch stays the campaign's.
var tilt_range := Vector2.ZERO
const DRAG_TILT := 0.15
## The pad's right stick turns the camera (a flick left or right is a quarter turn) and zooms it (up and down) while
## this is on: exploring turns it on (game_root); a fight's radial menu aims with the stick instead (U6).
var pad_look := false
var distance := 13.0
var zoom_min := ZOOM_MIN
var zoom_max := ZOOM_MAX
## How far toward the horizon the wheel has taken the camera (0 in play, 1 fully tilted), and how far it shows now.
var horizon := 0.0
var horizon_shown := 0.0
## A shot over the play view for a fight's big moments (G2 combat impact, G3 a boss's entrance; lane 21), tweened by
## CombatImpact and put back when the moment ends: shot_zoom under 1 pushes in, shot_pitch raises the camera's pitch
## by that many degrees (looking flatter, up at a boss), and the view leans toward shot_focus by shot_weight (0 the
## rig's own point, 1 centred on it). shake jolts the view and dies away by itself.
var shot_zoom := 1.0
var shot_pitch := 0.0
var shot_focus := Vector3.ZERO
var shot_weight := 0.0
var shake := 0.0
## A kick (GameFeel, Visual Polish Plan E39): the picture knocked one way on the screen, on the same offsets as the
## shake, springing back with a little overshoot. impulse() adds to it.
var kick := Vector2.ZERO
var _kick_v := Vector2.ZERO
const KICK_SPRING := 220.0
const KICK_DAMP := 18.0
## The camera's life of its own (a game's "camera" "drift", Visual Polish Plan E50): once the party has stood still a
## few seconds the view breathes, turning and easing in and out a little; any move settles it. `sweep_deg` is a turn
## still to unwind (a fight's opening sweep round the board), eased away by sweep().
var drift := 0.0
var sweep_deg := 0.0
var _still := 0.0
var _drift_t := 0.0
var _last_follow := Vector3.INF
## Whether the tactical view is on, and how far the camera has eased into it.
var tactical := false
var tactical_shown := 0.0
## What walls, houses and trees clear the view to while a shot is on it (a boss's entrance), instead of the party's
## leader; null the rest of the time (LocationView._process).
var cutaway_focus: Node3D = null
var _shake_rng := RandomNumberGenerator.new()
var _far := 120.0
var _yaw_steps := 0
var _yaw := 0.0
var touch_offset := Vector3.ZERO
## Continuous mobile twist; keyboard/controller quarter-turn counts remain independent.
var _touch_yaw := 0.0


func _init() -> void:
	name = "CameraRig"
	pitch_deg = play_pitch()
	free_turn = turns_freely()
	tilt_range = tilt_limits()
	drift = clampf(float(_camera_setting("drift", 0.0)), 0.0, 1.0)
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.3
	camera.far = _far
	add_child(camera)
	_yaw = deg_to_rad(45.0)


## The play camera's pitch for this game (degrees, negative: down): data/campaign.json's "camera" "pitch" (degrees
## down, within PITCH_RANGE), else PITCH_DEG. The combat camera, the talk and impact shots (which lean off it), the
## see-through walls (which follow the camera wherever it is) and the sun's shadow reach (Atmosphere) all go by it.
static func play_pitch() -> float:
	var cam: Variant = Campaign.config().get("camera", {})
	if not cam is Dictionary or not (cam as Dictionary).has("pitch"):
		return PITCH_DEG
	return -clampf(absf(float((cam as Dictionary)["pitch"])), PITCH_RANGE.x, PITCH_RANGE.y)


## Whether this game's camera turns freely: data/campaign.json's "camera" "free_turn" (default false).
static func turns_freely() -> bool:
	var cam: Variant = Campaign.config().get("camera", {})
	return cam is Dictionary and bool((cam as Dictionary).get("free_turn", false))


## The tilt a game allows (data/campaign.json "camera" "tilt": [lowest, highest] degrees down, within PITCH_RANGE), or
## zero for none.
static func tilt_limits() -> Vector2:
	var cam: Variant = Campaign.config().get("camera", {})
	var t: Variant = (cam as Dictionary).get("tilt", []) if cam is Dictionary else []
	if not t is Array or (t as Array).size() != 2:
		return Vector2.ZERO
	var lo := clampf(absf(float((t as Array)[0])), PITCH_RANGE.x, PITCH_RANGE.y)
	var hi := clampf(absf(float((t as Array)[1])), PITCH_RANGE.x, PITCH_RANGE.y)
	return Vector2(minf(lo, hi), maxf(lo, hi))


static func _camera_setting(key: String, default: Variant) -> Variant:
	var cam: Variant = Campaign.config().get("camera", {})
	return (cam as Dictionary).get(key, default) if cam is Dictionary else default


## How far a fight's opening sweep turns the camera round the board (data/campaign.json "camera" "fight_sweep",
## degrees; 0 none).
static func fight_sweep() -> float:
	return float(_camera_setting("fight_sweep", 0.0))


## Whether conversations frame the screen in letterbox bars (data/campaign.json "camera" "letterbox").
static func letterbox() -> bool:
	return bool(_camera_setting("letterbox", false))


## Starts the view `degrees` off its heading and eases it round onto it over `seconds` (a fight's opening sweep).
func sweep(degrees: float, seconds := 1.6) -> void:
	if is_zero_approx(degrees) or MobileNative.reduced_motion():
		return
	sweep_deg = degrees
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "sweep_deg", 0.0, seconds)


## Tilts the camera `degrees` further down (negative: flatter), within tilt_range; nothing without one.
func tilt_by(degrees: float) -> void:
	if tilt_range == Vector2.ZERO:
		return
	pitch_deg = -clampf(-pitch_deg + degrees, tilt_range.x, tilt_range.y)


## Turns the camera by `degrees` (positive: as rotate_step(1) does), at once, in free turning.
func turn_by(degrees: float) -> void:
	_free_yaw = wrapf(_free_yaw + deg_to_rad(degrees), -PI, PI)


## The heading the camera eases to: the start's 45 degrees, its quarter turns, and any free or touch turning.
func _goal_yaw() -> float:
	return deg_to_rad(45.0) + _yaw_steps * PI / 2.0 + _touch_yaw + _free_yaw


func rotate_step(dir: int) -> void:
	_yaw_steps += dir


## Unit vectors on the ground plane for "screen up" and "screen right", for camera-relative movement.
func ground_basis() -> Array[Vector3]:
	var fwd := -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := global_transform.basis.x
	right.y = 0
	return [fwd, right.normalized()]


func snap_to_target() -> void:
	if follow:
		global_position = follow.global_position
	_yaw = _goal_yaw()
	horizon_shown = horizon
	_apply()


func touch_camera(update: Dictionary) -> void:
	if str(update.get("kind", "")) == "camera":
		distance = clampf(distance / maxf(float(update.get("scale", 1.0)), 0.1), zoom_min, zoom_max)
		# Screen-space positive angles are clockwise; positive camera yaw makes the ground follow the fingers.
		_touch_yaw = wrapf(_touch_yaw + float(update.get("rotation", 0.0)), -PI, PI)
	var delta := update.get("delta", Vector2.ZERO) as Vector2
	var axes := ground_basis()
	var units := distance / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	touch_offset += (-axes[1] * delta.x + axes[0] * delta.y) * units
	touch_offset = touch_offset.limit_length(24.0)
	horizon = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.has_meta(&"touch_gui"):
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if horizon > 0.0:
				horizon = maxf(horizon - 1.0 / HORIZON_STEPS, 0.0)
			else:
				distance = clampf(distance - 1.0, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if distance >= zoom_max - 0.01 and Look.modern():
				horizon = minf(horizon + 1.0 / HORIZON_STEPS, 1.0)
			else:
				distance = clampf(distance + 1.0, zoom_min, zoom_max)
	if (free_turn or tilt_range != Vector2.ZERO) and event is InputEventMouseMotion \
			and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		var drag := (event as InputEventMouseMotion).relative
		if free_turn:
			turn_by(drag.x * DRAG_TURN)
		tilt_by(drag.y * DRAG_TILT)
		return
	if pad_look and event is InputEventJoypadButton:
		return   # exploring, the stick clicks sneak and switch turn-based; the right stick turns the camera
	if event.is_action_pressed(&"camera_tactical"):
		tactical = not tactical
	elif free_turn and (event.is_action(&"camera_rotate_left") or event.is_action(&"camera_rotate_right")):
		return   # (held, they turn it smoothly: _process)
	elif event.is_action_pressed(&"camera_rotate_left"):
		rotate_step(-1)
	elif event.is_action_pressed(&"camera_rotate_right"):
		rotate_step(1)


## How far the right stick must lean to turn the camera, and come back before it turns it again; zoom per second.
const LOOK_FLICK := 0.7
const LOOK_REST := 0.3
const LOOK_ZOOM := 14.0
var _flicked := false


func _process(delta: float) -> void:
	if pad_look:
		_look(delta)
	if free_turn and is_inside_tree() and InputMap.has_action(&"camera_rotate_left") and InputMap.has_action(&"camera_rotate_right"):
		var held := Input.get_axis(&"camera_rotate_left", &"camera_rotate_right")
		if held != 0.0:
			turn_by(held * TURN_SPEED * delta)
	if follow:
		global_position = global_position.lerp(follow.global_position + touch_offset, clampf(delta * 6.0, 0.0, 1.0))
	var goal := _goal_yaw()
	_yaw = lerp_angle(_yaw, goal, clampf(delta * 9.0, 0.0, 1.0))
	horizon_shown = move_toward(horizon_shown, horizon, delta * 1.6)
	_breathe(delta)
	tactical_shown = move_toward(tactical_shown, 1.0 if tactical else 0.0, delta * 3.0)
	_shake(delta)
	_apply()


## The idle drift: the party still for a few seconds lets the view breathe; it settles as soon as anyone moves.
func _breathe(delta: float) -> void:
	if drift <= 0.0:
		return
	var at := follow.global_position if follow != null else global_position
	var moved := _last_follow != Vector3.INF and at.distance_to(_last_follow) > delta * 0.05
	_last_follow = at
	_still = 0.0 if moved else _still + delta
	_drift_t += delta


## How much of the drift shows now (0 moving, 1 after standing still a while).
func drift_shown() -> float:
	return drift * smoothstep(2.5, 6.0, _still) if not MobileNative.reduced_motion() else 0.0


## The right stick (pad_look): a flick turns a quarter, up and down zoom within the play range.
func _look(delta: float) -> void:
	if not InputMap.has_action(&"look_left"):
		return
	var v := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if free_turn:
		if absf(v.x) > 0.2 and absf(v.x) >= absf(v.y) * 0.5:
			turn_by(v.x * TURN_SPEED * delta)
	elif absf(v.x) >= LOOK_FLICK and not _flicked and absf(v.x) > absf(v.y):
		_flicked = true
		rotate_step(1 if v.x > 0.0 else -1)
	elif absf(v.x) < LOOK_REST:
		_flicked = false
	if absf(v.y) > 0.25 and horizon <= 0.0:
		distance = clampf(distance + v.y * LOOK_ZOOM * delta, zoom_min, zoom_max)


## The shake's jolt for this frame, on the camera's own offsets so the rig's point and the shot stay put.
func _shake(delta: float) -> void:
	if MobileNative.reduced_motion():
		shake = 0.0
		kick = Vector2.ZERO
		_kick_v = Vector2.ZERO
	var kicked := _kick(delta)
	if shake <= 0.0:
		if camera.h_offset != kicked.x or camera.v_offset != kicked.y:
			camera.h_offset = kicked.x
			camera.v_offset = kicked.y
		return
	shake = maxf(shake - delta * SHAKE_FADE, 0.0)
	var reach := shake * shake * SHAKE_MAX
	camera.h_offset = _shake_rng.randf_range(-reach, reach) + kicked.x
	camera.v_offset = _shake_rng.randf_range(-reach, reach) + kicked.y


## Knocks the picture `amount` world units toward `picture_dir` on the screen (x right, y up); it springs back.
func impulse(picture_dir: Vector2, amount: float) -> void:
	if MobileNative.reduced_motion() or picture_dir == Vector2.ZERO:
		return
	kick -= picture_dir.normalized() * amount


## The kick's spring this frame: the camera's offset from it.
func _kick(delta: float) -> Vector2:
	if kick == Vector2.ZERO and _kick_v == Vector2.ZERO:
		return Vector2.ZERO
	var dt := clampf(delta, 0.0, 0.05)
	_kick_v += (-KICK_SPRING * kick - KICK_DAMP * _kick_v) * dt
	kick += _kick_v * dt
	if kick.length() < 0.0005 and _kick_v.length() < 0.01:
		kick = Vector2.ZERO
		_kick_v = Vector2.ZERO
	return kick


func _apply() -> void:
	var breathe := drift_shown()
	rotation = Vector3(0, _yaw + deg_to_rad(sweep_deg + sin(_drift_t * 0.11) * 2.5 * breathe), 0)
	var k := smoothstep(0.0, 1.0, horizon_shown)
	var kt := smoothstep(0.0, 1.0, tactical_shown)
	var reduce := MobileNative.reduced_motion()
	var pitch := lerpf(pitch_deg, TACTICAL_PITCH_DEG, kt) + (0.0 if reduce else shot_pitch)
	var play := deg_to_rad(pitch)
	var d := distance * (1.0 if reduce else shot_zoom) * lerpf(1.0, TACTICAL_ZOOM, kt) \
		* (1.0 + sin(_drift_t * 0.07 + 1.3) * 0.035 * breathe)
	var at := Vector3(0, -sin(play) * d, cos(play) * d) + Vector3(0, 0.6, 0)
	if shot_weight > 0.0 and not reduce:
		at += Basis(Vector3.UP, -_yaw) * ((shot_focus - global_position) * shot_weight)
	camera.position = at.lerp(Vector3(0, HORIZON_HEIGHT, HORIZON_BACK), k)
	camera.rotation = Vector3(deg_to_rad(lerpf(pitch, HORIZON_PITCH_DEG, k)), 0, 0)
	var far := lerpf(_far, HORIZON_FAR, k)
	if not is_equal_approx(camera.far, far):
		camera.far = far
