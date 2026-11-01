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


## Gives `ch` `n` levels of `id` from the story: a new one with `onset_hours` (hours, or dice of hours rolled with
## `dice`) lies dormant until then.
static func afflict(st: StoryState, ch: Character, id: String, n: int, dice: DiceRoller = null) -> int:
	var def := Afflictions.definition(id)
	var before := Afflictions.level_of(ch, id)
	var after := Afflictions.add(ch, id, n, def)
	var hours := onset(def, dice)
	if before == 0 and after > 0 and hours > 0:
		Afflictions.effect_of(ch, id).data["dormant_until"] = st.total_minutes() + hours * 60
		Afflictions.set_level(ch, id, after, def)   # rebuilt asleep
	return after


## How many hours a new one lies dormant: `onset_hours` as a number, or as dice ("1d4") rolled with `dice` (without dice to
## roll, the most they could show is not assumed: their count, the least).
static func onset(def: Dictionary, dice: DiceRoller) -> int:
	var v: Variant = def.get("onset_hours", 0)
	if v is String and str(v).contains("d"):
		if dice != null:
			return int(dice.roll_expr(str(v), "%s takes hold" % str(def.get("name", "")))["total"])
		return maxi(1, int(str(v).get_slice("d", 0)))
	return int(v)


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
		for ch in st.party.duplicate():
			if Afflictions.level_of(ch, id) <= 0:
				continue
			if ch.dead:
				lines.append_array(_after_death(st, ch, id, def, from, now))
				continue
			lines.append_array(_suppression(st, ch, id, def))
			lines.append_array(_wake(st, ch, id, def))
			if def.get("daily", null) is Dictionary:
				lines.append_array(_daily(ch, id, def, from, now, dice))
			if def.get("repeat", null) is Dictionary:
				lines.append_array(_repeat(ch, id, def, from, now, dice))
		if def.get("exposure", null) is Dictionary:
			lines.append_array(_exposure(st, id, def, from, now, dice))
	return lines


## A spell holding it down (`suppressed_by`): its hours start at the first look after the casting, and when they're over it
## comes back.
static func _suppression(st: StoryState, ch: Character, id: String, def: Dictionary) -> Array[String]:
	var fx := Afflictions.effect_of(ch, id)
	var hours := int(fx.data.get("suppress_hours", 0))
	if hours > 0:
		fx.data.erase("suppress_hours")
		fx.data["suppressed_until"] = st.total_minutes() + hours * 60
		return [] as Array[String]
	var until := int(fx.data.get("suppressed_until", -1))
	if until < 0 or st.total_minutes() < until:
		return [] as Array[String]
	fx.data.erase("suppressed_until")
	Afflictions.set_level(ch, id, Afflictions.level_of(ch, id), def)
	return ["The %s stirs in %s again." % [str(def.get("name", id)), ch.name.get_slice(" ", 0)]] as Array[String]


## A hero who died with it (`on_death` {hour, becomes, flag, only_types}): at the next `hour` o'clock after the clock
## first saw them dead, the body becomes that creature and the hero is lost for good (the fallen keep them, with
## `becomes`; the condition `became:<monster>`), and `flag` counts it.
static func _after_death(st: StoryState, ch: Character, id: String, def: Dictionary, from: int, now: int) -> Array[String]:
	var od := def.get("on_death", {}) as Dictionary
	if od.is_empty():
		return [] as Array[String]
	if od.has("only_types") and not str(ch.creature_type) in (od["only_types"] as Array):
		return [] as Array[String]
	var fx := Afflictions.effect_of(ch, id)
	if not fx.data.has("dead_seen"):
		fx.data["dead_seen"] = from
	if _times(int(od.get("hour", 0)), int(fx.data["dead_seen"]), now) <= 0:
		return [] as Array[String]
	var monster := str(od.get("becomes", ""))
	st.lose_member(ch, "became:" + monster)
	(st.fallen[-1] as Dictionary)["becomes"] = monster
	if str(od.get("flag", "")) != "":
		st.set_flag(str(od["flag"]), int(st.get_flag(str(od["flag"]), 0)) + 1)
	return ["What the %s left of %s rises as %s." % [str(def.get("name", id)), ch.name.get_slice(" ", 0),
		Compendium.shared().display_name("monsters", monster) if monster != "" else "something else"]] as Array[String]


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


## The save again every so often (`repeat`: {every_minutes, save, failure (1)}): a success ends it, a failure adds levels;
## at its `max_level` no more saves come (captivated for good, until something cures it). The first is `every_minutes`
## after the start of the time the clock's first look at it covers.
static func _repeat(ch: Character, id: String, def: Dictionary, from: int, now: int, dice: DiceRoller) -> Array[String]:
	var lines: Array[String] = []
	var rp := def["repeat"] as Dictionary
	var every := maxi(1, int(rp.get("every_minutes", 10)))
	var first := ch.name.get_slice(" ", 0)
	var name := str(def.get("name", id))
	var top := int(def.get("max_level", 0))
	for i in MOST:
		var fx := Afflictions.effect_of(ch, id)
		if fx == null or (top > 0 and int(fx.data.get("level", 0)) >= top) or int(fx.data.get("dormant_until", -1)) >= 0:
			break
		if not fx.data.has("repeat_at"):
			fx.data["repeat_at"] = from + every   # counted from the start of the time this look covers
		if int(fx.data["repeat_at"]) > now:
			break
		fx.data["repeat_at"] = int(fx.data["repeat_at"]) + every
		var sv := rp.get("save", {}) as Dictionary
		var ab := StringName(str(sv.get("ability", "wis")))
		var t := ch.roll_save(dice, ab, int(sv.get("dc", 10)), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], name, ch.name])
		if t.success:
			Afflictions.clear(ch, id)
			lines.append("%s shakes off %s." % [first, name])
			break
		var after := Afflictions.add(ch, id, int(rp.get("failure", 1)), def)
		lines.append("%s sinks deeper into %s (level %d)." % [first, name, after])
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
			var after := afflict(st, ch, id, int(x.get("levels", 1)), dice)
			lines.append("The %s gets into %s (level %d)." % [name, ch.name.get_slice(" ", 0), after])
	return lines
