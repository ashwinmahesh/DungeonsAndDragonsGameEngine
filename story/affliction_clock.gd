class_name AfflictionClock
extends RefCounted
## Afflictions on the story's clock (docs/reference/contracts/afflictions.md "On the clock"): what happens as time passes
## to the heroes who have one, and to those out in what spreads one. LocationClock asks catch_up() as the clock moves,
## beside the Schedule. Kept in StoryState.flags[MEMORY] ({last: minute}) and on each affliction's effect, so saves
## keep it. Pure story logic; every roll goes through the DiceRoller it is handed.
##
## A definition's keys here: `onset_hours` (a new affliction lies dormant that long: no modifiers until it wakes, and then
## `onset_exhaustion` levels of Exhaustion come with it),
## `daily` {hour, save {ability, dc}, failure (levels gained, 1), successes_to_end} (each day at that hour every living
## hero who has it saves; enough successes end it; a spell in `held_off_by` skips the next one), `exposure` {when,
## every_minutes, save {ability, dc}, levels (1)} (while `when` holds, each living hero saves that often or gains levels).

const MEMORY := "_affliction_clock"
const DAY := 24 * 60
## The most days of daily saves, and of exposures, one look catches up (a long journey isn't a hundred rolls).
const MOST := 7


## Gives `ch` `n` levels of `id` from the story: a new one with `onset_hours` lies dormant until then.
static func afflict(st: StoryState, ch: Character, id: String, n: int) -> int:
	var def := Afflictions.definition(id)
	var before := Afflictions.level_of(ch, id)
	var after := Afflictions.add(ch, id, n, def)
	if before == 0 and after > 0 and int(def.get("onset_hours", 0)) > 0:
		Afflictions.effect_of(ch, id).data["dormant_until"] = st.total_minutes() + int(def["onset_hours"]) * 60
		Afflictions.set_level(ch, id, after, def)   # rebuilt asleep
	return after


## Everything that came due since the last look, oldest kind first. Returns the lines to show.
static func catch_up(st: StoryState, dice: DiceRoller) -> Array[String]:
	var lines: Array[String] = []
	if not st.flags.get(MEMORY, null) is Dictionary:
		st.flags[MEMORY] = {"last": st.total_minutes()}
	var mem := st.flags[MEMORY] as Dictionary
	var from := int(mem["last"])
	var now := st.total_minutes()
	if now <= from:
		return lines
	mem["last"] = now
	for def: Dictionary in Compendium.shared().all("afflictions"):
		var id := str(def.get("id", ""))
		for ch in st.party:
			if ch.dead or Afflictions.level_of(ch, id) <= 0:
				continue
			lines.append_array(_wake(st, ch, id, def))
			if def.get("daily", null) is Dictionary:
				lines.append_array(_daily(ch, id, def, from, now, dice))
		if def.get("exposure", null) is Dictionary:
			lines.append_array(_exposure(st, id, def, from, now, dice))
	return lines


static func _wake(st: StoryState, ch: Character, id: String, def: Dictionary) -> Array[String]:
	var fx := Afflictions.effect_of(ch, id)
	var until := int(fx.data.get("dormant_until", -1))
	if until < 0 or st.total_minutes() < until:
		return [] as Array[String]
	fx.data.erase("dormant_until")
	Afflictions.set_level(ch, id, Afflictions.level_of(ch, id), def)
	# A fever as it takes hold (`onset_exhaustion`: levels of Exhaustion, kept while it lasts with `exhaustion_lock`).
	if int(def.get("onset_exhaustion", 0)) > 0:
		ch.add_exhaustion(int(def["onset_exhaustion"]))
	return ["%s feels the %s take hold." % [ch.name.get_slice(" ", 0), str(def.get("name", id))]] as Array[String]


## How many times `hour` o'clock came round in (from, to], at most MOST.
static func _times(hour: int, from: int, to: int) -> int:
	var n := 0
	var day := floori(float(from) / DAY)
	while n < MOST:
		var t := day * DAY + hour * 60
		if t > to:
			break
		if t > from:
			n += 1
		day += 1
	return n


static func _daily(ch: Character, id: String, def: Dictionary, from: int, now: int, dice: DiceRoller) -> Array[String]:
	var lines: Array[String] = []
	var d := def["daily"] as Dictionary
	var first := ch.name.get_slice(" ", 0)
	var name := str(def.get("name", id))
	for i in _times(int(d.get("hour", 18)), from, now):
		var fx := Afflictions.effect_of(ch, id)
		if fx == null:
			break
		if int(fx.data.get("dormant_until", -1)) >= 0:
			continue
		if bool(fx.data.get("held", false)):
			fx.data.erase("held")
			lines.append("The %s holds off in %s today." % [name, first])
			continue
		var sv := d.get("save", {}) as Dictionary
		var ab := StringName(str(sv.get("ability", "con")))
		var t := ch.roll_save(dice, ab, int(sv.get("dc", 10)), [], [], "%s save vs the %s (%s)" % [Creature.ABILITY_NAMES[ab], name, ch.name])
		if t.success:
			var got := int(fx.data.get("successes", 0)) + 1
			fx.data["successes"] = got
			if d.has("successes_to_end") and got >= int(d["successes_to_end"]):
				Afflictions.clear(ch, id)
				lines.append("%s throws off the %s." % [first, name])
				break
			lines.append("%s fights the %s off for another day." % [first, name])
		else:
			var after := Afflictions.add(ch, id, int(d.get("failure", 1)), def)
			lines.append("The %s worsens in %s (level %d)." % [name, first, after])
	return lines


static func _exposure(st: StoryState, id: String, def: Dictionary, from: int, now: int, dice: DiceRoller) -> Array[String]:
	var lines: Array[String] = []
	var x := def["exposure"] as Dictionary
	if not StoryConditions.check(str(x.get("when", "")), st):
		return lines
	var every := maxi(1, int(x.get("every_minutes", 60)))
	var n := mini(MOST, floori(float(now) / every) - floori(float(from) / every))
	var name := str(def.get("name", id))
	for i in n:
		for ch in st.party:
			if ch.dead:
				continue
			var sv := x.get("save", {}) as Dictionary
			if not sv.is_empty():
				var ab := StringName(str(sv.get("ability", "con")))
				if ch.roll_save(dice, ab, int(sv.get("dc", 10)), [], [], "%s save vs the %s (%s)" % [Creature.ABILITY_NAMES[ab], name, ch.name]).success:
					continue
			var after := afflict(st, ch, id, int(x.get("levels", 1)))
			lines.append("The %s gets into %s (level %d)." % [name, ch.name.get_slice(" ", 0), after])
	return lines
