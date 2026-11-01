class_name NightEvents
extends RefCounted
## Named night events (data/camp/night_events.json, optional): what comes for a party that takes a real Long Rest in
## certain places while a story condition holds (a forest's Dead of Night, a plague's swarms the first night in the
## village). One comes in a night at most, the first in the file that is due; it breaks the rest before its benefits,
## as the campaign's visit does (LongRest.VISIT), and the game plays its dialogue (which may start a fight). Once the
## dialogue, and any fight, is over the party sleeps on (LongRest.resume).

const FILE := "res://data/camp/night_events.json"
## st.flags: event id -> the minute it came (an underscore key: bookkeeping, not story).
const SEEN := "_night_events"
static var _data: Dictionary = {}
static var _loaded := false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		_data = {}
		if FileAccess.file_exists(FILE):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
			if parsed is Dictionary:
				_data = parsed as Dictionary
	return _data


## Replaces the events (tests); an empty `d` reads the file again next time.
static func use(d: Dictionary) -> void:
	_data = d
	_loaded = not d.is_empty()


static func events() -> Array:
	return data().get("events", []) as Array


static func get_event(id: String) -> Dictionary:
	for e: Variant in events():
		if str((e as Dictionary)["id"]) == id:
			return e as Dictionary
	return {}


## Whether `event` may come for a rest where the party is now: its `locations` (map ids) or `regions` hold the place
## (neither: anywhere), its `when` holds, and a `once` event hasn't come before.
static func applies(event: Dictionary, st: StoryState) -> bool:
	var locs := event.get("locations", []) as Array
	var regions := event.get("regions", []) as Array
	if not locs.is_empty() or not regions.is_empty():
		var region := str(Compendium.shared().get_entry("locations", st.location).get("region", ""))
		if not locs.has(st.location) and not regions.has(region):
			return false
	if bool(event.get("once", true)) and (st.flags.get(SEEN, {}) as Dictionary).has(str(event["id"])):
		return false
	return StoryConditions.check(str(event.get("when", "")), st)


## The night's event, if one comes: the first that applies, on its `chance` (a d100; certain when unset). Notes it as
## come. {} when none does.
static func due(st: StoryState, dice: DiceRoller) -> Dictionary:
	for e: Variant in events():
		var event := e as Dictionary
		if not applies(event, st):
			continue
		var chance := float(event.get("chance", 1.0))
		if chance < 1.0 and dice.roll_one(100, "Night event: %s" % event["id"]) > roundi(chance * 100.0):
			continue
		var seen := st.flags.get(SEEN, {}) as Dictionary
		seen[str(event["id"])] = st.total_minutes()
		st.flags[SEEN] = seen
		return event
	return {}
