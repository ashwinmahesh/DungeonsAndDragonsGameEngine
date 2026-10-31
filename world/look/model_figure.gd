class_name ModelFigure
extends DirectionalSprite
## A character or creature drawn as a rigged 3D model (FigureModels, docs/reference/art/figures.md) in place of its
## 8-direction sprite. To everything that shows a figure (CombatToken, FieldView, the gray-box room) it is a
## DirectionalSprite: the same facing, moving, pose, walk pacing, attack, cast, hurt and die, and the same struck,
## attack_finished and footfall signals, so the engine draws a model wherever it would draw a sprite. Its own sprite
## draws nothing (FigureModels.frames' blank stand-ins, on no render layer); the model is its child:
##   ModelFigure > Turn (faces `facing`, turning to it) > Posture (standing, recoiling, lying down) > the model.
## Clips play by role (FigureModels.CLIPS): idle and walk (or run) loop, the walk paced to the ground it covers; attack,
## cast, hurt, talk and greet play once and blend back to the loop. A clip that walks the model forward (Tripo's walk
## and greet) is held in place: its root bone's drift is taken out once, the first time the model is used, and the
## distance it covered paces the walk; a looping one (a run) is also centred over the model's feet, and a die clip's
## root is held over its square so the figure lies where it stood. Without a die clip the figure tips over backward and
## lies on its back; without a hurt clip it recoils; without an idle it stands still and breathes, unless its manifest says
## `idle_from_walk`, then it stirs on its walk.
## Surfaces: lit_figure.gdshader with figure_ink.gdshader as their ink (Look.figure_settings),
## drawn after the screen pass as the 2D figures are, so the place's mist, grade and depth blur leave it clear. An entry
## can paint the model with a texture of its own (`albedo`, a dressing of a shared body), draw it with a game's shader
## (`shader`), grow or shrink bones on top of every clip (`bones`, FigureBones) and show it as a ghost (`ghost`).
## Layers (FigureModels parts): the entry's `layers` and what `wear` puts on, rigid pieces held on bones and skinned
## layers bound to the model's own skeleton, so a figure's gear and clothes move with every clip.

const SHADER := preload("res://addons/dnd_core/shaders/world/lit_figure.gdshader")
const INK := preload("res://addons/dnd_core/shaders/world/figure_ink.gdshader")
const DEPTH := preload("res://addons/dnd_core/shaders/world/figure_depth.gdshader")
## Seconds to blend from one clip into the next.
const BLEND := 0.22
## How fast a figure turns to a new facing, radians a second.
const TURN_RATE := 11.0
## The fall without a die clip, and getting up again, in seconds.
const FALL_SECONDS := 0.5
const RISE_SECONDS := 0.45
## Getting up after a die clip: the fall plays backwards over this long, then blends into the idle.
const RISE_CLIP_SECONDS := 0.85
## A walk plays at the rate that matches its stride to the ground covered, within these: legs a little faster or
## slower than the ground look fine, past them they skate. Over RUN_FROM the run clip plays instead, if there is one:
## a figure walks for as long as its walk keeps up with the ground, and runs only past that (never when sneaking).
const MIN_WALK_RATE := 0.6
const MAX_WALK_RATE := 2.2
const RUN_FROM := MAX_WALK_RATE
## A walk clip that doesn't move the model (made in place) is taken to cover this many of the figure's heights a second.
const IN_PLACE_PACE := 0.62
## The speed of a walk-only model's idle when its manifest says `idle_from_walk`: its walk, slowed to a stir.
const IDLE_STIR := 0.3
## Roles whose clips are all used, in turn, rather than the first found.
const VARIED: Array[String] = ["talk", "greet"]

var art_id := ""
var model: Node3D
var _turn: Node3D
var _posture: Node3D
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _meshes: Array[GeometryInstance3D] = []
## The model's own meshes (a layer can hide them), and its height at rest in the model's units.
var _own_meshes: Array[MeshInstance3D] = []
var _rest_height := 1.0
## Part id -> what it put on the figure: {"nodes": [the attachment or the bound meshes], "meshes": [...], "hides": [...]}.
var _layers: Dictionary = {}
## The parts `wear` asked for (the entry's own `layers` are always on).
var _worn: Array[String] = []
## The per-instance shader values set so far (tint, flash, glow, ghost), for meshes put on later.
var _params: Dictionary = {}
## Upright pieces (a part's `upright`): their holder -> the bone they follow, moved there each time the pose is set.
var _upright: Dictionary = {}
## Drawn as a soft ghost: its surfaces blended, after a depth pass of their own (set_ghost_look with see_through).
var _soft := false
var _info: Dictionary = {}
## role -> the clips that play it: [{"name", "from", "to", "hit", "speed"}]
var _roles: Dictionary = {}
var _turns: Dictionary = {}   ## role -> the next of its clips to play
var _scale := 1.0
var _yaw := 0.0
var _faced := false
## The loop playing ("idle", "walk", "run") and its rate; the one-shot playing (a clip spec with its "role"), or {}.
var _loop := ""
var _rate := 1.0
var _clip: Dictionary = {}
## Lying down: 0 standing, 1 on its back. A die clip leaves the figure lying in its last frame instead (_fell_by_clip).
var _lie := 0.0
var _lie_to := 0.0
var _fell_by_clip := false
var _shown_modulate := Color(-1, -1, -1, -1)
var _walk_at := -1.0
var _tilt := 0.0
var _tilt_v := 0.0
## Getting up by playing the die clip backwards: the clip's start it rises to, or -1 when not rising.
var _rise_to := -1.0
static var _materials: Dictionary = {}


