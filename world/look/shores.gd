class_name Shores
extends RefCounted
## Natural shores in the Modern look (the vault's Natural Maps Plan, N3; owner 2026-10-19: "we don't need to draw our real
## world maps as a battle grid"). Each water square of the map was a 1 x 1 box at -0.18 beside ground at 0, so a pond was
## a square cut out of the land with a kerb round it and a lake a staircase. Here the shore is a smooth, wandering
## contour: the signed distance from the water squares' outline, blurred so convex corners round off, moved about by noise
## seeded by the place and kept within MAX_SHIFT of the grid line (so a token in the middle of a walkable square stays
## well clear of the water, and the land never reaches further than about half a square out over a water square, nor the
## water further than a quarter in over a walkable one). The
## ground (GroundRelief's skin) is lowered along it, a short bank on the land side and a shelf under the water, so the
## water plane, which stays at the board's own level, meets the ground where the contour says; the board's water boxes
## stay under the water squares and a skirt of water goes under the walkable squares beside them, for the shore to dip
## into. The water shader's shore foam and depth follow the contour (the mask). Cosmetic only: the rules grid never sees
## any of it; water squares stay water and walkable ones walkable. The Classic look is frozen and keeps its squares.
##
## Water on raised ground (a creek running down a hillside, a tarn up on a shelf; 2026-10-29)
## lies at its own squares' height, not the board's: every square of the field takes the level of the nearest water
## (a water square its own floor), smoothed so a stream slopes down the hill instead of stepping down it square by
## square, and the bank, the shelf, the skirt and the water's surface follow that level. Where all the water is at the
## board's own level (every Curse of Strahd place) it is drawn exactly as before.
##
## Built for speed (a place is built on every arrival): the field is worked out once per place on flat arrays over the
## water's bounding box and kept, like GroundRelief's.

## Fine cells per square (a third of a square: the ground it lowers has a point every half), and squares of land round the water the field covers.
const RES := 3
const PAD := 2
## The board's water level (AtmosphereLand.WATER_Y), where the contour lies.
const WATER_Y := -0.13
## How far the contour may lie from the grid line: out over a water square (the land reaches out, where the water is wide
## enough to spare it) and in over a walkable square (the water comes in; a square's middle stays dry besides, MIDDLE_DRY).
const MAX_SHIFT := 0.45
const MAX_IN := 0.28
## How far inland the bank begins (squares), how steeply it meets the water (height per square at the contour) and how
## deep the shelf runs under the water.
const BANK := 0.22
const BANK_SLOPE := 0.9
const SHELF := 0.45
## Banks (ground beside the water, in world units above the floor): up to LOW_BANK a bank is met at the waterline (a short
## slope); a higher one is a pit's rim (Krezk's pool is a 5 ft pit): the water's edge moves out into the water squares by
## PIT_REACH a unit of height above PIT_RISE (at most PIT_MAX) and the bank slopes down over them, from half the rim's height
## at the grid line (what natural ground makes of it there) to the water, so a rim is a rounded slope and not a wall. Rims
## higher than REACHABLE are cliffs (Natural Maps plan N6) and keep the board's own face.
const LOW_BANK := 0.35
const PIT_RISE := 0.3
const PIT_REACH := 0.65
const PIT_MAX := 0.8
const PIT_BLEND := 0.25
const REACHABLE := 2.05
## How dry the middle of a walkable square stays (the contour is at least this far from it), and how fast the water may
## come on past 0.2 from the middle.
const MIDDLE_DRY := -0.2
const MIDDLE_SLOPE := 2.4
## The blur that rounds corners (cells either side, twice) and the wander's size.
const BLUR := 1
const WANDER := 0.42
## Set by art QA tools only, to shoot a place as it was before (tools/capture/natural_audit.gd NA_NO_SHORES).
static var off := false
## Fields built on earlier visits, by place and board shape (a place comes out the same every time); the newest few.
static var _kept: Dictionary = {}
static var _kept_order: Array[String] = []

