class_name PlaceHazards
extends RefCounted
## Places whose air harms whoever stays (a location's `hazard`, on the exploration clock): a haze, a miasma.
## `{name, every_min, save, condition, lasting: {every_min, exhaustion}, immune_flags, when}`:
## - On entering the place and every `every_min` (10) minutes inside, while its story `when` holds, each living hero and
##   story ally travelling with them (st.guests) not carrying one of `immune_flags` makes the `save` or gains `condition`
##   (Poisoned).
## - A hero holding that condition from the place makes the save again every `lasting.every_min` (60) minutes, wherever
##   they are: failing adds `lasting.exhaustion` (1) levels of Exhaustion, succeeding ends it.
## Rolls go through a DiceRoller seeded from the playthrough and the minute, so the same walk gives the same result. What happens is queued
## on StoryState (hazard_news) for the world to show. Bookkeeping lives in underscore flags (saved with the story).

const CHECKS := "_place_hazard_at"     ## location id -> the minute of its last check
const HELD := "_place_hazard_held"     ## hero id -> {loc, next_at}


static func hazard_of(st: StoryState, loc_id: String) -> Dictionary:
	var hz := Compendium.shared().get_entry("locations", loc_id).get("hazard", {}) as Dictionary
	if hz.is_empty() or not StoryConditions.check(str(hz.get("when", "")), st):
		return {}
	return hz


static func _source(loc_id: String) -> String:
	return "place:" + loc_id


## The party has just come into `st.location`: the check on entering (and the clock for any other place stops).
static func entered(st: StoryState) -> void:
	var checks := {}
	st.flags[CHECKS] = checks
	var hz := hazard_of(st, st.location)
	if hz.is_empty():
		return
	checks[st.location] = st.total_minutes()
	_check_all(st, st.location, hz, st.total_minutes())


## The clock moved `minutes` on from `start` (StoryState.advance_minutes).
static func tick(st: StoryState, start: int, minutes: int) -> void:
	if minutes <= 0:
		return
	var now := start + minutes
	var hz := hazard_of(st, st.location)
	var checks := st.flags.get(CHECKS, {}) as Dictionary
	if not hz.is_empty() and checks.has(st.location):
		var every := maxi(1, int(hz.get("every_min", 10)))
		var at := int(checks[st.location])
		while at + every <= now:
			at += every
			_check_all(st, st.location, hz, at)
		checks[st.location] = at
	var held := st.flags.get(HELD, {}) as Dictionary
	for id: String in held.keys():
		var rec := held[id] as Dictionary
		var ch := _hero(st, id)
		var hz2 := Compendium.shared().get_entry("locations", str(rec["loc"])).get("hazard", {}) as Dictionary
		if ch == null or ch.dead or hz2.is_empty() or not ch.has_condition(StringName(str(hz2.get("condition", "poisoned")))):
			held.erase(id)
			continue
		var lasting := hz2.get("lasting", {}) as Dictionary
		var every2 := maxi(1, int(lasting.get("every_min", 60)))
		while int(rec["next_at"]) <= now and held.has(id):
			var when := int(rec["next_at"])
			rec["next_at"] = when + every2
			var t := _save(st, ch, hz2, when)
			if t.success:
				ch.remove_condition(StringName(str(hz2.get("condition", "poisoned"))), _source(str(rec["loc"])))
				held.erase(id)
				_news(st, "%s shakes off %s." % [ch.name.get_slice(" ", 0), str(hz2.get("name", "the bad air"))])
			else:
				ch.add_exhaustion(int(lasting.get("exhaustion", 1)))
				_news(st, "%s sickens from %s: a level of Exhaustion." % [ch.name.get_slice(" ", 0), str(hz2.get("name", "the bad air"))])
	st.flags[HELD] = held


static func _check_all(st: StoryState, loc_id: String, hz: Dictionary, at: int) -> void:
	var cond := StringName(str(hz.get("condition", "poisoned")))
	var held := st.flags.get(HELD, {}) as Dictionary
	for ch in _everyone(st):
		if ch.dead or held.has(ch.id):
			continue
		if (hz.get("immune_flags", []) as Array).any(func(f: Variant) -> bool: return ch.has_flag(str(f))):
			continue
		var t := _save(st, ch, hz, at)
		if t.success:
			continue
		if ch.add_condition(cond, _source(loc_id)):
			held[ch.id] = {"loc": loc_id, "next_at": at + int((hz.get("lasting", {}) as Dictionary).get("every_min", 60))}
			_news(st, "%s breathes in %s and is %s." % [ch.name.get_slice(" ", 0), str(hz.get("name", "the bad air")), str(cond).capitalize()])
	st.flags[HELD] = held


static func _save(st: StoryState, ch: Creature, hz: Dictionary, at: int) -> D20Test:
	var sv := hz.get("save", {"ability": "con", "dc": 10}) as Dictionary
	var dice := DiceRoller.new(hash("%d:%d:%s:place_hazard" % [st.playthrough_seed, at, ch.id]))
	return ch.roll_save(dice, StringName(str(sv["ability"])), int(sv["dc"]), [], [], "%s save vs %s (%s)" % [
		str(sv["ability"]).to_upper(), str(hz.get("name", "the air")), ch.name])


static func _hero(st: StoryState, id: String) -> Creature:
	for ch in _everyone(st):
		if ch.id == id:
			return ch
	return null


## The party and the story allies travelling with it.
static func _everyone(st: StoryState) -> Array[Creature]:
	var out: Array[Creature] = []
	for ch in st.party:
		out.append(ch)
	out.append_array(st.guests)
	return out


static func _news(st: StoryState, line: String) -> void:
	st.hazard_news.append(line)


## The lines waiting to be shown, emptied.
static func drain(st: StoryState) -> Array[String]:
	var out := st.hazard_news.duplicate()
	st.hazard_news.clear()
	return out
