class_name GameFeel
extends RefCounted
## Game feel a game turns on under data/campaign.json's "game_feel" (Visual Polish Plan E39-E41, after the AI methods
## report's FX1 and FX2). Every default leaves a fight as it was, so a game that names none plays the same:
##   hit_stop: frames (at 60 a second) the fight stops for when a blow lands, by its weight: {"light": 2, "medium": 4,
##     "heavy": 7, "crit": 9, "kill": 10}; a weight it doesn't name stops nothing. {} keeps the engine's one freeze on a
##     heavy hit (CombatImpact.FREEZE). A blow's weight is the share of its target's Hit Points it takes (weight()).
##   kick: how far (world units) a blow knocks the camera the way it travels, at full weight; it springs back.
##   flash: how white a struck figure flashes (0 to 1), for flash_seconds.
##   knockback: times the engine's recoil when a figure is struck (1 is as it was).
##   dip: a short slow beat on a critical hit or a killing blow: {"scale": 0.35, "seconds": 0.22}. {} for none.
##   impact_frame: frames the picture turns to ink and paper on a critical hit or a killing blow (0 for none);
##     impact_ink and impact_paper are palette names.
##   breath: times the engine's breathing on standing figures. sway: how far (world units) the top of a figure stirs
##     in the place's wind, its feet planted (0 for none).
##   spell_light and spell_reach: times the brightness and reach of the light every spell effect throws.
##   spell_shadows: a spell's brightest flash casts shadows.
##   shapes: drawn shapes (slash crescents, burst stars, ink splashes, speed lines) over blows and impacts, animated
##     on twos (shape_fps a second). The art comes from art/vfx/shapes/<kind>.png (the game's, else the engine's
##     procedural fallback); shape_size is times their size.
const DEFAULTS := {
	"hit_stop": {}, "kick": 0.0, "flash": 0.0, "flash_seconds": 0.12, "knockback": 1.0,
	"dip": {}, "impact_frame": 0, "impact_ink": "void", "impact_paper": "parchment",
	"breath": 1.0, "sway": 0.0,
	"spell_light": 1.0, "spell_reach": 1.0, "spell_shadows": false,
	"shapes": false, "shape_fps": 12.0, "shape_size": 1.0,
}
## The share of a target's Hit Points a blow takes from which it is medium and heavy (under medium it is light).
const MEDIUM_SHARE := 0.12
const HEAVY_SHARE := 0.3

## Tests and captures put their own settings in place (null reads the game's again).
static var _own: Variant = null
static var _cached: Dictionary = {}


## The settings: DEFAULTS under the game's own "game_feel", read once (use() to change them).
static func settings() -> Dictionary:
	if _cached.is_empty():
		_cached = DEFAULTS.duplicate(true)
		var own: Variant = _own if _own is Dictionary else Campaign.config().get("game_feel", {})
		if own is Dictionary:
			for k: String in own as Dictionary:
				if DEFAULTS.has(k):
					_cached[k] = (own as Dictionary)[k]
	return _cached


## Puts `cfg` in place of the game's "game_feel" (tests, captures); null goes back to the game's.
static func use(cfg: Variant) -> void:
	_own = cfg
	_cached = {}


static func num(key: String) -> float:
	return float(settings().get(key, DEFAULTS.get(key, 0.0)))


static func flag(key: String) -> bool:
	return bool(settings().get(key, false))


static func table(key: String) -> Dictionary:
	var v: Variant = settings().get(key, {})
	return v as Dictionary if v is Dictionary else {}


## A blow's weight: "kill" when it fells its target, "crit" for a critical hit, else "light", "medium" or "heavy" by
## the share of the target's Hit Points it takes.
static func weight(amount: int, max_hp: int, critical: bool, fells: bool) -> String:
	if fells:
		return "kill"
	if critical:
		return "crit"
	var share := float(amount) / float(maxi(1, max_hp))
	if share >= HEAVY_SHARE:
		return "heavy"
	return "medium" if share >= MEDIUM_SHARE else "light"


## How strong a weight is, 0 to 1 (the camera kick scales by it).
static func strength(w: String) -> float:
	return {"light": 0.35, "medium": 0.6, "heavy": 0.85, "crit": 1.0, "kill": 1.0}.get(w, 0.5)


## Real seconds the fight stops for a blow of weight `w`, 0 when the game names no stop for it. A kill or a critical hit
## that isn't in the table falls back to "heavy".
static func stop_seconds(w: String) -> float:
	var t := table("hit_stop")
	if t.is_empty():
		return 0.0
	var frames: Variant = t.get(w, t.get("heavy", 0) if w in ["crit", "kill"] else 0)
	return maxf(0.0, float(frames)) / 60.0


## Whether the game uses its own hit-stop table instead of the engine's one heavy freeze.
static func stops() -> bool:
	return not table("hit_stop").is_empty()


## The way a blow from `from` to `to` travels on the screen of `cam` (x right, y up), unit length; zero when it can't
## tell (no camera, or straight along the view).
static func screen_dir(cam: Camera3D, from: Vector3, to: Vector3) -> Vector2:
	if cam == null or from == Vector3.INF:
		return Vector2.ZERO
	var d := to - from
	var v := Vector2(d.dot(cam.global_basis.x), d.dot(cam.global_basis.y) + d.dot(-cam.global_basis.z) * 0.35)
	return v.normalized() if v.length() > 0.01 else Vector2.ZERO