var board: ArenaBoard
## The squares the field covers: first square and size, and its fine cells across and down.
var _x0 := 0
var _z0 := 0
var _sw := 0
var _sd := 0
var _cw := 0
var _cd := 0
## The signed distance (squares) from the contour at each fine cell's middle, positive over the water.
var _dist := PackedFloat32Array()
## The height of the bank beside each fine cell (a water square takes the highest of its neighbours') and how far its
## shore is moved out into the water by it.
var _bank := PackedFloat32Array()
var _shift := PackedFloat32Array()
## The water squares the ground draws (land may reach out over them), and the walkable squares beside water (the water
## goes under them).
var _zone_water: Dictionary = {}
var _zone_land: Dictionary = {}
var _mask: ImageTexture = null
## The water's level (world units above the board's own) at each square of the field (the nearest water square's floor)
## and at each fine cell (smoothed between squares), and whether any of it is off the board's own level.
var _lev := PackedFloat32Array()
var _level := PackedFloat32Array()
var _sloped := false
## The water squares the field covers.
var _wet: Dictionary = {}
## The waterfalls (falls), and the flow map made from the levels (flow_map).
var _falls: Array[Dictionary] = []
var _flow_tex: ImageTexture = null
## How many times the squares' levels are smoothed (a 3 x 3 average each time): the stream's slope spreads over about
## this many squares either side of a step.
const LEVEL_BLUR := 2
## A drop between neighbouring water squares of this many units (10 ft) or more is a waterfall: the levels either side
## aren't smoothed into each other, and a sheet of falling water pours over the lip (Waterfall).
const FALL_STEP := 2.0


## Whether the Modern look draws natural shores (not Classic, and not for a QA shot of the places as they were).
static func on() -> bool:
	return not off and Look.modern()


## The shore of the water squares of `board_`, given the squares the shaped ground draws (`skin`, and the ones of them
## it keeps `flat`); null where there is no water, or in the Classic look.
static func build(board_: ArenaBoard, skin: Dictionary, flat: Dictionary) -> Shores:
	if not on():
		return null
	var g := board_.grid
	var lo := Vector2i(g.width, g.depth)
	var hi := Vector2i(-1, -1)
	for z in g.depth:
		for x in g.width:
			if g.has_flag(Vector2i(x, z), CombatGrid.WATER):
				lo = Vector2i(mini(lo.x, x), mini(lo.y, z))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, z))
	if hi.x < 0:
		return null
	var key := "%s|%dx%d|%d|%d" % [board_.place, g.width, g.depth, skin.size(), flat.size()]
	if _kept.has(key):
		var k := _kept[key] as Shores
		var again := Shores.new()
		again.board = board_
		again._x0 = k._x0
		again._z0 = k._z0
		again._sw = k._sw
		again._sd = k._sd
		again._cw = k._cw
		again._cd = k._cd
		again._dist = k._dist
		again._bank = k._bank
		again._shift = k._shift
		again._zone_water = k._zone_water
		again._zone_land = k._zone_land
		again._mask = k._mask
		again._lev = k._lev
		again._level = k._level
		again._sloped = k._sloped
		again._wet = k._wet
		again._falls = k._falls
		again._flow_tex = k._flow_tex
		return again
	var s := Shores.new()
	s.board = board_
	s._x0 = maxi(lo.x - PAD, 0)
	s._z0 = maxi(lo.y - PAD, 0)
	s._sw = mini(hi.x + PAD + 1, g.width) - s._x0
	s._sd = mini(hi.y + PAD + 1, g.depth) - s._z0
	s._cw = s._sw * RES
	s._cd = s._sd * RES
	s._levels()
	s._zones(skin)
	s._field(skin, flat)
	_kept[key] = s
	_kept_order.append(key)
	while _kept_order.size() > AtmosphereLand.KEEP:
		_kept.erase(_kept_order.pop_front())
	return s


## Whether a shore can meet square `c`: its ground is not a cliff above the water (Natural Maps plan N6).
func _near(c: Vector2i) -> bool:
	return absf(board.floor_y(c) - _lev_of(c)) <= REACHABLE


