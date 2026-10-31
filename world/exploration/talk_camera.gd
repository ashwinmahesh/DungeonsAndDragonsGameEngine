class_name TalkCamera
extends RefCounted
## The camera in a conversation (Visual Polish Plan 7, after Octopath Traveler 2's scenes): as a conversation opens
## while exploring, the play camera eases in a step, a little lower, and leans to frame the party's leader and whoever
## they're talking to above the conversation box; when it ends it eases back to the play view. GameRoot.start_dialogue and _dialogue_ended call
## it. It moves only the CameraRig's shot (shot_zoom, shot_pitch, shot_focus, shot_weight, as CombatImpact does in a
## fight), never the rig itself, and never during a fight. Like the rest of the interface's motion it's off in
## headless runs and still captures (UiMotion).
##
## Close-ups (a game's data/campaign.json "camera" "talk_close_ups"): as each line is said, the camera comes in on the
## speaker's head and shoulders, flatter, and the speaker turns to face it, as conversations look in Baldur's Gate 3;
## whoever speaks next takes the shot, a line nobody on the map says goes back to the pair, and close() eases back to
## the play view. A 3D figure wears its close-up look meanwhile (ModelFigure.set_close_up).

## How close (shot_zoom), how much lower (degrees off the play pitch: flatter, more of the faces), how far the view
## leans toward the pair (shot_weight), and the seconds it takes to come in and to go back.
const ZOOM := 0.8
const PITCH := 5.0
const LEAN := 0.7
## How far the camera also comes forward (world units, toward the player): the conversation box covers the lower part
## of the screen, so the pair is framed above it rather than behind it.
const RAISE := 1.6
const IN := 0.8
const OUT := 0.7
## The tween on a rig, kept so the way back cuts the way in short, and the mark that it moved the shot.
const TWEEN := &"talk_camera"
const OPEN := &"talk_camera_open"
## A close-up: how far from the speaker's face the camera stands (world units), how much flatter it looks (degrees off
## the play pitch), where on the speaker it aims (a share of their height: a little under the eyes, so the face sits
## above the conversation box), and the seconds it takes to come in. The pair's shot is kept to go back to.
const CLOSE_DISTANCE := 1.35
const CLOSE_PITCH := 20.0
const CLOSE_AIM := 0.8
const CLOSE_IN := 0.45
const PAIR := &"talk_camera_pair"
const SPEAKER := &"talk_camera_speaker"

## Tests ask for it in headless runs.
static var headless_too := false


static func on() -> bool:
	return UiMotion.on() or headless_too


## The conversation with `npc_id` opened in `view`: the camera eases in toward the leader and the speaker (the leader
## alone when the speaker isn't on the map; or the prop that speaks, a vestige's block of amber).
static func open(view: LocationView, npc_id: String, prop_id: String = "") -> void:
	if not on() or view == null or view.rig == null or view.in_combat or not view.is_inside_tree():
		return
	var rig := view.rig
	var focus := rig.global_position
	var tok: Variant = view.npc_tokens.get(npc_id, view._staged.get(npc_id))   # a person of the place, or one a scene brought on
	if is_instance_valid(tok) and (tok as Node3D).is_inside_tree():
		focus = (focus + (tok as Node3D).global_position) / 2.0
	elif prop_id != "" and view.prop_cell(prop_id) != null:
		focus = (focus + view.board.cell_center(view.prop_cell(prop_id) as Vector2i)) / 2.0   # a vestige's block speaks
	# The rig leans toward shot_focus by shot_weight: a point toward the player, so the pair sits above the box.
	focus += rig.global_basis * Vector3(0.0, 0.0, RAISE / LEAN)
	var tw := _tween(rig)
	rig.set_meta(OPEN, true)
	rig.set_meta(PAIR, [focus, ZOOM, PITCH, LEAN])
	if rig.shot_weight < 0.01:
		rig.shot_focus = focus
	else:
		tw.tween_property(rig, "shot_focus", focus, IN)
	tw.tween_property(rig, "shot_zoom", ZOOM, IN)
	tw.tween_property(rig, "shot_pitch", PITCH, IN)
	tw.tween_property(rig, "shot_weight", LEAN, IN)
	_bars(view, true)


