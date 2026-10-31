class_name Jail
extends RefCounted
## Jail (plan E10's cells; docs/contracts/dialogue.md `jail`): the party locked up in a place's cell. A conversation's
## `jail <location>[:<spawn>] [keep_gear] [until <condition>]` takes the party there, as `move` does, and the jailers
## keep every living hero's gear (what they wear and hold included) unless `keep_gear`. While the party is held the
## condition `jailed` holds, so the cell's door and the jail's exits stay shut with a `when` on it, and `days_since.jailed`
## counts the days inside. The party is let out by a `jail release` (a bribe paid, a sentence served, a friend's word) or,
## with `until`, as soon as that condition holds (settle, after each conversation and interaction); either way the
## gear comes back as it was and goes back on. An NPC in a cell is a placement in it with its own `when`. Pure logic.

## The story flag holding the stay: {location, spawn, until, gear: {hero id: [inventory entries]}}.
const STATE := "_jail"
## The flag stamped with the game minute the party was locked up, for `days_since.jailed`.
const STAMP := "jailed"


## Whether the party is held now: locked up, and its `until` (if any) not yet holding.
static func held(st: StoryState) -> bool:
	var stay := st.flags.get(STATE, {}) as Dictionary
	if stay.is_empty():
		return false
	var until := str(stay.get("until", ""))
	return until == "" or not StoryConditions.check(until, st)


## Locks the party up at `location`: stamps the day, and unless `keep_gear` takes every living hero's gear into keeping
## (off their bodies and out of their hands first).
static func lock_up(st: StoryState, location: String, spawn: String, until: String, keep_gear: bool) -> void:
	var gear := {}
	if not keep_gear:
		for ch in st.party:
			if ch.dead or ch.inventory.is_empty():
				continue
			var kept: Array = []
			for e: Dictionary in ch.inventory.duplicate():
				var entry := e.duplicate(true)
				if str(e.get("slot", "")) != "":
					entry["worn"] = str(e["slot"])
					ch.unequip_item(str(e["id"]))
					entry["slot"] = ""
				ch.inventory.erase(e)
				kept.append(entry)
			ch.refresh()
			gear[ch.id] = kept
	st.flags[STATE] = {"location": location, "spawn": spawn, "until": until, "gear": gear}
	st.set_flag(STAMP, st.total_minutes())


## Lets the party out and hands back what was kept, each item to its hero and back where it was worn or held. Returns
## what to tell the player ("" if the party wasn't locked up).
static func release(st: StoryState) -> String:
	var stay := st.flags.get(STATE, {}) as Dictionary
	if stay.is_empty():
		return ""
	st.flags.erase(STATE)
	st.flags.erase(STAMP)
	var gear := stay.get("gear", {}) as Dictionary
	for ch in st.party:
		var kept := gear.get(ch.id, []) as Array
		if kept.is_empty():
			continue
		var wear: Array[Array] = []
		for e: Variant in kept:
			var entry := (e as Dictionary).duplicate(true)
			if entry.has("worn"):
				wear.append([str(entry["id"]), str(entry["worn"])])
				entry.erase("worn")
			ch.inventory.append(entry)
		for w in wear:
			ch.equip(str(w[0]), str(w[1]))
		ch.refresh()
	return "You are free to go%s." % (", and your gear is handed back" if not gear.is_empty() else "")


## Lets the party out once its `until` holds. Returns what to tell the player, or "".
static func settle(st: StoryState) -> String:
	var stay := st.flags.get(STATE, {}) as Dictionary
	if stay.is_empty() or str(stay.get("until", "")) == "" or held(st):
		return ""
	return release(st)
