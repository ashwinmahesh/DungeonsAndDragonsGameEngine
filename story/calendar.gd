class_name Calendar
extends RefCounted
## The campaign's day (plan E2): when night falls, how the hours look, what the hours are called, when the day's
## magic comes back, and the moon. All of it is the campaign's `calendar` setting in data/campaign.json:
##   "night": [19, 6]        night from 19:00 to 05:59 (hours, or "HH:MM"); `is_night()` everywhere reads it
##   "eternal_night": true   no sun: always night (the hours' `phase` still sets how each one looks)
##   "hours": [{"from": "18:00", "name": "the Twilight Hour", "phase": "dusk"}, ...]: named hours, each running until
##                           the next one's `from`; a `phase` (day, dusk, night, dawn) overrides the look of that hour
##   "dawn": "06:00", "dusk": "18:00": when an item's "at dawn" and "at dusk" charges come back
##   "words": {"dawn": "dusk"}: what the screens call those moments ("regains 1 charge at dusk")
##   "start": "18:00"        when a new game's first day begins
##   "moon": {"size": 1.0, "brightness": 1.0, "nights": [{"size": 1.2, "brightness": 1.1}, ...]}: the moon's disc
##                           in the sky and its key light outdoors at night, the `nights` cycling one a day
## A game that names none keeps the engine's day: night 19:00 to 06:00, dusk 18:00, dawn 06:00, no hour names, a
## start at 18:00, one moon. Pure logic.

const DAY := 24 * 60
const DEFAULT := {"night": [19, 6], "dawn": 6, "dusk": 18, "start": 18}


static func spec() -> Dictionary:
	return Campaign.setting("calendar", {}) as Dictionary


## A time of day as minutes: an hour (19, 17.5), "HH:MM", or the name of one of the campaign's hours (its start).
static func minutes_of(v: Variant) -> int:
	if v is String and (v as String).contains(":"):
		return (int((v as String).get_slice(":", 0)) * 60 + int((v as String).get_slice(":", 1))) % DAY
	if v is String and not (v as String).is_valid_float():
		for h: Variant in spec().get("hours", []):
			if str((h as Dictionary).get("name", "")).to_lower() == (v as String).to_lower():
				return minutes_of((h as Dictionary).get("from", 0))
		return 0
	return roundi(float(v) * 60.0) % DAY


static func _at(key: String) -> int:
	return minutes_of(spec().get(key, DEFAULT[key]))


static func eternal_night() -> bool:
	return bool(spec().get("eternal_night", false))


## Whether `minute` (of the day) is night.
static func is_night(minute: int) -> bool:
	if eternal_night():
		return true
	var n := spec().get("night", DEFAULT["night"]) as Array
	var from := minutes_of(n[0])
	var to := minutes_of(n[1])
	minute = posmod(minute, DAY)
	return minute >= from or minute < to if from > to else (minute >= from and minute < to)


## The named hour `minute` falls in ({from, name, phase?}), or {} when the campaign names none.
static func hour(minute: int) -> Dictionary:
	var hours := spec().get("hours", []) as Array
	if hours.is_empty():
		return {}
	minute = posmod(minute, DAY)
	var best: Dictionary = {}
	var best_from := -1
	var latest: Dictionary = {}
	var latest_from := -1
	for h: Variant in hours:
		var hd := h as Dictionary
		var f := minutes_of(hd.get("from", 0))
		if f <= minute and f > best_from:
			best = hd
			best_from = f
		if f > latest_from:
			latest = hd
			latest_from = f
	return best if best_from >= 0 else latest   # before the day's first named hour: the last one still runs


## The name of the hour `minute` is in ("" without named hours).
static func hour_name(minute: int) -> String:
	return str(hour(minute).get("name", ""))


## How the world looks at `minute`: "day", "dusk", "night" or "dawn". The engine's day: day 7:00-17:59, dusk the hour
## from dusk, night from nightfall, dawn the hour from dawn. A named hour's `phase` wins; under eternal night every
## other hour is night.
static func phase(minute: int) -> String:
	var named := str(hour(minute).get("phase", ""))
	if named != "":
		return named
	if eternal_night() or is_night(minute):
		return "night"
	minute = posmod(minute, DAY)
	if minute >= _at("dusk") and minute < _at("dusk") + 60:
		return "dusk"
	if minute >= _at("dawn") and minute < _at("dawn") + 60:
		return "dawn"
	return "day"


## When the day's "at dawn" charges come back, and the "at dusk" ones (minutes of the day).
static func dawn_minute() -> int:
	return _at("dawn")


static func dusk_minute() -> int:
	return _at("dusk")


## What the screens call `moment` ("dawn" or "dusk"): the campaign's `words`, else the moment itself.
static func word(moment: String) -> String:
	return str((spec().get("words", {}) as Dictionary).get(moment, moment))


## When a new game's first day begins (minutes of the day).
static func start_minute() -> int:
	return _at("start")


## The moon on `day`: {size, brightness} (each 1.0 for the engine's moon).
static func moon(day: int) -> Dictionary:
	var m := spec().get("moon", {}) as Dictionary
	var out := {"size": float(m.get("size", 1.0)), "brightness": float(m.get("brightness", 1.0))}
	var nights := m.get("nights", []) as Array
	if not nights.is_empty():
		var n := nights[posmod(day - 1, nights.size())] as Dictionary
		out["size"] = float(n.get("size", out["size"]))
		out["brightness"] = float(n.get("brightness", out["brightness"]))
	return out


## "18:40", and the hour's name after it when the campaign names its hours ("18:40 · the Twilight Hour").
static func clock(minute: int) -> String:
	minute = posmod(minute, DAY)
	var name := hour_name(minute)
	return "%02d:%02d" % [minute / 60, minute % 60] + (" · " + name if name != "" else "")