## The level of the water nearest each square of the field (a water square's own floor; 8 ways, the lowest on a tie), and
## the fine cells' levels, smoothed (_lev, _level, _sloped).
func _levels() -> void:
	var g := board.grid
	var count := _sw * _sd
	_lev.resize(count)
	var steps := PackedInt32Array()
	steps.resize(count)
	steps.fill(1 << 20)
	var front: Array[Vector2i] = []
	for sz in _sd:
		for sx in _sw:
			var c := Vector2i(_x0 + sx, _z0 + sz)
			if g.has_flag(c, CombatGrid.WATER):
				var k := sz * _sw + sx
				_lev[k] = g.height(c) / float(CombatGrid.FEET)
				_wet[c] = true
				steps[k] = 0
				front.append(Vector2i(sx, sz))
				_sloped = _sloped or not is_zero_approx(_lev[k])
	while not front.is_empty():
		var next: Array[Vector2i] = []
		for at: Vector2i in front:
			var k := at.y * _sw + at.x
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx := at.x + dx
					var nz := at.y + dz
					if nx < 0 or nz < 0 or nx >= _sw or nz >= _sd:
						continue
					var nk := nz * _sw + nx
					if steps[nk] > steps[k] + 1:
						steps[nk] = steps[k] + 1
						_lev[nk] = _lev[k]
						next.append(Vector2i(nx, nz))
					elif steps[nk] == steps[k] + 1:
						_lev[nk] = minf(_lev[nk], _lev[k])
		front = next
	_level.resize(_cw * _cd)
	if not _sloped:
		return   # (all zero: the board's own level, as before)
	_find_falls()
	var soft := _lev.duplicate()
	for _pass in LEVEL_BLUR:
		var out := soft.duplicate()
		for sz in _sd:
			for sx in _sw:
				var sum := 0.0
				var n := 0
				var own := _lev[sz * _sw + sx]
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var nx := sx + dx
						var nz := sz + dz
						if nx >= 0 and nz >= 0 and nx < _sw and nz < _sd and absf(_lev[nz * _sw + nx] - own) < FALL_STEP:
							sum += soft[nz * _sw + nx]
							n += 1
				out[sz * _sw + sx] = sum / n
		soft = out
	for j in _cd:
		for i in _cw:
			var fx := (i + 0.5) / RES - 0.5
			var fz := (j + 0.5) / RES - 0.5
			var x0 := clampi(floori(fx), 0, _sw - 1)
			var z0 := clampi(floori(fz), 0, _sd - 1)
			var x1 := mini(x0 + 1, _sw - 1)
			var z1 := mini(z0 + 1, _sd - 1)
			var ax := clampf(fx - x0, 0.0, 1.0)
			var az := clampf(fz - z0, 0.0, 1.0)
			_level[j * _cw + i] = lerpf(lerpf(soft[z0 * _sw + x0], soft[z0 * _sw + x1], ax),
				lerpf(soft[z1 * _sw + x0], soft[z1 * _sw + x1], ax), az)


func _lev_of(c: Vector2i) -> float:
	var sx := c.x - _x0
	var sz := c.y - _z0
	if sx < 0 or sz < 0 or sx >= _sw or sz >= _sd:
		return 0.0
	return _lev[sz * _sw + sx]


## The water's surface height at a point of the map (world units): the board's water level, raised to the water's own
## level where it lies on raised ground.
func water_y(p: Vector2) -> float:
	return WATER_Y + (_sample(_level, p, 0.0) if _sloped else 0.0)


## Whether any of the place's water lies off the board's own level (a creek down a hillside).
func sloped() -> bool:
	return _sloped


