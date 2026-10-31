class_name FigureModels
extends RefCounted
## 3D figures for characters and creatures (docs/reference/art/figures.md): a rigged model, a scene with a Skeleton3D,
## its skinned meshes and an AnimationPlayer of named clips (a GLB from Tripo Studio or Mixamo, say), stands in for an
## art id's 8-direction sprite wherever the game draws that art: the party, people, foes and guests (CombatToken), a
## spell's figure (FieldView), the gray-box room. Anything without a model keeps its sprite, so a game moves to 3D one
## figure at a time. art/figures/manifest.json (the core's, with the game's own entries merged over it) names them:
##   "figures": {"<art id>": {"file": "art/figures/rook.glb", "scale": 1.0, "lift": 0.0, "turn": 0.0, "clips": {...}}}
## `file` is the model (res:// relative); `scale` sizes it against the height CombatToken draws the art at (its feet on
## the ground, its top at that height, times `scale`); `lift` raises it (world units, negative sinks it); `turn` is
## the degrees it is turned about its up axis so it faces +z, the way a figure looks when it faces south. `clips` maps
## the figure's roles to the model's clip names where they aren't the usual ones (CLIPS), each a name, a list of names
## (picked in turn for variety), or {"clip", "from", "to", "hit", "speed", "loop"}: a part of a long clip, from and to
## in seconds, the moment the blow lands (`hit`, seconds into the clip) and how fast it plays. A manifest's "defaults"
## entry is under every figure's (its `clips` merged role by role): models made one way share their preset clips.
## Other keys are the game's own (its import tool's `source`), never read here.
##
## Layers (docs/reference/art/figures.md, "Layers"): a figure can wear parts on its own skeleton. The manifest's "parts"
## names them, `"<part id>": {"file": ..., "bone": ..., "size": ..., "offset": [...], "turn": [...], "grip": [...],
## "hides": [...]}`: a part with a `bone` is a rigid piece held on that bone (a sword, a lantern, a helmet), sized to
## `size` of the figure's height on its longest side; one without is a skinned layer (a coat, a cloak, boots) whose
## meshes join the figure's skeleton, bound bone by bone by name, so it moves with every clip. `hides` names the
## figure's own meshes the part covers. A figure entry's `layers` lists the parts it always wears, and
## ModelFigure.wear adds what it wears now (its gear).

const MANIFEST_JSON := "art/figures/manifest.json"   # the core's, with the game's own entries merged over it (ArtPaths.json)
## The stand-in sprite frames' metadata naming the figure's art id (DirectionalSprite.create makes a ModelFigure for them).
const META := &"figure_model"
## What a figure does, and the clip names each looks for when the manifest names none: the first a model has is used.
## idle and walk loop; the rest play once. Without attack, cast or hurt clips the figure lunges, gestures and recoils
## as a sprite without those frames does; without a die clip it falls procedurally (ModelFigure.die).
const CLIPS := {
	"idle": ["idle"],
	"walk": ["walk"],
	"run": ["run"],
	"attack": ["attack", "slash"],
	"cast": ["cast", "spell"],
	"hurt": ["hurt", "hit"],
	"die": ["die", "death", "fall"],
	"talk": ["talk", "agree", "complain_01", "complain"],
	"greet": ["greet", "greet_01", "wave"],
}
const LOOPS: Array[String] = ["idle", "walk", "run"]
## A role with no clip of its own plays another role's, at this speed: a creature rigged with only a walk (a crawler, a
## hound: Tripo's "Other" rig) idles on its walk, slowed to a stir, rather than standing in its bind pose. (A run falls
## back to the walk, sped up, in ModelFigure.set_step_time.)
const FALLBACKS := {
	"idle": {"role": "walk", "speed": 0.3},
}
## How deep `base` entries may stack (a dressing of a dressing); past it the chain is taken for a loop.
const MAX_BASES := 4

static var _manifest: Dictionary = {}
static var _defaults: Dictionary = {}
static var _entries: Dictionary = {}
static var _read := false
## Figures added in code (tests, a game's own at run time): art id -> [entry, PackedScene or null].
static var _registered: Dictionary = {}
## The manifests' parts (part id -> entry), and parts added in code: part id -> [entry, PackedScene or null].
static var _parts: Dictionary = {}
## The manifests' "gear": item id (or the mundane item under a magic one) -> the part it shows as.
static var _gear: Dictionary = {}
static var _registered_parts: Dictionary = {}
static var _frames: Dictionary = {}
static var _blank: ImageTexture


## Every model in the manifests: art id -> entry.
static func manifest() -> Dictionary:
	if not _read:
		_read = true
		var all := ArtPaths.json(MANIFEST_JSON)
		_manifest = all.get("figures", {}) as Dictionary
		_defaults = all.get("defaults", {}) as Dictionary
		_parts = all.get("parts", {}) as Dictionary
		_gear = all.get("gear", {}) as Dictionary
	return _manifest


