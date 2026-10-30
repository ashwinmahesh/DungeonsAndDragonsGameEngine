extends Node3D
## The natural-world audit (principles 1.6 and 5.1; plan E29): every location, or the ones named, built as in the game
## and shot four ways: whole from above, whole with the battle grid laid over it (the grid derived from the land, as the
## player sees it while the key is held), from the play camera at the party's spawn, and tilted to the horizon there. A
## map is done when no square corner of water, row of trees, flat-topped block or straight slab shows in the first three,
## and the grid in the second sits on the land. Not part of the game: a game's capture tool runs this scene.
##   make capture SCENE=res://addons/dnd_core/world/authoring/natural_audit.tscn NAME=natural/before FRAMES=10
## Environment: NA_LOCS=a,b (default every location with a map), NA_SHOTS=whole,grid,play,tilt (default all four),
## NA_HOUR=12, NA_WEATHER=overcast (the world's weather for the whole run; default the new game's own), NA_AT=x,z (the
## play and tilt shots look at this square instead of the spawn; with one place only).
## NA_PARTY=a,b,c,d (the pregens who stand at the spawn; default the first four of the game's pregens).
## Shots: <out>_<loc>_whole.png, _grid.png, _play.png, _tilt.png.

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	var weather := OS.get_environment("NA_WEATHER")
	if weather != "":
		# Every climate has only that weather, for this run.
		var d := Weather.data().duplicate(true)
		var climates := {}
		for c: String in d.get("climates", {}) as Dictionary:
			climates[c] = {weather: 1}
		d["climates"] = climates
		Weather.use(d)


## Every location with a map, in id order.
static func locations() -> Array[String]:
	var out: Array[String] = []
	for id: String in Compendium.shared().tables["locations"] as Dictionary:
		if (Compendium.shared().get_entry("locations", id) as Dictionary).has("map"):
			out.append(id)
	out.sort()
	return out


func capture_shots(tool: Node, out: String) -> void:
	var ids := locations()
	if OS.get_environment("NA_LOCS") != "":
		ids.assign(OS.get_environment("NA_LOCS").split(",", false))
	var shots := OS.get_environment("NA_SHOTS").split(",", false)
	if shots.is_empty():
		shots = PackedStringArray(["whole", "grid", "play", "tilt"])
	var hour := int(OS.get_environment("NA_HOUR")) if OS.get_environment("NA_HOUR") != "" else 12
	for id in ids:
		_build(id, hour)
		await tool.call("wait_frames", 30)
		var rig := view.rig
		var at := view.board.cell_center(_spawn())
		if OS.get_environment("NA_AT") != "":
			var a := OS.get_environment("NA_AT").split(",")
			at = view.board.cell_center(Vector2i(int(a[0]), int(a[1])))
		if "whole" in shots:
			rig.horizon = 0.0
			rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
			rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
			rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_whole.png" % [out, id])
		if "grid" in shots:
			rig.horizon = 0.0
			rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
			rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
			rig.snap_to_target()
			var lines := BattleGrid.create(view.board)
			lines.latched = true
			view.board.add_child(lines)
			lines.gather(null)
			await tool.call("wait_frames", 30)
			tool.call("_shot", "%s_%s_grid.png" % [out, id])
			lines.queue_free()
		if "play" in shots:
			rig.horizon = 0.0
			rig.distance = 16.0
			rig.global_position = at
			rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_play.png" % [out, id])
		if "tilt" in shots:
			rig.horizon = 1.0
			rig.distance = 22.0
			rig.global_position = at
			rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_tilt.png" % [out, id])
		view.queue_free()
		view = null
		await tool.call("wait_frames", 2)


## The heroes who stand at the spawn: NA_PARTY, else the first four of the game's pregens by id.
static func party() -> Array[String]:
	var out: Array[String] = []
	if OS.get_environment("NA_PARTY") != "":
		out.assign(OS.get_environment("NA_PARTY").split(",", false))
		return out
	var ids: Array = (Compendium.shared().tables.get("pregens", {}) as Dictionary).keys()
	ids.sort()
	for i in mini(4, ids.size()):
		out.append(str(ids[i]))
	return out


## Where the party stands on arrival: the leader's square.
func _spawn() -> Vector2i:
	if view.leader() != null:
		return view.leader().cell
	return Vector2i(view.grid.width / 2, view.grid.depth / 2)


func _build(loc_id: String, hour: int) -> void:
	GameState.reset()
	for id: String in party():
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	var rig := view.rig
	rig.follow = null
	rig.zoom_max = maxf(rig.zoom_max, 60.0)