## Which way and how fast the water runs at each third of a square of the map, for the water shader (lit_water's
## flow_map): red and green the way downhill (0.5 is none), blue the speed (a pool barely moves, a steep run races),
## alpha the white water (steep runs and the foot of a fall). Null where the water is level: the mood's own `flow` drifts it.
func flow_map(width: int, depth: int) -> ImageTexture:
	if not _sloped:
		return null
	if _flow_tex != null:
		return _flow_tex
	var mw := width * RES
	var md := depth * RES
	var img := Image.create(mw, md, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.0, 0.0))
	for j in _cd:
		for i in _cw:
			var gi := _x0 * RES + i
			var gj := _z0 * RES + j
			if gi >= mw or gj >= md:
				continue
			var at := flow_at(Vector2(_x0 + (i + 0.5) / RES, _z0 + (j + 0.5) / RES))
			var dir := at[0] as Vector2
			img.set_pixel(gi, gj, Color(dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5, float(at[1]), float(at[2])))
	_flow_tex = ImageTexture.create_from_image(img)
	return _flow_tex


## The water's run at a point: [the way downhill (unit, or zero on level water), speed 0 to 1, white water 0 to 1].
func flow_at(p: Vector2) -> Array:
	var e := 1.0 / RES
	var g := Vector2(_sample(_level, p + Vector2(e, 0), 0.0) - _sample(_level, p - Vector2(e, 0), 0.0),
		_sample(_level, p + Vector2(0, e), 0.0) - _sample(_level, p - Vector2(0, e), 0.0)) / (2.0 * e)
	var slope := g.length()
	var dir := -g / slope if slope > 0.02 else Vector2.ZERO
	var speed := clampf(0.2 + slope * 0.9, 0.0, 1.0) if slope > 0.02 else 0.08
	var white := smoothstep(0.45, 1.1, slope)
	for f: Dictionary in _falls:
		var foot := f["foot"] as Vector2
		white = maxf(white, 1.0 - smoothstep(0.2, 0.9, p.distance_to(foot)))
	return [dir, speed, white]


## Where the water drops FALL_STEP or more between neighbouring water squares: {"lip": Vector2 (the edge's middle),
## "facing": Vector2i (downhill), "top": float, "drop": float, "foot": Vector2}.
func falls() -> Array[Dictionary]:
	return _falls


func _find_falls() -> void:
	_falls.clear()
	for c: Vector2i in _wet:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n := c + d
			if not _wet.has(n):
				continue
			var drop := _lev_of(c) - _lev_of(n)
			if drop < FALL_STEP:
				continue
			var lip := Vector2(c.x + 0.5, c.y + 0.5) + Vector2(d) * 0.5
			_falls.append({"lip": lip, "facing": d, "top": WATER_Y + _lev_of(c), "drop": drop,
				"foot": lip + Vector2(d) * 0.35})


## The water squares land may reach over (any beside a square the ground draws) and the drawn walkable squares water may
## reach under.
func _zones(skin: Dictionary) -> void:
	var g := board.grid
	for z in range(_z0, _z0 + _sd):
		for x in range(_x0, _x0 + _sw):
			var c := Vector2i(x, z)
			var wet := g.has_flag(c, CombatGrid.WATER)
			if not wet and not (skin.has(c) and _near(c)):
				continue
			for d: Vector2i in CombatGrid.DIRS:
				var n := c + d
				if not g.in_bounds(n):
					continue
				if wet and skin.has(n) and _near(n):
					_zone_water[c] = true
					break
				if not wet and g.has_flag(n, CombatGrid.WATER):
					_zone_land[c] = true
					break


