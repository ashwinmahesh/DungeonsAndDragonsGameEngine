class_name Campaign
extends RefCounted
## The campaign module the story engine asks (CampaignModule): the script named in data/campaign.json, loaded on first
## use, or the base module (a game with no campaign facts) when there is no file. Tests put their own in with use().
## The same file holds the campaign's settings (docs/reference/contracts/campaign.md): the level cap, the calendar, the
## reading (ReadingDeck), the arena's fight, the travel map's painting, the weather file, the camera's pitch, the
## finishes. A setting a game leaves out keeps the engine's default, which is how the first game on the engine played.

const CONFIG := "res://data/campaign.json"

## The first game's file paths and ids, kept as the defaults so a game that names none reads the same files as before.
const LEGACY := {
	"travel_map": "res://art/ui/map/barovia.png",
	"weather": "res://data/weather/barovia.json",
	"travel_main": "barovia",
	"land_name": "Barovia",
	"arena_encounter": "arena_wolves_and_zombies",
}
const LEVEL_CAP := 11

static var _module: CampaignModule
static var _config: Dictionary = {}
static var _config_read := false


static func module() -> CampaignModule:
	if _module == null:
		_module = _load()
	return _module


## Puts `m` in place of the configured module; null goes back to the configured one.
static func use(m: CampaignModule) -> void:
	_module = m


## The whole of data/campaign.json (read once), or {} when the game has none. Settings a game picks for itself live
## here beside the module: the camera's pitch (CameraRig.play_pitch), the finishes it offers (Look.finishes).
static func config() -> Dictionary:
	if not _config_read:
		_config_read = true
		if FileAccess.file_exists(CONFIG):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
			_config = parsed as Dictionary if parsed is Dictionary else {}
	return _config


## Puts `cfg` in place of data/campaign.json's settings (tests); null reads the file again.
static func use_config(cfg: Variant) -> void:
	_config = cfg as Dictionary if cfg is Dictionary else {}
	_config_read = cfg is Dictionary


static func _load() -> CampaignModule:
	var script := load(str(config().get("module", ""))) as GDScript if config().has("module") else null
	if script != null:
		return script.new() as CampaignModule
	return CampaignModule.new()


## One setting, or `fallback` when the game names none.
static func setting(key: String, fallback: Variant = null) -> Variant:
	return config().get(key, fallback)


## A setting that is a path or an id, with the first game's as its default.
static func path(key: String) -> String:
	return str(config().get(key, LEGACY.get(key, "")))


## The game's name in what it writes (error reports): `title`, else the project's name.
static func title() -> String:
	return str(config().get("title", ProjectSettings.get_setting("application/config/name", "Game")))


# --- Levels and scores -------------------------------------------------------------------------------------------

## The highest level the story takes the party to. `level_cap` is a number, or {"cap": 13, "raised": [{"when":
## "flag.moonfall", "cap": 20}]}: the highest `raised` cap whose condition holds wins (without a story, only `cap`).
static func level_cap(st: StoryState = null) -> int:
	var spec: Variant = config().get("level_cap", LEVEL_CAP)
	if not spec is Dictionary:
		return int(spec)
	var d := spec as Dictionary
	var cap := int(d.get("cap", LEVEL_CAP))
	if st != null:
		for r: Variant in d.get("raised", []):
			var rd := r as Dictionary
			if StoryConditions.check(str(rd.get("when", "false")), st):
				cap = maxi(cap, int(rd.get("cap", cap)))
	return cap


## How high a story's boon (a gift of +2 to a score) may take an ability score: `boon_ability_max`, else 20.
static func boon_ability_max() -> int:
	return int(config().get("boon_ability_max", 20))
