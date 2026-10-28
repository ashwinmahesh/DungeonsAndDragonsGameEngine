class_name ArtPaths
extends RefCounted
## Art that a game and the engine core both hold (docs/plans/engine_split.md): monster sprites and portraits live in the core,
## the game's own heroes, NPCs and villains in the game. A file is looked up in the game first (res://<rel>), then in the core
## (res://addons/dnd_core/<rel>), so a game can also replace a core picture by putting one with the same path in its own art/.

const CORE := "res://addons/dnd_core/"

static var _found: Dictionary = {}


## The path of `rel` ("art/sprites/wolf/walk.tres"): the game's if it has one, else the core's (also when neither has it).
static func of(rel: String) -> String:
	if _found.has(rel):
		return _found[rel] as String
	var game := "res://" + rel
	var path := game if _has(game) else CORE + rel
	if _has(path):
		_found[rel] = path   # only a hit is remembered: a file made later (a tool, a test) is still found
	return path


static func exists(rel: String) -> bool:
	return _has("res://" + rel) or _has(CORE + rel)


## The folders (just their names) under `rel_dir` in the game and in the core, each once.
static func dirs(rel_dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for root in ["res://", CORE]:
		for d in DirAccess.get_directories_at(root + rel_dir):
			if not d in out:
				out.append(d)
	out.sort()
	return out


## A JSON table that the core ships and a game may add to (art/vfx/effects.json, art/creature_looks.json, the texture, prop and model
## manifests): the core's file, then the game's merged over it, key by key all the way down (a key both have that holds tables is
## merged, anything else is the game's).
static func json(rel: String) -> Dictionary:
	return _merge(_read(CORE + rel), _read("res://" + rel))


static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	for key: Variant in over:
		if base.get(key) is Dictionary and over[key] is Dictionary:
			base[key] = _merge(base[key] as Dictionary, over[key] as Dictionary)
		else:
			base[key] = over[key]
	return base


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


static func _has(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)