## The entry for `art_id` over the manifests' defaults ({} when it has no model).
## An entry with a `base` is laid over that figure's entry, its `clips` merged role by role.
static func info(art_id: String) -> Dictionary:
	if _registered.has(art_id):
		return _resolved(art_id, 0)
	if _entries.has(art_id):
		return _entries[art_id] as Dictionary
	var out := _resolved(art_id, 0)
	if not out.is_empty():
		_entries[art_id] = out
	return out


## `art_id`'s own entry (one added in code as given, a manifest's over the defaults), laid over its `base`'s.
static func _resolved(art_id: String, depth: int) -> Dictionary:
	var registered := _registered.has(art_id)
	var own := ((_registered[art_id] as Array)[0] if registered else manifest().get(art_id, {})) as Dictionary
	if own.is_empty():
		return own
	var base := str(own.get("base", ""))
	if base != "" and base != art_id and depth < MAX_BASES:
		return _laid_over(_resolved(base, depth + 1), own)
	return own if registered else _laid_over(_defaults, own)


## `top` laid over `under`: its keys replace under's, its `clips` merged role by role.
static func _laid_over(under: Dictionary, top: Dictionary) -> Dictionary:
	if under.is_empty():
		return top
	var out := under.duplicate(true)
	for k: String in top:
		if k == "clips" and out.get("clips") is Dictionary and top[k] is Dictionary:
			(out["clips"] as Dictionary).merge(top[k] as Dictionary, true)
		else:
			out[k] = top[k]
	return out


## Whether `art_id` is drawn as a model: an entry whose file is there.
## A `base` entry's file is its base's.
static func has(art_id: String) -> bool:
	if art_id == "":
		return false
	if _registered.has(art_id):
		return true
	if not manifest().has(art_id):
		return false
	var file := str(info(art_id).get("file", ""))
	return file != "" and ResourceLoader.exists(ArtPaths.of(file))


## The sprite art id `art_id` wears while its model isn't there yet (its entry's `sprite`), or "" (it has its model, or
## no entry, or names no stand-in).
static func stand_in(art_id: String) -> String:
	if art_id == "" or has(art_id):
		return ""
	var sprite := str(info(art_id).get("sprite", ""))
	return sprite if sprite != art_id else ""


## The texture an entry paints its surfaces with in place of the model's own (`albedo`), or null.
static func albedo_of(art_id: String) -> Texture2D:
	var rel := str(info(art_id).get("albedo", ""))
	if rel == "" or not ArtPaths.exists(rel):
		return null
	return load(ArtPaths.of(rel)) as Texture2D


## The model's scene (a `base` entry's is its base's), or null.
static func scene(art_id: String) -> PackedScene:
	if _registered.has(art_id):
		var reg := _registered[art_id] as Array
		if reg[1] != null:
			return reg[1] as PackedScene
		var base := str((reg[0] as Dictionary).get("base", ""))
		if base != "" and base != art_id:
			return scene(base)
	var path := ArtPaths.of(str(info(art_id).get("file", "")))
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


## The path a place's preload reads for `art_id` ("" for none), so a model is in memory before its figure is made.
static func path_of(art_id: String) -> String:
	if not has(art_id) or _registered.has(art_id):
		return ""
	return ArtPaths.of(str(info(art_id).get("file", "")))


## Adds a figure in code: `entry` as a manifest entry, `packed` its scene (else the entry's file). Tests use it.
static func register(art_id: String, entry: Dictionary, packed: PackedScene = null) -> void:
	_registered[art_id] = [entry, packed]
	_frames.erase(art_id)


static func unregister(art_id: String) -> void:
	_registered.erase(art_id)
	_frames.erase(art_id)


## Reads the manifests again (a test that changed one).
static func forget() -> void:
	_read = false
	_manifest = {}
	_defaults = {}
	_parts = {}
	_gear = {}
	_entries.clear()
	_frames.clear()


# --- Layers ----------------------------------------------------------------------------------------------------------

## The entry of a part a figure can wear ({} when there is none).
static func part(part_id: String) -> Dictionary:
	if _registered_parts.has(part_id):
		return (_registered_parts[part_id] as Array)[0] as Dictionary
	manifest()
	return _parts.get(part_id, {}) as Dictionary


## Whether `part_id` is a part whose model is there.
static func has_part(part_id: String) -> bool:
	return part_scene(part_id) != null


## The part's scene, or null.
static func part_scene(part_id: String) -> PackedScene:
	if _registered_parts.has(part_id) and (_registered_parts[part_id] as Array)[1] != null:
		return (_registered_parts[part_id] as Array)[1] as PackedScene
	var file := str(part(part_id).get("file", ""))
	if file == "":
		return null
	var path := ArtPaths.of(file)
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


## Adds a part in code: `entry` as a manifest part, `packed` its scene (else the entry's file). Tests use it.
static func register_part(part_id: String, entry: Dictionary, packed: PackedScene = null) -> void:
	_registered_parts[part_id] = [entry, packed]


static func unregister_part(part_id: String) -> void:
	_registered_parts.erase(part_id)