## The contour's signed distance at every fine cell.
func _field(skin: Dictionary, flat: Dictionary) -> void:
	var g := board.grid
	var n := _cw * _cd
	# Each square once: water (1), a square the water may not reach into (2: not drawn, drawn flat or raised), the rest 0.
	var square := PackedByteArray()
	square.resize(_sw * _sd)
	for sz in _sd:
		for sx in _sw:
			var c := Vector2i(_x0 + sx, _z0 + sz)
			if g.has_flag(c, CombatGrid.WATER):
				square[sz * _sw + sx] = 1
			elif not skin.has(c) or flat.has(c) or not _near(c):
				square[sz * _sw + sx] = 2
	# The bank's height at each square: ground beside water is its own floor; a water square takes its highest neighbour's.
	var rise := PackedFloat32Array()
	rise.resize(_sw * _sd)
	for sz in _sd:
		for sx in _sw:
			if square[sz * _sw + sx] != 1:
				rise[sz * _sw + sx] = maxf(board.floor_y(Vector2i(_x0 + sx, _z0 + sz)) - _lev[sz * _sw + sx], 0.0)
	var rim := rise.duplicate()
	for sz in _sd:
		for sx in _sw:
			if square[sz * _sw + sx] != 1:
				continue
			var best := 0.0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx := sx + dx
					var nz := sz + dz
					if nx >= 0 and nz >= 0 and nx < _sw and nz < _sd and square[nz * _sw + nx] != 1:
						best = maxf(best, rise[nz * _sw + nx])
			rim[sz * _sw + sx] = best
	var water := PackedByteArray()
	water.resize(n)
	var dry := PackedByteArray()
	dry.resize(n)
	for j in _cd:
		var row := (j / RES) * _sw
		for i in _cw:
			var kind := square[row + i / RES]
			if kind == 1:
				water[j * _cw + i] = 1
			elif kind == 2:
				dry[j * _cw + i] = 1
	# Distance (cells) from every water cell to the nearest land one, and from every land cell to the nearest water one,
	# each from the cell's middle to the other's, so the outline lies half a cell from either: signed, in squares.
	var to_land := _chamfer(water, 0)
	var to_water := _chamfer(water, 1)
	var sd := PackedFloat32Array()
	sd.resize(n)
	for k in n:
		sd[k] = clampf((to_land[k] - 0.5) / RES if water[k] == 1 else -(to_water[k] - 0.5) / RES, -8.0, 8.0)
	# Blurred so convex corners round off, then moved about by noise, and kept within MAX_SHIFT of the grid line.
	var soft := _blur(_blur(sd, 1), 1)
	# How wide the water is about each cell (the deepest point within three quarters of a square): the land only reaches
	# out over water that has the width to spare, so a one-square stream keeps its banks.
	var wet := PackedFloat32Array()
	wet.resize(n)
	for k in n:
		wet[k] = maxf(sd[k], 0.0)
	var peak := _widest(wet)
	var seed_at := _seed_of(board.place)
	_dist.resize(n)
	_bank.resize(n)
	_shift.resize(n)
	for j in _cd:
		for i in _cw:
			var k := j * _cw + i
			# The bank's height here, between the squares' middles, and how far it moves the shore out.
			var fx := (i + 0.5) / RES - 0.5
			var fz := (j + 0.5) / RES - 0.5
			var x0 := clampi(floori(fx), 0, _sw - 1)
			var z0 := clampi(floori(fz), 0, _sd - 1)
			var x1 := mini(x0 + 1, _sw - 1)
			var z1 := mini(z0 + 1, _sd - 1)
			var ax := clampf(fx - x0, 0.0, 1.0)
			var az := clampf(fz - z0, 0.0, 1.0)
			var bank := lerpf(lerpf(rim[z0 * _sw + x0], rim[z0 * _sw + x1], ax), lerpf(rim[z1 * _sw + x0], rim[z1 * _sw + x1], ax), az)
			var shift := clampf((bank - PIT_RISE) * PIT_REACH, 0.0, PIT_MAX)
			_bank[k] = bank
			_shift[k] = shift
			var near := sd[k]
			if near > 1.0 or near < -1.0:
				_dist[k] = soft[k] - shift   # (well away from the edge: no wander to work out)
				continue
			var p := Vector2(_x0 + (i + 0.5) / RES, _z0 + (j + 0.5) / RES)
			var nz := noise(p * 0.5 + seed_at) * 0.65 + noise(p * 1.5 + seed_at + Vector2(5.3, 1.7)) * 0.35
			var wander := clampf((nz - 0.5) * 2.6, -1.0, 1.0) * WANDER
			var out := MAX_SHIFT * smoothstep(0.45, 0.85, peak[k])
			var d := clampf(soft[k] + wander, near - out, near + MAX_IN)
			if dry[k] == 1:
				d = minf(d, near)
			elif water[k] == 0:
				# The middle of a walkable square stays well clear of the water (a one-square spit has water either side):
				# the further a point is from its square's middle, the nearer the water may come.
				var from_mid := p.distance_to(Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5))
				d = minf(d, MIDDLE_DRY + MIDDLE_SLOPE * maxf(from_mid - 0.2, 0.0))
			_dist[k] = d - shift


