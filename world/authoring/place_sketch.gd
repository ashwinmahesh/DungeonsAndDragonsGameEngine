class_name PlaceSketch
extends RefCounted
## A place designed as a place, laid into the grid (principles 1.6 and 5.1; plan E29). The author paints two pictures
## over the source's map, at any size and without a square in sight: a height painting (black the lowest ground, white
## `top_ft` above it, painted as land is: hills, hollows, banks, a creek bed) and a layout drawing in a few flat colours
## (KEY: water, woods, rock, buildings, difficult ground, low cover, void; anything else is open ground). `lay` derives
## the location's `map.rows` and `map.elevation` from them: each 5 ft square takes the feature covering most of it and
## the mean height of its ground (water the lowest of its bed), in 5 ft steps. The grid is what the land says, never
## drawn by hand, and the board draws the land natural again from those rows.
##
## `report` says what to look at before using the rows: cliffs between walkable squares (15 ft or more), lone squares of
## water or difficult ground (a speck the eye will read as a square), water bodies that came out rectangular, and an
## outdoor place left flat. `preview` draws the derived squares over the sketch for a look by eye.
## The command line (sketch_tool.gd) writes the rows into a location file.

## The layout drawing's colours and the legend character each lays (docs/reference/contracts/locations.md).
const KEY := {
	"#0000ff": "w",   # water
	"#006400": "#",   # woods (trees)
	"#808080": "#",   # rock
	"#ff0000": "#",   # a building's walls
	"#8b4513": "~",   # difficult ground (brambles, mud, scree)
	"#ffff00": "=",   # low cover (a fence, a hedge, a woodpile)
	"#000000": " ",   # void (a drop with no bottom, outside the place)
}
## How far (RGB, 0 to 1.73) a pixel may be from a key colour and still be it; antialiased edges between are open ground.
const TOLERANCE := 0.3
## What the height painting's white stands for, unless asked (feet above its black).
const TOP_FT := 30
const STEP_FT := 5
const DIGITS := "0123456789abcdefghijklmnopqrstuvwxyz"
## Where the rules call a step between neighbours a cliff (feet).
const CLIFF_FT := 15


## The rows and elevation rows for a place `size` squares across and down, from its height painting and layout drawing
## (either may be null: flat ground, or all open). `opts`: top_ft, key ({"#rrggbb": char}), tolerance.
## Returns {"rows": Array[String], "elevation": Array[String], "report": Dictionary}.
static func lay(height: Image, layout: Image, size: Vector2i, opts: Dictionary = {}) -> Dictionary:
	var key := _key(opts.get("key", KEY) as Dictionary)
	var tol := float(opts.get("tolerance", TOLERANCE))
	var top := float(opts.get("top_ft", TOP_FT))
	var hi := _prepared(height)
	var li := _prepared(layout)
	var rows: Array[String] = []
	var elevation: Array[String] = []
	for z in size.y:
		var row := ""
		var erow := ""
		for x in size.x:
			var ch := _feature(li, x, z, size, key, tol)
			row += ch
			var ft := _height_ft(hi, x, z, size, top, ch == "w")
			erow += DIGITS[clampi(roundi(ft / STEP_FT), 0, DIGITS.length() - 1)]
		rows.append(row)
		elevation.append(erow)
	return {"rows": rows, "elevation": elevation, "report": report(rows, elevation)}


## What to look at in derived rows (see the class notes): {"counts", "cliffs", "lone", "square_water", "flat", "warnings"}.
static func report(rows: Array[String], elevation: Array[String]) -> Dictionary:
	var w := rows[0].length() if not rows.is_empty() else 0
	var d := rows.size()
	var counts := {}
	var cliffs: Array = []
	var lone: Array = []
	var heights := {}
	for z in d:
		for x in w:
			var ch := rows[z][x]
			counts[ch] = int(counts.get(ch, 0)) + 1
			heights[elevation[z][x]] = true
			if ch in ["w", "~"]:
				var alone := true
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := Vector2i(x, z) + o
					if n.x >= 0 and n.y >= 0 and n.x < w and n.y < d and rows[n.y][n.x] == ch:
						alone = false
				if alone:
					lone.append([x, z, ch])
			if _walkable(ch):
				for o: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var n := Vector2i(x, z) + o
					if n.x < w and n.y < d and _walkable(rows[n.y][n.x]):
						var ft := absi(DIGITS.find(elevation[z][x]) - DIGITS.find(elevation[n.y][n.x])) * STEP_FT
						if ft >= CLIFF_FT:
							cliffs.append([x, z, n.x, n.y, ft])
	var square_water := _rectangles(rows, "w")
	var warnings: Array[String] = []
	if not cliffs.is_empty():
		warnings.append("%d cliffs (15 ft or more) between walkable squares: soften the height painting there, or mean them" % cliffs.size())
	if not lone.is_empty():
		warnings.append("%d lone squares of water or difficult ground: widen them or paint them out" % lone.size())
	if not square_water.is_empty():
		warnings.append("%d bodies of water came out rectangular: round their shores in the layout" % square_water.size())
	if heights.size() <= 1:
		warnings.append("the place is flat: give it some height (principles 5.1)")
	return {"counts": counts, "cliffs": cliffs, "lone": lone, "square_water": square_water, "flat": heights.size() <= 1,
		"warnings": warnings}


