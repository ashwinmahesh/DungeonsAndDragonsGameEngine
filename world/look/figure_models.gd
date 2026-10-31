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

static var _manifest: Dictionary = {}
static var _defaults: Dictionary = {}
static var _entries: Dictionary = {}
static var _read := false
## Figures added in code (tests, a game's own at run time): art id -> [entry, PackedScene or null].
static var _registered: Dictionary = {}
static var _frames: Dictionary = {}
static var _blank: ImageTexture


## Every model in the manifests: art id -> entry.
static func manifest() -> Dictionary:
	if not _read:
		_read = true
		var all := ArtPaths.json(MANIFEST_JSON)
		_manifest = all.get("figures", {}) as Dictionary
		_defaults = all.get("defaults", {}) as Dictionary
	return _manifest


## The entry for `art_id` over the manifests' defaults ({} when it has no model).
static func info(art_id: String) -> Dictionary:
	if _registered.has(art_id):
		return (_registered[art_id] as Array)[0] as Dictionary
	if _entries.has(art_id):
		return _entries[art_id] as Dictionary
	var own := manifest().get(art_id, {}) as Dictionary
	if own.is_empty() or _defaults.is_empty():
		return own
	var out := _defaults.duplicate(true)
	for k: String in own:
		if k == "clips" and out.get("clips") is Dictionary and own[k] is Dictionary:
			(out["clips"] as Dictionary).merge(own[k] as Dictionary, true)
		else:
			out[k] = own[k]
	_entries[art_id] = out
	return out


## Whether `art_id` is drawn as a model: an entry whose file is there.
static func has(art_id: String) -> bool:
	if art_id == "":
		return false
	if _registered.has(art_id):
		return true
	var entry := manifest().get(art_id, {}) as Dictionary
	return not entry.is_empty() and ResourceLoader.exists(ArtPaths.of(str(entry.get("file", ""))))


## The model's scene, or null.
static func scene(art_id: String) -> PackedScene:
	if _registered.has(art_id) and (_registered[art_id] as Array)[1] != null:
		return (_registered[art_id] as Array)[1] as PackedScene
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
	_entries.clear()
	_frames.clear()


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