## A figure for the stand-in frames of a model (FigureModels.frames), `height_units` tall (DirectionalSprite.create).
static func create_for(frames: SpriteFrames, height_units: float) -> ModelFigure:
	var f := ModelFigure.new()
	f.sprite_frames = frames
	f.layers = 0
	f.art_id = str(frames.get_meta(FigureModels.META, ""))
	f._height = height_units
	f._breath_phase = DirectionalSprite._rng.randf() * TAU
	f._build()
	return f


func _build() -> void:
	_info = FigureModels.info(art_id)
	_turn = Node3D.new()
	_turn.name = "Turn"
	add_child(_turn)
	_posture = Node3D.new()
	_posture.name = "Posture"
	_turn.add_child(_posture)
	var packed := FigureModels.scene(art_id)
	if packed == null:
		return
	model = packed.instantiate() as Node3D
	model.name = "Model"
	_posture.add_child(model)
	var box := rest_box(model)
	_rest_height = maxf(box.size.y, 0.001)
	_scale = _height / _rest_height * float(_info.get("scale", 1.0))
	model.scale = Vector3.ONE * _scale
	model.rotation.y = deg_to_rad(float(_info.get("turn", 0.0)))
	model.position.y = -box.position.y * _scale + float(_info.get("lift", 0.0))
	for n in model.find_children("*", "AnimationPlayer", true, false):
		_player = n as AnimationPlayer
		break
	for n in model.find_children("*", "Skeleton3D", true, false):
		_skeleton = n as Skeleton3D
		break
	var ghostly := _info.get("ghost", {}) as Dictionary
	_soft = float(ghostly.get("see_through", 0.0)) > 0.0
	_dress()
	_fit_layers()
	_bones()
	_read_clips()
	if not ghostly.is_empty():
		set_ghost_look(ghostly)
	_play_loop("idle", 1.0)
	if _player != null and _player.current_animation != "":
		# A crowd doesn't breathe in step: each figure starts its idle somewhere of its own.
		_player.seek(DirectionalSprite._rng.randf() * _player.current_animation_length, true)


## The bounds of a model's meshes at rest, in the model's own space (its feet, its top, its width).
static func rest_box(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		while p != root and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b := xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# --- Surfaces --------------------------------------------------------------------------------------------------------

## Every surface in the figure's material: its own texture (or colour), lit and inked as figures are in this finish.
## Materials are shared by every copy of a model; what's a figure's own (its fade, flash, glow) is per instance.
func _dress() -> void:
	var paint := FigureModels.albedo_of(art_id)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		_dress_mesh(mi, paint)
		_own_meshes.append(mi)


## One mesh, the model's own or a layer's, in the figure material, with the figure's state so far. `paint` is the
## entry's own texture for the model's surfaces (a layer keeps its own).
func _dress_mesh(mi: MeshInstance3D, paint: Texture2D = null) -> void:
	var shadows := Look.modern() and Graphics.sprite_shadows()
	var own_shader := _own_shader()
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, surface_material(mi.get_active_material(i), paint, own_shader, _soft))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for param: StringName in _params:
		mi.set_instance_shader_parameter(param, _params[param])
	_meshes.append(mi)


## The game's own shader the entry names (`shader`), or null for the engine's.
func _own_shader() -> Shader:
	var rel := str(_info.get("shader", ""))
	if rel == "":
		return null
	if not ArtPaths.exists(rel):
		push_warning("figure %s: no shader %s, drawn with the engine's" % [art_id, rel])
		return null
	return load(ArtPaths.of(rel)) as Shader


