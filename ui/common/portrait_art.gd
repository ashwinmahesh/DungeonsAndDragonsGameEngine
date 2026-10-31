class_name PortraitArt
extends RefCounted
## Which picture a portrait chip shows: the turn order, the party frames, the examine card and the journal's Bestiary.
## Until a game turns `photoreal` on (art/portrait_sets.json, the core's file with the game's merged over it: ArtPaths.json)
## a portrait is art/portraits/<art id>.png as it always was, and a creature without one shows an empty frame.
## With it on (a game with photographs of its creatures):
##   a monster:    art/portraits/monsters/<stat block id>.webp, then the creature's art id as a character
##   a character:  art/portraits/characters/<art id>.webp, then art/portraits/<art id>.webp
## and each step also takes a .png of the same name. The first that exists wins, so a game can add portraits one creature
## at a time and everything else keeps the picture it had. A creature with none shows a drawn silhouette in the frame
## (placeholder) instead of an empty one, and a portrait that isn't square (photographs may be 7:9) is cropped to a square
## in a chip, from the top so the face stays (square). The Bestiary shows its picture large beside the entry's words (large).
## The stat block id is the file name the monster's data has (data/monsters/<id>.json), not its sprite's art id, so the art
## names follow the bestiary and a named villain who wears another creature's sprite still has a portrait of its own.

const CONFIG := "art/portrait_sets.json"
const EXTS: Array[String] = ["webp", "png"]
## How much of a tall portrait's spare height is cut from its top when it goes into a square: the face is in the upper
## part, so most of what's cut is the chest and below.
const FACE_BIAS := 0.3
## The widest and the narrowest a large portrait gets, as a share of its width, whatever the picture's own shape.
const LARGE_TALL := 1.3
const LARGE_SHORT := 0.85

static var _config: Dictionary = {}
static var _read := false
static var _found: Dictionary = {}


## art/portrait_sets.json merged: the core's defaults, then the game's.
static func config() -> Dictionary:
	if not _read:
		_config = ArtPaths.json(CONFIG)
		_read = true
	return _config


## Tests and tools that change the config or add art start the lookups over.
static func reset() -> void:
	_config = {}
	_read = false
	_found.clear()


## Tests: lookups as if the merged file said `with` (reset() puts the real one back).
static func use(with: Dictionary) -> void:
	_config = with
	_read = true
	_found.clear()


static func photoreal() -> bool:
	return bool(config().get("photoreal", false))


static func _dir(key: String, fallback: String) -> String:
	return str(config().get(key, fallback)).trim_suffix("/")


## The Combat view's stat block id for `c` to look a monster's portrait up by, or "": none for the party, a guest (a story
## ally wears their own face) or a creature that borrows a hero's look (an echo).
static func monster_id_of(c: Combatant) -> String:
	if c.side in [&"party", &"guest"] or not c.creature is Monster or c.creature.id.begins_with("guest_"):
		return ""
	var data := (c.creature as Monster).data
	if str(data.get("look_of", "")) != "":
		return ""
	return str(data.get("id", ""))


## Where to look, best first (paths below res://, which ArtPaths.of resolves in the game and then the core).
static func rel_paths(art_id: String, monster_id: String = "") -> Array[String]:
	var out: Array[String] = []
	var real := photoreal()
	if real and monster_id != "":
		for ext in EXTS:
			out.append("%s/%s.%s" % [_dir("monster_dir", "art/portraits/monsters"), monster_id, ext])
	if art_id != "":
		if real:
			for ext in EXTS:
				out.append("%s/%s.%s" % [_dir("character_dir", "art/portraits/characters"), art_id, ext])
		for ext in (EXTS if real else (["png"] as Array[String])):
			out.append("art/portraits/%s.%s" % [art_id, ext])
	return out


## The best picture there is for that creature, or null.
static func texture(art_id: String, monster_id: String = "") -> Texture2D:
	var key := "%s|%s" % [monster_id, art_id]
	if _found.has(key):
		return _found[key] as Texture2D
	for rel in rel_paths(art_id, monster_id):
		var path := ArtPaths.of(rel)
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_found[key] = tex   # only a hit is remembered: art made later (a tool, a test) is still found
				return tex
	return null


static func texture_for(c: Combatant) -> Texture2D:
	return texture(CombatToken.portrait_id(c), monster_id_of(c))


## The square of a picture a chip shows: the picture itself if it's square or the game keeps portraits as they are,
## else the largest square from its top part (or the middle of a wide one).
static func square(tex: Texture2D) -> Texture2D:
	if tex == null or not photoreal():
		return tex
	var w := tex.get_width()
	var h := tex.get_height()
	if absi(w - h) <= 2:
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0.0, floorf(float(h - w) * FACE_BIAS), float(w), float(w)) if h > w \
		else Rect2(floorf(float(w - h) * 0.5), 0.0, float(h), float(h))
	return at


## What a chip of that size shows with no portrait: a head and shoulders in the frame's dark, not an empty hole.
static func placeholder(size: Vector2) -> Control:
	var d := UiParts.drawn(size, func(c: Control) -> void:
		var s := c.size
		var tint := Color(Look.color("pewter"), 0.5)
		c.draw_circle(Vector2(s.x * 0.5, s.y * 0.37), minf(s.x, s.y) * 0.17, tint)
		var pts := PackedVector2Array()
		for i in 25:
			var a := PI + PI * float(i) / 24.0
			pts.append(Vector2(s.x * (0.5 + 0.36 * cos(a)), s.y * (1.02 + 0.42 * sin(a))))
		c.draw_colored_polygon(pts, tint))
	d.name = "Placeholder"
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## Whether the Bestiary shows an entry's picture large beside its words.
static func large() -> bool:
	return photoreal()


## The size a large portrait is framed at for a picture (a square's, a tall one's, a wide one's, none's): `width` wide,
## its height following the picture's shape within LARGE_SHORT..LARGE_TALL of the width.
static func large_size(tex: Texture2D, width: float) -> Vector2:
	if tex == null or tex.get_width() <= 0:
		return Vector2(width, width)
	var share := clampf(float(tex.get_height()) / float(tex.get_width()), LARGE_SHORT, LARGE_TALL)
	return Vector2(width, roundf(width * share))