## Distance in cells from each cell to the nearest cell holding `target` (8 ways, 1 and 1.414 a step; 99 where none).
func _chamfer(a: PackedByteArray, target: int) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(a.size())
	for k in a.size():
		f[k] = 0.0 if a[k] == target else 99.0
	var diag := 1.41421
	for j in _cd:
		for i in _cw:
			var k := j * _cw + i
			var v := f[k]
			if i > 0:
				v = minf(v, f[k - 1] + 1.0)
			if j > 0:
				v = minf(v, f[k - _cw] + 1.0)
				if i > 0:
					v = minf(v, f[k - _cw - 1] + diag)
				if i < _cw - 1:
					v = minf(v, f[k - _cw + 1] + diag)
			f[k] = v
	for j in range(_cd - 1, -1, -1):
		for i in range(_cw - 1, -1, -1):
			var k := j * _cw + i
			var v := f[k]
			if i < _cw - 1:
				v = minf(v, f[k + 1] + 1.0)
			if j < _cd - 1:
				v = minf(v, f[k + _cw] + 1.0)
				if i < _cw - 1:
					v = minf(v, f[k + _cw + 1] + diag)
				if i > 0:
					v = minf(v, f[k + _cw - 1] + diag)
			f[k] = v
	return f


## The largest value of `a` within BLUR + 1 cells of each cell (along x then z).
func _widest(a: PackedFloat32Array) -> PackedFloat32Array:
	var r := BLUR + 1
	var tmp := PackedFloat32Array()
	tmp.resize(a.size())
	for j in _cd:
		var row := j * _cw
		for i in _cw:
			var best := 0.0
			for o in range(-r, r + 1):
				best = maxf(best, a[row + clampi(i + o, 0, _cw - 1)])
			tmp[row + i] = best
	var out := PackedFloat32Array()
	out.resize(a.size())
	for j in _cd:
		for i in _cw:
			var best := 0.0
			for o in range(-r, r + 1):
				best = maxf(best, tmp[clampi(j + o, 0, _cd - 1) * _cw + i])
			out[j * _cw + i] = best
	return out


## A box blur of `a` (BLUR cells either side, along x then z), the edges holding their last value.
func _blur(a: PackedFloat32Array, _pass: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(a.size())
	var width := float(2 * BLUR + 1)
	for j in _cd:
		var row := j * _cw
		for i in _cw:
			var sum := 0.0
			for o in range(-BLUR, BLUR + 1):
				sum += a[row + clampi(i + o, 0, _cw - 1)]
			tmp[row + i] = sum / width
	var out := PackedFloat32Array()
	out.resize(a.size())
	for j in _cd:
		for i in _cw:
			var sum := 0.0
			for o in range(-BLUR, BLUR + 1):
				sum += tmp[clampi(j + o, 0, _cd - 1) * _cw + i]
			out[j * _cw + i] = sum / width
	return out


## Value noise 0..1, smooth over a square or so.
static func noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x), lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x), u.y)


static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.x * 127.1 + p.y * 311.7) * 43758.5453, 1.0)


## Where a place's noise starts, so no two places wander alike (shapes come from noise seeded by the place).
static func _seed_of(place: String) -> Vector2:
	var h := absi(hash(place))
	return Vector2(float(h % 1013), float(h / 1013 % 1013)) * 0.173


# --- What the rest of the look asks ---------------------------------------------------------------------------------