## The figure material standing in for a model's own `src` (its albedo texture and colour), made once per look.
## `paint` replaces a textured surface's texture (a dressing of a shared body); `own_shader` replaces lit_figure.
## `soft`: a ghost seen through, blended rather than dithered: a depth pass (figure_depth) at RENDER_PRIORITY first, then
## its surfaces and ink one priority later, so they show only the nearest surface.
static func surface_material(src: Material, paint: Texture2D = null, own_shader: Shader = null, soft := false) -> ShaderMaterial:
	var tex: Texture2D = null
	var colour := Color.WHITE
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
		colour = (src as BaseMaterial3D).albedo_color
	if paint != null and tex != null:
		tex = paint
	var key := "%s|%s|%s|%s|%s" % [str(tex.get_rid().get_id()) if tex != null else "-", colour.to_html(), Look.style(),
		own_shader.resource_path if own_shader != null else "", "soft" if soft else ""]
	if _materials.has(key):
		return _materials[key] as ShaderMaterial
	var s := Look.figure_settings()
	var m := ShaderMaterial.new()
	m.shader = own_shader if own_shader != null else SHADER
	m.render_priority = RENDER_PRIORITY   # after the screen pass, as the 2D figures
	m.set_shader_parameter("use_texture", tex != null)
	if tex != null:
		m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("albedo", Color(colour.r, colour.g, colour.b))
	m.set_shader_parameter("light_floor", float(s["floor"]))
	m.set_shader_parameter("light_cap", float(s["light_cap"]))
	m.set_shader_parameter("rim_strength", float(s["rim"]))
	m.set_shader_parameter("bands", int(s["bands"]))
	m.set_shader_parameter("band_light", Vector4(float(s["band_lit"]), float(s["band_dark"]), float(s["band_mid"]),
		float(s["band_edge"])))
	m.set_shader_parameter("flatten", float(s["flatten"]))
	m.set_shader_parameter("flatten_mip", float(s["flatten_mip"]))
	m.set_shader_parameter("vivid", float(s["vivid"]))
	m.set_shader_parameter("ghost_tint", Look.color("silver"))
	if float(s["ink"]) > 0.0:
		var ink := ShaderMaterial.new()
		ink.shader = INK
		ink.render_priority = RENDER_PRIORITY
		ink.set_shader_parameter("ink", Look.color(str(s["ink_colour"])))
		ink.set_shader_parameter("width", float(s["ink"]))
		m.next_pass = ink
	if soft:
		for each: ShaderMaterial in [m, m.next_pass as ShaderMaterial]:
			if each != null:
				each.set_shader_parameter("soft_through", true)
				each.render_priority = RENDER_PRIORITY + 1
		var depth := ShaderMaterial.new()
		depth.shader = DEPTH
		depth.render_priority = RENDER_PRIORITY
		depth.next_pass = m
		m = depth
	_materials[key] = m
	return m


## How much of its colours the figure shows whatever the lights (DirectionalSprite.glow).
func set_glow(amount: float) -> void:
	_each_mesh("glow", amount)


## Washed toward a translucent grey (an Echo Knight's echo), 0 to 1.
func set_ghost(amount: float) -> void:
	_each_mesh("ghost", amount)


## The ink line drawn `px` pixels wide (at 1080 lines) on this figure alone: a close view (the creator's turntable)
## wants a wider line than the play camera's. Its surfaces' materials are copied, so other figures keep theirs; parts
## worn after this keep the usual line.
func set_ink_width(px: float) -> void:
	for gi in _meshes:
		var mi := gi as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m == null or not (m.next_pass is ShaderMaterial) or (m.next_pass as ShaderMaterial).shader != INK:
				continue
			var own := m.duplicate() as ShaderMaterial
			var ink := (m.next_pass as ShaderMaterial).duplicate() as ShaderMaterial
			ink.set_shader_parameter("width", px)
			own.next_pass = ink
			mi.set_surface_override_material(i, own)


## A ghost's look, as a manifest entry's "ghost" gives it (each 0 to 1, any left out is none): `wash` toward its colour
## (set_ghost), `colour` (a palette name; the material's grey without one), `glow` its own light (set_glow),
## `see_through` the share of it the world shows through, `rim` a glow along its edges, `pulse` how far its glow
## throbs. A ghost seen through is blended softly (surface_material's `soft`), its line fading less than its body.
func set_ghost_look(look: Dictionary) -> void:
	var soft := float(look.get("see_through", 0.0)) > 0.0
	if soft != _soft and model != null:
		_soft = soft
		_meshes.clear()
		_own_meshes.clear()
		_dress()   # seen through or not changes the surfaces' materials (surface_material's `soft`)
		for id: Variant in _layers:
			for mi: Variant in ((_layers[id] as Dictionary)["meshes"] as Array):
				_dress_mesh(mi as MeshInstance3D)
	set_ghost(float(look.get("wash", 0.0)))
	set_glow(float(look.get("glow", 0.0)))
	var colour := str(look.get("colour", ""))
	var c := Look.color(colour) if colour != "" else Color(0, 0, 0, 0)
	_each_mesh("ghost_colour", Vector4(c.r, c.g, c.b, c.a if colour != "" else 0.0))
	_each_mesh("see_through", clampf(float(look.get("see_through", 0.0)), 0.0, 0.95))
	_each_mesh("ghost_rim", float(look.get("rim", 0.0)))
	_each_mesh("pulse", float(look.get("pulse", 0.0)))


func _each_mesh(param: StringName, value: Variant) -> void:
	_params[param] = value
	for gi in _meshes:
		gi.set_instance_shader_parameter(param, value)


# --- Layers -----------------------------------------------------------------------------------------------------------

## Wears `parts` (FigureModels part ids: the hero's gear, FigureModels.gear_for) over the layers its entry always has.
## A part id ending "@off" is the part in the other hand, mirrored (FigureModels.mirrored). Parts no longer asked for
## come off, new ones go on, the rest stay as they are; a part with no model, or whose bone the skeleton lacks, is
## left off.
func wear(parts: Array) -> void:
	_worn.clear()
	for p: Variant in parts:
		_worn.append(str(p))
	_fit_layers()


## The parts on the figure now, in the order they went on.
func worn_parts() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _layers:
		out.append(str(id))
	return out


