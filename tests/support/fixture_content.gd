class_name FixtureContent
extends RefCounted
## Content a test builds itself, so an engine test needs nothing from the game that hosts the engine (its places, people, quests
## or stat blocks). `add` puts an entry into the shared Compendium; `restore` takes every one back out, or puts back the entry
## of the same id it replaced. Call `restore()` from the test's after_each (the runner also drops ids a file added).

var _saved: Array[Dictionary] = []


## Adds (or replaces) one entry of a Compendium folder and returns it. The entry needs an "id".
func add(folder: String, entry: Dictionary) -> Dictionary:
	var comp := Compendium.shared()
	if not comp.tables.has(folder):
		comp.tables[folder] = {}
	var table := comp.tables[folder] as Dictionary
	var id := str(entry["id"])
	_saved.append({"folder": folder, "id": id, "had": table.has(id), "old": table.get(id, {})})
	table[id] = entry
	return entry


## Adds an entry read from a fixture file (tests/fixtures/<name>.json, a JSON object with an "id").
func add_file(folder: String, fixture: String) -> Dictionary:
	var path := Compendium.core_root().path_join("tests/fixtures").path_join(fixture)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "fixture %s is a JSON object" % path)
	return add(folder, parsed as Dictionary)


## A story ally the party can take along (an NPC with `guest: true`) built on a core stat block; returns its id.
func add_guest(id: String = "test_ally", monster: String = "wereraven") -> String:
	add("npcs", {"id": id, "name": "Test Ally", "summary": "A guest the test builds.", "attitude": "friendly", "monster": monster,
		"guest": true, "guest_build": {"monster": monster}})
	return id


## A quest with the given stages, [id, ends] pairs in order ("" while open, else "success" or "failure"); returns its id.
func add_quest(id: String, quest_name: String, stages: Array) -> String:
	var list: Array[Dictionary] = []
	for st: Variant in stages:
		var pair := st as Array
		list.append({"id": pair[0], "journal": "The %s stage." % pair[0], "objectives": [], "ends": pair[1]})
	add("quests", {"id": id, "name": quest_name, "summary": "A quest the test builds.", "stages": list})
	return id


## A place with `containers` chests (each holding `items`, [{id, qty}]) and a treasure level, named without a "test_" prefix so
## sweeps over the host's real places take it in too. Returns its id.
func add_location(id: String, containers: int, items: Array = [], treasure_level: int = 6) -> String:
	var chests: Array[Dictionary] = []
	for i in containers:
		chests.append({"id": "%s_chest_%d" % [id, i], "cell": [i, 1], "label": "A chest", "model": "chest",
			"items": items.duplicate(true) if i == 0 else [], "gold": 10})
	add("locations", {"id": id, "name": "Fixture Place", "region": "fixture_region", "summary": "A place the test builds.",
		"treasure_level": treasure_level, "containers": chests, "props": []})
	Treasure.reset()
	return id


## Rebuilds the table of spells that magic items carry in themselves, after an item with `recipes` was added or removed.
func refresh_item_spells() -> void:
	Compendium.shared()._register_item_recipes()


func restore() -> void:
	var comp := Compendium.shared()
	for i in range(_saved.size() - 1, -1, -1):
		var s := _saved[i]
		var table := comp.tables.get(s["folder"], {}) as Dictionary
		if bool(s["had"]):
			table[s["id"]] = s["old"]
		else:
			table.erase(s["id"])
	_saved.clear()
	Treasure.reset()   # its table of the story's own items was built with the fixture places in it