## The derived squares drawn over the layout, `px` pixels a square: each square in its feature's colour (open ground
## green-grey), lighter the higher it stands, with the grid's lines, so an author sees what the land became.
static func preview(rows: Array[String], elevation: Array[String], px: int = 16) -> Image:
	var w := rows[0].length()
	var d := rows.size()
	var img := Image.create(w * px, d * px, false, Image.FORMAT_RGB8)
	var colours := {"w": Color("#2a5db0"), "#": Color("#2f4a2c"), "~": Color("#8b5a2b"), "=": Color("#c9b03a"),
		" ": Color.BLACK, ".": Color("#7f8f6a")}
	for z in d:
		for x in w:
			var ch := rows[z][x]
			var c := colours.get(ch, Color("#7f8f6a")) as Color
			var lift := float(DIGITS.find(elevation[z][x])) / 12.0
			c = c.lerp(Color.WHITE, clampf(lift, 0.0, 0.6))
			img.fill_rect(Rect2i(x * px, z * px, px, px), c)
			img.fill_rect(Rect2i(x * px, z * px, px, 1), Color(0, 0, 0, 1))
			img.fill_rect(Rect2i(x * px, z * px, 1, px), Color(0, 0, 0, 1))
	return img


static func _walkable(ch: String) -> bool:
	return ch in [".", "~", "="]


static func _key(raw: Dictionary) -> Array:
	var out: Array = []
	for hex: String in raw:
		out.append([Color(hex), str(raw[hex])])
	return out


static func _prepared(img: Image) -> Image:
	if img == null:
		return null
	var out := img.duplicate() as Image
	if out.is_compressed():
		out.decompress()
	out.convert(Image.FORMAT_RGBA8)
	return out


## The feature covering most of square (x, z): the key character with the most pixels, open ground on a tie or none.
static func _feature(img: Image, x: int, z: int, size: Vector2i, key: Array, tol: float) -> String:
	if img == null:
		return "."
	var tally := {".": 0}
	for p: Vector2i in _pixels(img, x, z, size):
		var c := img.get_pixel(p.x, p.y)
		var ch := "."
		if c.a >= 0.5:
			var best := tol
			for k: Array in key:
				var kc := k[0] as Color
				var dist := Vector3(c.r - kc.r, c.g - kc.g, c.b - kc.b).length()
				if dist < best:
					best = dist
					ch = str(k[1])
		tally[ch] = int(tally.get(ch, 0)) + 1
	var pick := "."
	for ch: String in tally:
		if int(tally[ch]) > int(tally[pick]):
			pick = ch
	return pick


## The square's ground height in feet: the mean of the painting over it (water: the lowest, its bed).
static func _height_ft(img: Image, x: int, z: int, size: Vector2i, top: float, water: bool) -> float:
	if img == null:
		return 0.0
	var total := 0.0
	var low := INF
	var n := 0
	for p: Vector2i in _pixels(img, x, z, size):
		var v := img.get_pixel(p.x, p.y).get_luminance()
		total += v
		low = minf(low, v)
		n += 1
	if n == 0:
		return 0.0
	return (low if water else total / n) * top


## The pixels of square (x, z) once the picture is stretched over the place: a sample grid of at most 8 x 8 across its
## middle 80% (an edge that runs along a square's side leaves it to its neighbour).
static func _pixels(img: Image, x: int, z: int, size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var sx := float(img.get_width()) / size.x
	var sz := float(img.get_height()) / size.y
	var n := clampi(int(minf(sx, sz)), 1, 8)
	for j in n:
		for i in n:
			var u := (x + 0.1 + 0.8 * (i + 0.5) / n) * sx
			var v := (z + 0.1 + 0.8 * (j + 0.5) / n) * sz
			out.append(Vector2i(clampi(int(u), 0, img.get_width() - 1), clampi(int(v), 0, img.get_height() - 1)))
	return out


## Bodies of `ch` (4-connected) that fill their bounding box: [[x0, z0, x1, z1], ...]; a single square is lone instead.
static func _rectangles(rows: Array[String], ch: String) -> Array:
	var w := rows[0].length()
	var d := rows.size()
	var seen := {}
	var out: Array = []
	for z in d:
		for x in w:
			if rows[z][x] != ch or seen.has(Vector2i(x, z)):
				continue
			var stack: Array[Vector2i] = [Vector2i(x, z)]
			seen[Vector2i(x, z)] = true
			var lo := Vector2i(x, z)
			var hi := Vector2i(x, z)
			var count := 0
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				count += 1
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := c + o
					if n.x >= 0 and n.y >= 0 and n.x < w and n.y < d and rows[n.y][n.x] == ch and not seen.has(n):
						seen[n] = true
						stack.append(n)
			var box := (hi.x - lo.x + 1) * (hi.y - lo.y + 1)
			if count > 1 and count == box and hi.x > lo.x and hi.y > lo.y:
				out.append([lo.x, lo.y, hi.x, hi.y])
	return out