func _fit_layers() -> void:
	if model == null or _skeleton == null:
		return
	var wanted: Array[String] = []
	for p: Variant in (_info.get("layers", []) as Array):
		wanted.append(str(p))
	for p in _worn:
		if not p in wanted:
			wanted.append(p)
	for id: Variant in _layers.keys():
		if not str(id) in wanted:
			_take_off(str(id))
	for id in wanted:
		if not _layers.has(id):
			_put_on(id)
	var hidden := {}
	for id: Variant in _layers:
		for h: Variant in ((_layers[id] as Dictionary)["hides"] as Array):
			hidden[str(h)] = true
	for mi in _own_meshes:
		mi.visible = not (hidden.has("*") or hidden.has(str(mi.name)))


## Puts part `id` on: a rigid piece on its bone, or a skinned layer's meshes onto the figure's skeleton.
func _put_on(id: String) -> void:
	var entry := FigureModels.part(id.trim_suffix(FigureModels.OFF_HAND))
	if id.ends_with(FigureModels.OFF_HAND):
		entry = FigureModels.mirrored(entry)
	var packed := FigureModels.part_scene(id.trim_suffix(FigureModels.OFF_HAND))
	if packed == null:
		return
	var piece := packed.instantiate() as Node3D
	if piece == null:
		return
	var nodes: Array[Node3D] = []
	var bone_name := str(entry.get("bone", ""))
	if bone_name != "":
		var b := FigureModels.bone(_skeleton, bone_name)
		if b < 0:
			piece.free()
			return
		var hold: Node3D
		if bool(entry.get("upright", false)):
			# Upright: where the hand is, but standing the way the figure stands, as a lantern hangs or a torch is held
			# up whatever the hand's roll, which differs from rig to rig and clip to clip.
			hold = Node3D.new()
			_upright[hold] = b
			if not _skeleton.skeleton_updated.is_connected(_follow_bones):
				_skeleton.skeleton_updated.connect(_follow_bones)
		else:
			hold = BoneAttachment3D.new()
		hold.name = "Holds_" + id.validate_node_name()
		_skeleton.add_child(hold)
		if hold is BoneAttachment3D:
			(hold as BoneAttachment3D).bone_name = _skeleton.get_bone_name(b)
		else:
			hold.position = _skeleton.get_bone_global_pose(b).origin
		hold.add_child(piece)
		piece.transform = _hold_at(piece, entry, _skeleton.get_bone_name(b), hold is BoneAttachment3D)
		nodes.append(hold)
	else:
		for n in piece.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or mi.skin == null:
				continue
			var own := mi.get_node_or_null(mi.skeleton) as Skeleton3D
			var keep := mi.transform
			mi.owner = null
			mi.get_parent().remove_child(mi)
			mi.name = "Wears_%s_%d" % [id.validate_node_name(), nodes.size()]
			_skeleton.add_child(mi)
			mi.transform = keep
			mi.skeleton = NodePath("..")
			mi.skin = _bound_skin(mi.skin, own)
			nodes.append(mi)
		piece.free()
	var meshes: Array[MeshInstance3D] = []
	for node in nodes:
		var found: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
		found.push_front(node)
		for n in found:
			if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				_dress_mesh(n as MeshInstance3D)
				meshes.append(n as MeshInstance3D)
	_layers[id] = {"nodes": nodes, "meshes": meshes, "hides": entry.get("hides", []) as Array}


func _take_off(id: String) -> void:
	var rec := _layers[id] as Dictionary
	for mi: Variant in (rec["meshes"] as Array):
		_meshes.erase(mi)
	for node: Variant in (rec["nodes"] as Array):
		_upright.erase(node)
		if is_instance_valid(node):
			(node as Node).queue_free()
	_layers.erase(id)


## A skinned layer's binds named by the figure's own bones: a bind that names a bone the way the layer's rig did
## ("mixamorig:Hips") is renamed to the figure's ("mixamorig_Hips"); one that only gives a bone index takes its name
## from the layer's own skeleton. The skin is copied, so the layer's model keeps its own.
func _bound_skin(skin: Skin, own: Skeleton3D) -> Skin:
	var out := skin.duplicate() as Skin
	for i in out.get_bind_count():
		var name := str(out.get_bind_name(i))
		if name == "" and own != null and out.get_bind_bone(i) >= 0 and out.get_bind_bone(i) < own.get_bone_count():
			name = own.get_bone_name(out.get_bind_bone(i))
		var b := FigureModels.bone(_skeleton, name) if name != "" else -1
		if b >= 0:
			out.set_bind_name(i, _skeleton.get_bone_name(b))
			out.set_bind_bone(i, -1)
	return out


## Where a rigid piece sits on its bone: the figure entry's frame for that bone (`sockets`, the palm of this model's
## hand, say), then the part's own `offset` and `turn`, its `grip` (the point held, in the piece's own units; its middle
## when none is given) on the bone, and the piece scaled so its longest side is `size` of the figure's height.
## Offsets are in figure heights, so a part sits the same on a tall figure as on a short one.
func _hold_at(piece: Node3D, entry: Dictionary, bone_name: String, turns_with_bone := true) -> Transform3D:
	var h := _rest_height / _skeleton_scale()
	var box := rest_box(piece)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var size := float(entry.get("size", 0.0))
	var s := size * h / longest if size > 0.0 and longest > 0.0001 else 1.0
	var frame := Transform3D.IDENTITY
	var sockets := _info.get("sockets", {}) as Dictionary
	for key: Variant in sockets:
		if FigureModels.bone_key(str(key)) == FigureModels.bone_key(bone_name):
			var sock := sockets[key] as Dictionary
			frame = Transform3D(_euler(sock.get("turn")) if turns_with_bone else Basis.IDENTITY, _vec(sock.get("offset")) * h)
	var basis := _euler(entry.get("turn")) * Basis.from_scale(Vector3.ONE * s)
	var grip := _vec(entry.get("grip"), box.get_center())
	return frame * Transform3D(basis, _vec(entry.get("offset")) * h - basis * grip)


