class_name DefeatCapture
extends RefCounted
## Losing a fight without dying (an encounter's `defeat`, docs/reference/contracts/locations.md): when the party falls in
## a fight whose entry says so, it is taken instead of killed. The heroes still breathing come round at `hp` (1), the
## flags in `set` are set, and with `jail` the party is locked up there as a conversation's `jail` does (Jail: its gear
## kept unless `keep_gear`, let out by `until` or a `jail release`); with `move` it is carried there with its gear.
## The fight's outcome is "captured", not "defeat", so the game goes on. Pure story logic: the view moves the party.
##
## `defeat`: {jail: "<location>[:<spawn>]" or move: "<location>[:<spawn>]", until, keep_gear, hp, set: flag or [flags],
## say: a Narrator key}.

const OUTCOME := "captured"


## The entry's `defeat` rule, or {}.
static func rule_for(spec: Dictionary) -> Dictionary:
	var rule := spec.get("defeat", {})
	return rule as Dictionary if rule is Dictionary else {}


## Takes the fallen party as `rule` says. Returns {location, spawn} for the view to move it to ("" stays where it is).
static func apply(st: StoryState, rule: Dictionary) -> Dictionary:
	var hp := maxi(1, int(rule.get("hp", 1)))
	for ch in st.party:
		if ch.dead:
			continue
		if ch.hp <= 0:
			ch.hp = mini(hp, ch.max_hp())
		ch.death_successes = 0
		ch.death_failures = 0
		ch.stable = false
		ch.end_condition(&"unconscious")
	var flags: Variant = rule.get("set", [])
	for f: Variant in (flags as Array if flags is Array else [flags]):
		if str(f) != "":
			st.set_flag(str(f), st.total_minutes())
	var where := str(rule.get("jail", rule.get("move", "")))
	if where == "":
		return {"location": "", "spawn": ""}
	var loc := where.get_slice(":", 0)
	var spawn := where.get_slice(":", 1) if where.contains(":") else "default"
	if rule.has("jail"):
		Jail.lock_up(st, loc, spawn, str(rule.get("until", "")), bool(rule.get("keep_gear", false)))
	return {"location": loc, "spawn": spawn}
