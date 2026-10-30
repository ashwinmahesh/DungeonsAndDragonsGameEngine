extends SceneTree
## Lays a sketched place into a location's grid (PlaceSketch; plan E29), from the command line:
##   godot --headless --path . --script res://addons/dnd_core/world/authoring/sketch_tool.gd -- \
##     --height=sketch/hill_height.png --layout=sketch/hill_layout.png --size=34x28 [--top=30] \
##     [--loc=data/locations/hill.json] [--preview=captures/hill_grid.png] [--force]
## Prints the rows, the elevation rows and the report. With --loc it writes them into that location's `map` (keeping the
## rest of the file); a location that already has rows keeps its walkable squares, spawns and exits (the bots are
## path-sensitive: extend a map, don't redraw it), so the tool refuses a sketch that closes any of them unless --force.
## A game's Makefile wraps it (make sketch).


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq := a.find("=")
			args[a.substr(2, eq - 2) if eq > 0 else a.substr(2)] = a.substr(eq + 1) if eq > 0 else "true"
	var code := run(args)
	quit(code)


static func run(args: Dictionary) -> int:
	var size_s := str(args.get("size", "")).split("x")
	if size_s.size() != 2:
		printerr("sketch: --size=WxD (squares across and down) is needed")
		return 2
	var size := Vector2i(int(size_s[0]), int(size_s[1]))
	var height := _image(str(args.get("height", "")))
	var layout := _image(str(args.get("layout", "")))
	if height == null and layout == null:
		printerr("sketch: give --height and/or --layout pictures")
		return 2
	var laid := PlaceSketch.lay(height, layout, size, {"top_ft": float(args.get("top", PlaceSketch.TOP_FT))})
	var rows := laid["rows"] as Array[String]
	var elevation := laid["elevation"] as Array[String]
	print("rows:")
	for r in rows:
		print("  \"%s\"," % r)
	print("elevation:")
	for r in elevation:
		print("  \"%s\"," % r)
	for w: String in (laid["report"] as Dictionary)["warnings"]:
		print("look at: " + w)
	if args.has("preview"):
		PlaceSketch.preview(rows, elevation).save_png(str(args["preview"]))
		print("preview: " + str(args["preview"]))
	if args.has("loc"):
		return _write(str(args["loc"]), rows, elevation, args.has("force"))
	return 0


static func _image(path: String) -> Image:
	if path == "":
		return null
	var img := Image.load_from_file(path)
	if img == null:
		printerr("sketch: can't read %s" % path)
	return img


## Writes the rows into the location file, unless they close a square, spawn or exit the old rows had open.
static func _write(path: String, rows: Array[String], elevation: Array[String], force: bool) -> int:
	var loc := {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			loc = parsed as Dictionary
	var map := loc.get("map", {}) as Dictionary
	var closed := closes(loc, rows)
	if not closed.is_empty() and not force:
		printerr("sketch: the new rows close %d squares the map had open (first: %s); a walked map is extended, not redrawn. --force to write anyway" % [closed.size(), closed[0]])
		return 1
	map["rows"] = rows
	map["elevation"] = elevation
	loc["map"] = map
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(loc, "  ") + "\n")
	print("wrote: " + path)
	return 0


## The squares open in location `loc`'s rows (walkable, a spawn or an exit's square) that `rows` closes.
static func closes(loc: Dictionary, rows: Array[String]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var old := (loc.get("map", {}) as Dictionary).get("rows", []) as Array
	var keep := {}
	for z in old.size():
		var r := str(old[z])
		for x in r.length():
			if PlaceSketch._walkable(r[x]):
				keep[Vector2i(x, z)] = true
	for s: Variant in (loc.get("spawns", {}) as Dictionary).values():
		if s is Array and (s as Array).size() >= 2:
			keep[Vector2i(int((s as Array)[0]), int((s as Array)[1]))] = true
	for e: Variant in loc.get("exits", []) as Array:
		var c: Variant = (e as Dictionary).get("cell", null) if e is Dictionary else null
		if c is Array and (c as Array).size() >= 2:
			keep[Vector2i(int((c as Array)[0]), int((c as Array)[1]))] = true
	for c: Vector2i in keep:
		if c.y >= rows.size() or c.x >= rows[c.y].length() or not PlaceSketch._walkable(rows[c.y][c.x]):
			out.append(c)
	out.sort()
	return out
