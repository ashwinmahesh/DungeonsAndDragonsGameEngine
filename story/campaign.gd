class_name Campaign
extends RefCounted
## The campaign module the story engine asks (CampaignModule): the script named in data/campaign.json, loaded on first
## use, or the base module (a game with no campaign facts) when there is no file. Tests put their own in with use().

const CONFIG := "res://data/campaign.json"

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