## The signed distance (squares) from the shore's contour at a point of the map, positive over the water, or -8 off the
## field (land well away from any water).
func distance_at(p: Vector2) -> float:
	return _sample(_dist, p, -8.0)


## An array of the field's fine cells read at a point of the map (bilinear between the cells' middles), `outside` off it.
func _sample(a: PackedFloat32Array, p: Vector2, outside: float) -> float:
	var fi := (p.x - _x0) * RES - 0.5
	var fj := (p.y - _z0) * RES - 0.5
	if fi < -1.0 or fj < -1.0 or fi > _cw or fj > _cd:
		return outside
	var i := clampi(floori(fi), 0, _cw - 2)
	var j := clampi(floori(fj), 0, _cd - 2)
	var fx := clampf(fi - i, 0.0, 1.0)
	var fz := clampf(fj - j, 0.0, 1.0)
	var k := j * _cw + i
	return lerpf(lerpf(a[k], a[k + 1], fx), lerpf(a[k + _cw], a[k + _cw + 1], fx), fz)


## The ground's height over a point where the shore's distance is `d`, for ground at `ground` there (absolute): down a
## short bank (`width` squares) to the water's level at the contour with the bank's slope (a cubic from the ground's own
## height, so a raised bank rounds off into the water instead of standing as a wall), then a shelf under the water.
static func shelf(d: float, ground: float = 0.0, width: float = BANK, water: float = WATER_Y) -> float:
	if d <= -width:
		return ground
	if d <= 0.0:
		var t := (d + width) / width
		return ground + (water - ground) * (3.0 * t * t - 2.0 * t * t * t) - BANK_SLOPE * width * (t * t * t - t * t)
	return water - SHELF * (1.0 - exp(-d * BANK_SLOPE / SHELF))


## Whether a point of the map is under the water (past the contour).
func is_wet(p: Vector2) -> bool:
	return distance_at(p) > 0.0


## The water squares the ground draws (land may reach out over them).
func water_squares() -> Dictionary:
	return _zone_water


## Lowers ground height `h` (relative to the natural ground's `base` at `p`, 0 where it is level) to the shore's: not at
## all on dry ground, a short bank to the water and a shelf under it beside low ground, and where the bank is a pit's rim a
## long slope from half its height at the grid line down over the water squares (the natural ground's own slope there is
## replaced; inland of the grid line it blends in over PIT_BLEND).
func lower(h: float, p: Vector2, base: float = 0.0) -> float:
	var d := distance_at(p)
	var bank := _sample(_bank, p, 0.0)
	var lev := _sample(_level, p, 0.0) if _sloped else 0.0
	if bank > PIT_RISE:
		var w := maxf(_sample(_shift, p, 0.0), 0.1)
		if d <= -w - PIT_BLEND:
			return h
		return lerpf(h, shelf(d, lev + 0.5 * bank, w, WATER_Y + lev) - base, smoothstep(-w - PIT_BLEND, -w, d))
	if d <= -BANK:
		return h
	return minf(h, shelf(d, base + h, BANK, WATER_Y + lev) - base)


## Whether the shore lowers or raises the ground at a point (for tests of the skin's own shape: it is meant to).
func touches(p: Vector2) -> bool:
	return distance_at(p) > -(PIT_MAX + PIT_BLEND + 0.1)