## A line said by `speaker_id` is showing: the camera comes in close on them and they turn to face it (a game with
## CameraRig.talk_close_ups). A line by someone not on the map (the Narrator, a voice off) goes back to the pair.
static func speaker(view: LocationView, speaker_id: String) -> void:
	if not on() or not CameraRig.talk_close_ups() or view == null or view.rig == null or view.in_combat:
		return
	var rig := view.rig
	if not rig.has_meta(OPEN):
		return
	var tok := FigureTalk.token_of(view, speaker_id)
	_close_up_off(rig)
	if tok == null or not tok.is_inside_tree() or not (tok.sprite is DirectionalSprite):
		var pair := rig.get_meta(PAIR, []) as Array
		if pair.size() == 4:
			_ease(rig, pair[0] as Vector3, float(pair[1]), float(pair[2]), float(pair[3]), CLOSE_IN)
		return
	var fig := tok.sprite as DirectionalSprite
	var aim := tok.global_position + Vector3.UP * fig._height * CLOSE_AIM
	# The rig looks at its own point 0.6 up, leaned all the way to the focus: the focus is the aim less that rise.
	_ease(rig, aim - Vector3(0.0, 0.6, 0.0), CLOSE_DISTANCE / maxf(rig.distance, 0.1), CLOSE_PITCH, 1.0, CLOSE_IN)
	var cam := rig.camera.global_position
	tok.face(Vector2(cam.x - tok.global_position.x, cam.z - tok.global_position.z), false)
	if fig is ModelFigure:
		(fig as ModelFigure).set_close_up(true)
	rig.set_meta(SPEAKER, tok)


static func _ease(rig: CameraRig, focus: Vector3, zoom: float, pitch: float, weight: float, seconds: float) -> void:
	var tw := _tween(rig)
	tw.tween_property(rig, "shot_focus", focus, seconds)
	tw.tween_property(rig, "shot_zoom", zoom, seconds)
	tw.tween_property(rig, "shot_pitch", pitch, seconds)
	tw.tween_property(rig, "shot_weight", weight, seconds)


## The last speaker's close-up look comes off.
static func _close_up_off(rig: CameraRig) -> void:
	var last: Variant = rig.get_meta(SPEAKER) if rig.has_meta(SPEAKER) else null
	if is_instance_valid(last) and (last as CombatToken).sprite is ModelFigure:
		((last as CombatToken).sprite as ModelFigure).set_close_up(false)
	if rig.has_meta(SPEAKER):
		rig.remove_meta(SPEAKER)


## The conversation ended: the camera eases back to the play view, or is back at once (`at_once`) when a fight
## starts from it, so the fight's own camera has the shot to itself.
static func close(view: LocationView, at_once: bool = false) -> void:
	if view == null or view.rig == null or not view.is_inside_tree():
		return
	_bars(view, false, at_once)
	var rig := view.rig
	_close_up_off(rig)
	if not rig.has_meta(OPEN):
		return   # it never moved for this conversation (a fight's, say): the shot isn't its to put back
	rig.remove_meta(OPEN)
	if rig.has_meta(PAIR):
		rig.remove_meta(PAIR)
	var tw := _tween(rig)
	if at_once or view.in_combat:
		tw.kill()
		rig.shot_zoom = 1.0
		rig.shot_pitch = 0.0
		rig.shot_weight = 0.0
		return
	tw.tween_property(rig, "shot_zoom", 1.0, OUT)
	tw.tween_property(rig, "shot_pitch", 0.0, OUT)
	tw.tween_property(rig, "shot_weight", 0.0, OUT)


## Letterbox bars over the top and bottom of the screen while a conversation is on, for a game that asks
## (CameraRig.letterbox): they slide in with the camera and out with it, under the conversation box.
const BAR := 0.09
const BARS := &"LetterboxBars"


static func _bars(view: LocationView, show: bool, at_once := false) -> void:
	if not CameraRig.letterbox():
		return
	var layer := view.get_node_or_null(NodePath(BARS)) as CanvasLayer
	if layer == null:
		if not show:
			return
		layer = CanvasLayer.new()
		layer.name = BARS
		layer.layer = 1
		for top: bool in [true, false]:
			var r := ColorRect.new()
			r.name = "Top" if top else "Bottom"
			r.color = Look.color("ui_black")
			r.anchor_right = 1.0
			r.anchor_top = 0.0 if top else 1.0
			r.anchor_bottom = 0.0 if top else 1.0
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(r)
		view.add_child(layer)
	var h := view.get_viewport().get_visible_rect().size.y * BAR if show else 0.0
	for r: ColorRect in [layer.get_node(^"Top") as ColorRect, layer.get_node(^"Bottom") as ColorRect]:
		var top := r.name == "Top"
		var prop := "offset_bottom" if top else "offset_top"
		var goal := h if top else -h
		if at_once or not on():
			r.set(prop, goal)
			continue
		UiMotion.tween_for(r).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE) \
			.tween_property(r, prop, goal, IN if show else OUT)


## A new tween for the rig's shot, replacing the one still running; it runs while the game is paused (a conversation
## may pause it) and eases in and out.
static func _tween(rig: CameraRig) -> Tween:
	var old: Variant = rig.get_meta(TWEEN) if rig.has_meta(TWEEN) else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := UiMotion.tween_for(rig).set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	rig.set_meta(TWEEN, tw)
	return tw