## Upright pieces to their bones, once the clip has set the pose.
func _follow_bones() -> void:
	for hold: Variant in _upright:
		if is_instance_valid(hold):
			(hold as Node3D).position = _skeleton.get_bone_global_pose(int(_upright[hold])).origin


## How much the model's own units are scaled on the way down to its skeleton (an exporter's armature scale).
func _skeleton_scale() -> float:
	var sc := 1.0
	var p: Node = _skeleton.get_parent()
	while p != null and p != model and p is Node3D:
		sc *= (p as Node3D).transform.basis.get_scale().y
		p = p.get_parent()
	return maxf(sc, 0.0001)


static func _vec(v: Variant, fallback := Vector3.ZERO) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float((v as Array)[0]), float((v as Array)[1]), float((v as Array)[2]))
	return fallback


## Degrees about x, y and z as a basis.
static func _euler(v: Variant) -> Basis:
	var d := _vec(v)
	return Basis.from_euler(Vector3(deg_to_rad(d.x), deg_to_rad(d.y), deg_to_rad(d.z)))


## The entry's `bones`: each grown or shrunk on top of every clip (FigureBones).
func _bones() -> void:
	var want := _info.get("bones", {}) as Dictionary
	if want.is_empty() or _skeleton == null:
		return
	var fb := FigureBones.new()
	fb.name = "FigureBones"
	for bone: String in want:
		var i := FigureBones.bone_named(_skeleton, bone)
		if i < 0:
			push_warning("figure %s: no bone %s to scale" % [art_id, bone])
			continue
		fb.scales[i] = float(want[bone])
	if fb.scales.is_empty():
		fb.free()
		return
	_skeleton.add_child(fb)


# --- Clips ------------------------------------------------------------------------------------------------------------

## The model's clips for each role: the manifest's names where it gives them, else the usual names (FigureModels.CLIPS).
func _read_clips() -> void:
	if _player == null:
		return
	var names := _player.get_animation_list()
	var own := _info.get("clips", {}) as Dictionary
	for role: String in FigureModels.CLIPS:
		var wanted: Variant = own.get(role, FigureModels.CLIPS[role])
		var specs: Array[Dictionary] = []
		for w: Variant in (wanted as Array if wanted is Array else [wanted]):
			var spec := (w as Dictionary).duplicate() if w is Dictionary else {"clip": str(w)}
			var found := clip_named(names, str(spec.get("clip", "")))
			if found == "":
				continue
			spec["name"] = found
			specs.append(spec)
			_ready_clip(found, role)
			if not own.has(role) and not role in VARIED:
				break
		if not specs.is_empty():
			_roles[role] = specs
	# A walk-only rig stands still and breathes (_play_loop), unless its manifest says idle_from_walk: then it idles on its
	# walk, slowed to a stir.
	if not _roles.has("idle") and _roles.has("walk") and bool(_info.get("idle_from_walk", false)):
		var stir: Array[Dictionary] = []
		for spec: Dictionary in _roles["walk"] as Array:
			var b := spec.duplicate()
			b["speed"] = float(spec.get("speed", 1.0)) * IDLE_STIR
			stir.append(b)
		_roles["idle"] = stir


## The clip of `names` called `wanted`, ignoring case, a library prefix and the numbered suffix exporters add
## ("idle.001", "Armature|walk", "preset:quadruped:walk"); "" when there is none.
static func clip_named(names: PackedStringArray, wanted: String) -> String:
	if wanted == "":
		return ""
	var want := plain(wanted)
	for n in names:
		if plain(n) == want:
			return n
	return ""


static func plain(clip: String) -> String:
	var s := clip.to_lower()
	for sep: String in ["/", "|", ":"]:
		s = s.get_slice(sep, s.get_slice_count(sep) - 1)
	var dot := s.rfind(".")
	if dot > 0 and s.substr(dot + 1).is_valid_int():
		s = s.substr(0, dot)
	return s