## A part's id with this after it is the part held in the other hand (ModelFigure.wear).
const OFF_HAND := "@off"
## The slots a figure can show gear from, and for held things the hand: a part is made for the right hand, and the off
## hand holds it mirrored.
const HANDS := {"main_hand": "", "off_hand": OFF_HAND}


## The parts `ch`'s figure (`art_id`) wears for what they have on and in hand: in each slot its entry's `gear` lists
## ("main_hand", "off_hand", "armor", "cloak", "head"...), the part the item's data names (`look`), else the manifest's
## "gear" for the item's id, else for the mundane item under it (a +1 Longsword shows as a longsword). A figure whose
## entry lists no slots shows none: its model has its things drawn on.
static func gear_for(art_id: String, ch: Character) -> Array[String]:
	var out: Array[String] = []
	var slots := info(art_id).get("gear", []) as Array
	if slots.is_empty() or ch == null:
		return out
	manifest()
	for e: Dictionary in ch.inventory:
		var slot := str(e.get("slot", ""))
		if slot == "" or not slot in slots or int(e.get("qty", 1)) <= 0:
			continue
		var data := (ch.compendium if ch.compendium != null else Compendium.shared()).item_data(str(e["id"]))
		var p := str(data.get("look", ""))
		if p == "":
			p = str(_gear.get(str(e["id"]), _gear.get(MagicItems.base_id(data), "")))
		if p == "" or not has_part(p):
			continue
		p += str(HANDS.get(slot, ""))
		if not p in out:
			out.append(p)
	return out


## A part's entry for the other hand: its bone's Left and Right swapped, and its offset, turn and grip mirrored across
## the figure's middle.
static func mirrored(entry: Dictionary) -> Dictionary:
	var out := entry.duplicate(true)
	var b := str(entry.get("bone", ""))
	if b.contains("Right"):
		out["bone"] = b.replace("Right", "Left")
	elif b.contains("Left"):
		out["bone"] = b.replace("Left", "Right")
	for key: String in ["offset", "grip"]:
		if entry.get(key) is Array and (entry[key] as Array).size() >= 3:
			var v := (entry[key] as Array).duplicate()
			v[0] = -float(v[0])
			out[key] = v
	if entry.get("turn") is Array and (entry["turn"] as Array).size() >= 3:
		var t := (entry["turn"] as Array).duplicate()
		t[1] = -float(t[1])
		t[2] = -float(t[2])
		out["turn"] = t
	return out


## The bone of `skeleton` that `name` means, or -1: the same name, else the same once an exporter's prefix is set aside
## and case ignored ("RightHand", "mixamorig:RightHand" and "mixamorig_RightHand" are one bone), so a part made on one
## rig finds its bones on another rig of the same kind.
static func bone(skeleton: Skeleton3D, name: String) -> int:
	var exact := skeleton.find_bone(name)
	if exact >= 0:
		return exact
	var want := bone_key(name)
	for i in skeleton.get_bone_count():
		if bone_key(skeleton.get_bone_name(i)) == want:
			return i
	return -1


## A bone's name without its rig's prefix, lower case: "mixamorig:LeftHand" and "mixamorig_LeftHand" are "lefthand".
static func bone_key(name: String) -> String:
	var n := name.get_slice(":", name.get_slice_count(":") - 1).get_slice("|", name.get_slice_count("|") - 1)
	if n.to_lower().begins_with("mixamorig") and n.length() > 9:
		n = n.substr(9)
		while n != "" and (n[0].is_valid_int() or n[0] == "_"):   # "mixamorig1_Hips"
			n = n.substr(1)
	return n.to_lower()


## The stand-in frames for `art_id`: one blank frame per animation the sprite code asks after (idle, walk, attack,
## cast, and die and down, as the figure falls and lies down itself), with the art id as META. What the rest of the
## engine checks a sprite's frames for answers for the model this way; a model without an attack or cast clip says so
## when asked to play one (ModelFigure.attack returns false), as a sprite without the sheet does.
## `attack_casts` in the entry: the attack clip is a spell gesture, played for spells too (DirectionalSprite.attack_casts).
static func frames(art_id: String) -> SpriteFrames:
	if _frames.has(art_id):
		return _frames[art_id] as SpriteFrames
	if _blank == null:
		_blank = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	var f := SpriteFrames.new()
	f.remove_animation(&"default")
	for base: String in ["idle", "walk", "attack", "cast", "die", "down"]:
		for d: String in DirectionalSprite.DIRECTIONS:
			var anim := StringName(base + "_" + d)
			f.add_animation(anim)
			f.set_animation_loop(anim, base in LOOPS or base == "down")
			f.add_frame(anim, _blank)
	f.set_meta(META, art_id)
	f.set_meta("casts", bool(info(art_id).get("attack_casts", false)))
	_frames[art_id] = f
	return f


## The manifest's height for `art_id` if it gives one, else `fallback` (CombatToken.height_for asks).
static func height_of(art_id: String, fallback: float) -> float:
	return float(info(art_id).get("height", fallback))