## Draws what the shore needs besides the ground: the water's mask (the foam and the depth colour follow the contour) and
## a skirt of water under the walkable squares beside it, at the board's water level, for the bank to dip into. `parent`
## is the surround; `water` the water's material (the board's own plain one where the mood has none); `on` the board
## being dressed (a shore kept from an earlier visit was worked out on that visit's board).
func dress(parent: Node3D, water: Material, on: ArenaBoard = null) -> void:
	var w := water
	if w == null:
		w = Look.cel_textured("wild/water")
	if water is ShaderMaterial:
		(water as ShaderMaterial).set_shader_parameter("water_mask", mask())
	if _sloped and w != null:
		_dress_stream(parent, w, on if on != null else board)
		return
	if _zone_land.is_empty() or w == null:
		return
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for c: Vector2i in _zone_land:
		var b := verts.size()
		verts.append(Vector3(c.x, WATER_Y, c.y))
		verts.append(Vector3(c.x + 1, WATER_Y, c.y))
		verts.append(Vector3(c.x, WATER_Y, c.y + 1))
		verts.append(Vector3(c.x + 1, WATER_Y, c.y + 1))
		for q in 4:
			normals.append(Vector3.UP)
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "ShoreWater"
	mi.mesh = mesh
	mi.material_override = w
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## The water shader's mask: a texel for a third of a square over the map, 0 on land and rising from a little over 0 at
## the contour to 1 some squares out into the water, as the old mask did from the water squares.
func mask() -> ImageTexture:
	if _mask != null:
		return _mask
	var g := board.grid
	var mw := g.width * RES
	var md := g.depth * RES
	var data := PackedByteArray()
	data.resize(mw * md)
	var x0 := _x0 * RES
	var z0 := _z0 * RES
	for j in md:
		var cj := j - z0
		if cj < 0 or cj >= _cd:
			continue
		for i in mw:
			var ci := i - x0
			if ci < 0 or ci >= _cw:
				continue
			var d := _dist[cj * _cw + ci]
			if d > -0.02:
				data[j * mw + i] = roundi(clampf(0.125 + d * 0.25, 0.0, 1.0) * 255.0)
	_mask = ImageTexture.create_from_image(Image.create_from_data(mw, md, false, Image.FORMAT_R8, data))
	return _mask


## Water off the board's level (a creek down a hillside): one surface over the water squares and the walkable squares
## beside them, a point every third of a square at the water's own smoothed level, so the stream runs down the slope
## between its banks. The board's flat water boxes (ArenaBoard._water) are hidden for it.
func _dress_stream(parent: Node3D, water: Material, on: ArenaBoard) -> void:
	var cover := {}
	for c: Vector2i in _zone_land:
		cover[c] = true
	for c: Vector2i in _wet:
		cover[c] = true
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	var step := 1.0 / RES
	for c: Vector2i in cover:
		for j in RES:
			for i in RES:
				var b := verts.size()
				for q in 4:
					var p := Vector2(c.x + (i + (q & 1)) * step, c.y + (j + (q >> 1)) * step)
					verts.append(Vector3(p.x, water_y(p), p.y))
					var dx := water_y(p + Vector2(step, 0)) - water_y(p - Vector2(step, 0))
					var dz := water_y(p + Vector2(0, step)) - water_y(p - Vector2(0, step))
					normals.append(Vector3(-dx, 2.0 * step, -dz).normalized())
				idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "StreamWater"
	mi.mesh = mesh
	mi.material_override = water
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if water is ShaderMaterial and (water as ShaderMaterial).shader == Atmosphere.LIT_WATER_SHADER:
		(water as ShaderMaterial).set_shader_parameter("flow_map", flow_map(on.grid.width, on.grid.depth))
		(water as ShaderMaterial).set_shader_parameter("use_flow_map", true)
	var colours := {}
	if water is ShaderMaterial:
		for k: String in ["deep", "foam"]:
			colours[k] = (water as ShaderMaterial).get_shader_parameter(k)
	for f: Dictionary in _falls:
		var facing := f["facing"] as Vector2i
		var lip := f["lip"] as Vector2
		var sheet := Waterfall.build({"at": [lip.x, lip.y], "height": float(f["top"]), "width": 0.95,
			"drop": float(f["drop"]), "facing": Waterfall.facing_of(facing), "lean": 0.25, "speed": 2.2}, {})
		if colours.get("deep") is Color:
			(sheet.material_override as ShaderMaterial).set_shader_parameter("deep", colours["deep"])
			(sheet.material_override as ShaderMaterial).set_shader_parameter("foam", colours["foam"])
		parent.add_child(sheet)
	for n: Node in on.get_children():
		if n.has_meta(&"water_cell"):
			(n as Node3D).visible = false