## Readies clip `clip` once for every copy of the model: loops loop, and a clip that carries the model forward (its root
## bone drifting across the ground) is held in place, the distance it covered kept as its stride ("figure_stride",
## world units at the model's own size) and the moments its body is lowest, its feet coming down ("figure_steps", a
## share of the clip each).
func _ready_clip(clip: String, role: String) -> void:
	var anim := _player.get_animation(clip)
	if anim == null:
		return
	if role in FigureModels.LOOPS:
		anim.loop_mode = Animation.LOOP_LINEAR
	if anim.has_meta("figure_stride"):
		return
	var stride := 0.0
	var steps := PackedFloat32Array()
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D or not _is_root_bone(anim.track_get_path(t)):
			continue
		var count := anim.track_get_key_count(t)
		if count < 2 or anim.length <= 0.0:
			continue
		var first := anim.track_get_key_value(t, 0) as Vector3
		var drift := anim.track_get_key_value(t, count - 1) as Vector3 - first
		drift.y = 0.0
		if role == "die":
			# A fall that carries the body off to one side (Tripo's falls end most of a square away): the root is held
			# over the square throughout, so the figure goes down where it stood and lies across it.
			for k in count:
				var v := anim.track_get_key_value(t, k) as Vector3
				anim.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))
			continue
		if drift.length() > 0.001:
			stride = maxf(stride, drift.length() * _bone_space_scale())
			var sum := Vector3.ZERO
			for k in count:
				var v := anim.track_get_key_value(t, k) as Vector3 - drift * (anim.track_get_key_time(t, k) / anim.length)
				anim.track_set_key_value(t, k, v)
				sum += v
			if role in FigureModels.LOOPS:
				# A loop can start mid-stride, the body well ahead of the feet's rest (Tripo's run starts half a square
				# on): its middle is put where the model stands at rest, so the figure runs over its own square.
				var off := sum / count - _rest_origin(_track_bone(anim.track_get_path(t)))
				off.y = 0.0
				for k in count:
					anim.track_set_key_value(t, k, anim.track_get_key_value(t, k) as Vector3 - off)
		if steps.is_empty():
			steps = _low_points(anim, t)
	anim.set_meta("figure_stride", stride)
	anim.set_meta("figure_steps", steps)


## Whether an animation track's path is a bone with no parent (a skeleton's root: Hips, Root).
func _is_root_bone(path: NodePath) -> bool:
	var bone := _track_bone(path)
	return bone >= 0 and _skeleton.get_bone_parent(bone) < 0


## The skeleton's bone an animation track's path names, or -1.
func _track_bone(path: NodePath) -> int:
	if _skeleton == null or path.get_subname_count() == 0:
		return -1
	return _skeleton.find_bone(str(path.get_subname(path.get_subname_count() - 1)))


## Where bone `bone` sits in the model's rest pose (its parent's space, as its position track's keys are).
func _rest_origin(bone: int) -> Vector3:
	return _skeleton.get_bone_rest(bone).origin if bone >= 0 else Vector3.ZERO


## Model units per unit of the skeleton's own space (an Armature exported at 0.01 scale, say).
func _bone_space_scale() -> float:
	if _skeleton == null:
		return 1.0
	var xf := Transform3D.IDENTITY
	var p: Node = _skeleton
	while p != model and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.basis.get_scale().x


## Where a root bone's height track is lowest, each a share of the clip: in a walk the body is lowest just as a foot
## takes the weight, so these are the footfalls.
static func _low_points(anim: Animation, track: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := anim.track_get_key_count(track)
	var ys := PackedFloat32Array()
	var lo := INF
	var hi := -INF
	for k in n:
		var y := (anim.track_get_key_value(track, k) as Vector3).y
		ys.append(y)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	if hi - lo < 1e-4:
		return out
	for k in n:
		var y := ys[k]
		if y < ys[posmod(k - 1, n)] and y <= ys[posmod(k + 1, n)] and y < lo + (hi - lo) * 0.4:
			out.append(anim.track_get_key_time(track, k) / anim.length)
	return out


## Whether the model has a clip for `role`.
func has_role(role: String) -> bool:
	return _roles.has(role)


func _spec(role: String) -> Dictionary:
	var specs := _roles.get(role, []) as Array
	if specs.is_empty():
		return {}
	var i := int(_turns.get(role, 0))
	_turns[role] = (i + 1) % specs.size()
	return specs[i % specs.size()] as Dictionary


func _play_loop(role: String, rate: float) -> void:
	if _player == null:
		return
	var spec := _spec(role) if role != _loop else (_roles.get(role, [{}]) as Array)[0] as Dictionary
	if spec.is_empty():
		if role != "idle":
			_play_loop("idle", 1.0)
		elif _loop != "idle":
			# No idle clip (a walk-only rig): stand in the rest pose, breathing (_breath), rather than walking on the spot.
			_player.stop()
			if _skeleton != null:
				_skeleton.reset_bone_poses()
			_loop = "idle"
		return
	_rate = rate
	if role != _loop or _player.current_animation != str(spec["name"]):
		_player.play(str(spec["name"]), BLEND)
		_walk_at = -1.0
	_loop = role
	_player.speed_scale = rate * float(spec.get("speed", 1.0))


## Plays `role`'s clip once (or the part of it the manifest names); `lands` when it lands a blow (struck at `hit`).
## False when the model has no clip for it.
func _play_role(role: String, lands: bool) -> bool:
	var spec := _spec(role)
	if spec.is_empty() or _player == null:
		return false
	var name := str(spec["name"])
	var length := _player.get_animation(name).length
	var from := clampf(float(spec.get("from", 0.0)), 0.0, length)
	var to := clampf(float(spec.get("to", length)), from, length)
	_clip = spec.duplicate()
	_clip["role"] = role
	_clip["from"] = from
	_clip["to"] = to
	_clip["hit"] = clampf(float(spec.get("hit", from + (to - from) * 0.45)), from, to)
	_one_shot = role
	_attacking = lands
	_struck = not lands
	moving = false
	_loop = ""
	_rise_to = -1.0   # a clip cuts a getting-up short
	_player.play(name, BLEND)
	_player.seek(from, true)
	_player.speed_scale = float(spec.get("speed", 1.0))
	return true


func _end_clip() -> void:
	var role := str(_clip.get("role", ""))
	_clip = {}
	_one_shot = ""
	if _attacking:
		_attacking = false
		if not _struck:
			_struck = true
			struck.emit()
		attack_finished.emit()
	if role == "die" and pose == "down":
		return   # it lies where the clip left it
	_play_loop("idle", 1.0)


# --- What a DirectionalSprite does ------------------------------------------------------------------------------------

func set_step_time(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var role := "walk"
	var rate := _rate_for("walk", 1.0 / seconds)
	if rate > RUN_FROM and has_role("run") and pose != "sneak":
		role = "run"
		rate = _rate_for("run", 1.0 / seconds)
	walk_speed = clampf(rate, MIN_WALK_RATE, MAX_WALK_RATE)
	set_meta("walk_role", role)


## The rate `role`'s clip plays at to cover `speed` world units a second.
func _rate_for(role: String, speed: float) -> float:
	var specs := _roles.get(role, []) as Array
	if specs.is_empty() or _player == null:
		return 1.0
	var spec := specs[0] as Dictionary
	var anim := _player.get_animation(str(spec["name"]))
	var stride := float(anim.get_meta("figure_stride", 0.0)) * _scale
	var natural := stride / maxf(anim.length, 0.01) if stride > 0.01 else IN_PLACE_PACE * _height
	return speed / maxf(natural * float(spec.get("speed", 1.0)), 0.01)


func attack() -> bool:
	return _play_role("attack", true)


func cast() -> bool:
	return _play_role("cast", true)


## The hurt clip with a flash; the recoil's lean instead when there is no clip, or the figure is busy swinging.
func hurt() -> bool:
	if pose == "down" or _attacking or _one_shot == "die" or not has_role("hurt"):
		recoil()
		return false
	_flash = 1.0
	return _play_role("hurt", false)


## Falls and lies there (pose "down"): its die clip, else it tips over backward. False when already down or falling.
func die() -> bool:
	if _one_shot == "die" or (pose == "down" and _lie_to >= 1.0) or _fell_by_clip:
		return false
	pose = "down"
	if _play_role("die", false):
		_fell_by_clip = true
		return true
	_one_shot = "die"
	_lie_to = 1.0
	return true


## A talk or greet gesture (FigureTalk), when standing free; false when the model has none or is busy.
func gesture(kind: String) -> bool:
	if moving or pose == "down" or _one_shot != "":
		return false
	return _play_role(kind, false)


func is_dying() -> bool:
	return _one_shot == "die"


func recoil() -> void:
	if pose == "down":
		return
	_flash = 1.0
	_tilt_v -= 7.0 * GameFeel.num("knockback")


## Whether a ray (from `origin` along `dir`) passes through the figure: a column down its middle as tall as it is, as
## wide as a sprite's picking band (SpritePick). Its distance along the ray, or INF.
func ray_hit(origin: Vector3, dir: Vector3) -> float:
	var r := maxf(0.25, _height * 0.24)
	var base := global_position
	var o := Vector2(origin.x - base.x, origin.z - base.z)
	var d := Vector2(dir.x, dir.z)
	var a := d.dot(d)
	if a < 1e-8:
		return INF
	var b := 2.0 * o.dot(d)
	var c := o.dot(o) - r * r
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return INF
	var t := (-b - sqrt(disc)) / (2.0 * a)
	var lying := _lie > 0.5
	for tt: float in [t, (-b + sqrt(disc)) / (2.0 * a)]:
		if tt <= 0.0:
			continue
		var y := origin.y + dir.y * tt - base.y
		if y >= -0.05 and y <= (0.4 if lying else _height):
			return tt
	return INF


func _process(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	_time += dt
	_show_modulate()
	_flash = maxf(0.0, _flash - dt / maxf(GameFeel.num("flash_seconds"), 0.01))
	_each_mesh("flash", clampf(_flash, 0.0, 1.0) * clampf(GameFeel.num("flash"), 0.0, 1.0))
	_face(dt)
	_spring(dt)
	_pose_step(dt)
	if _player == null:
		return
	if not _clip.is_empty():
		_clip_step()
		if not _clip.is_empty():
			if moving and str(_clip.get("role")) != "die":
				_end_clip()   # moving again cuts the clip short
			else:
				return
	finish_stride = false
	if pose == "down":
		return
	if _rise_to >= 0.0:
		if not moving and _player.is_playing() and _player.current_animation_position > _rise_to + 0.02:
			return   # still getting up
		_rise_to = -1.0
		_one_shot = ""
	var role := str(get_meta("walk_role", "walk")) if moving else "idle"
	if not has_role(role):
		role = "walk" if moving else "idle"
	var rate := walk_speed if moving else 1.0
	if role != _loop or not is_equal_approx(rate, _rate):
		_play_loop(role, rate)
	if moving:
		_footfalls()


## The figure's modulate (CombatToken's fades, tints and flashes) onto its surfaces.
func _show_modulate() -> void:
	if modulate == _shown_modulate:
		return
	_shown_modulate = modulate
	_each_mesh("tint", Vector4(modulate.r, modulate.g, modulate.b, modulate.a))


## Turns toward `facing`, the short way round; the first time at once.
func _face(dt: float) -> void:
	if facing.length_squared() < 0.0001:
		return
	var want := atan2(facing.x, facing.z)
	if not _faced:
		_faced = true
		_yaw = want
	else:
		var diff := wrapf(want - _yaw, -PI, PI)
		_yaw += clampf(diff, -TURN_RATE * dt, TURN_RATE * dt)
	_turn.rotation.y = _yaw


## The recoil: a quick lean back from a blow, springing upright.
func _spring(dt: float) -> void:
	_tilt_v += (-SPRING * _tilt - DAMP * _tilt_v) * dt
	_tilt += _tilt_v * dt


## Standing or lying: on its back, centred on its square (the fall turns it about its middle and lowers it), plus the
## recoil's lean.
func _pose_step(dt: float) -> void:
	if pose == "down" and not _fell_by_clip:
		_lie_to = 1.0
	elif pose != "down":
		_lie_to = 0.0
		if _fell_by_clip:
			_fell_by_clip = false
			_get_up_by_clip()
	if _lie != _lie_to:
		var falling := _lie_to > _lie
		_lie = move_toward(_lie, _lie_to, dt / (FALL_SECONDS if falling else RISE_SECONDS))
		if falling and _lie >= 1.0:
			if _one_shot == "die":
				_one_shot = ""
			if _player != null:
				_player.pause()   # lying still
				_loop = ""
	# A fall gathers speed (eased in); getting up eases out. It turns about the figure's middle and drops it to the
	# ground; the recoil leans it back from its feet.
	var f := _lie * _lie if _lie_to >= _lie else 1.0 - (1.0 - _lie) * (1.0 - _lie)
	var c := _height * 0.5
	var back := Basis(Vector3.RIGHT, -PI * 0.5 * f)
	var pivot := Vector3(0.0, c, 0.0)
	var lie := Transform3D(back, pivot - back * pivot + Vector3(0.0, (_back_depth() - c) * f, 0.0))
	var lean := Basis(Vector3.RIGHT, clampf(_tilt, -1.0, 1.0) * 0.18 * (1.0 - f))
	_posture.transform = lie * Transform3D(lean * _breath(), Vector3.ZERO)


## A model with no idle clip, standing still, breathes: a little taller and narrower at the top of each breath, from
## its feet (GameFeel's `breath` scales it, as for sprites). Otherwise no change.
func _breath() -> Basis:
	if has_role("idle") or moving or pose == "down" or _lie > 0.0 or _one_shot != "":
		return Basis.IDENTITY
	var b := sin(_time * TAU / BREATH_PERIOD + _breath_phase) * BREATH * GameFeel.num("breath")
	return Basis.from_scale(Vector3(1.0 - b * 0.5, 1.0 + b, 1.0 - b * 0.5))


## Gets up from a die clip's last frame: the fall played backwards to its start over RISE_CLIP_SECONDS, then the idle
## blends in (_process). Without the clip, the idle at once.
func _get_up_by_clip() -> void:
	var specs := _roles.get("die", []) as Array
	if specs.is_empty() or _player == null:
		_play_loop("idle", 1.0)
		return
	var spec := specs[0] as Dictionary
	var name := str(spec["name"])
	var length := _player.get_animation(name).length
	var from := clampf(float(spec.get("from", 0.0)), 0.0, length)
	var to := clampf(float(spec.get("to", length)), from, length)
	_player.play(name, 0.0, -(to - from) / RISE_CLIP_SECONDS, true)
	_player.seek(to, true)
	_player.speed_scale = 1.0
	_rise_to = from
	_one_shot = "rise"
	_loop = ""


## How far the model's back lies behind its middle (its depth from front to back, halved), so it lies on the ground.
func _back_depth() -> float:
	if model == null:
		return 0.0
	if not has_meta("back_depth"):
		var box := rest_box(model)
		set_meta("back_depth", maxf(0.0, -box.position.z) * _scale)
	return float(get_meta("back_depth"))


## The one-shot clip: its blow lands at `hit`; it ends at `to` (or when the clip runs out).
func _clip_step() -> void:
	var pos := _player.current_animation_position
	var name := str(_clip.get("name", ""))
	if _attacking and not _struck and pos >= float(_clip["hit"]):
		_struck = true
		struck.emit()
	if _player.current_animation != name or not _player.is_playing() or pos >= float(_clip["to"]) - 0.001:
		if str(_clip.get("role")) == "die":
			_player.pause()   # the fall's last frame is how it lies
		_end_clip()


## A footfall each time the walk passes one of its low points (two a cycle when the clip shows none).
func _footfalls() -> void:
	var anim := _player.get_animation(_player.current_animation) if _player.current_animation != "" else null
	if anim == null or anim.length <= 0.0:
		return
	var at := fmod(_player.current_animation_position, anim.length) / anim.length
	var steps := anim.get_meta("figure_steps", PackedFloat32Array()) as PackedFloat32Array
	if steps.is_empty():
		steps = PackedFloat32Array([0.0, 0.5])
	if _walk_at >= 0.0:
		for s in steps:
			var passed := (s > _walk_at and s <= at) if at >= _walk_at else (s > _walk_at or s <= at)
			if passed:
				footfall.emit()
				break
	_walk_at = at
