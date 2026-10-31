class_name CheckEdges
extends RefCounted
## Advantage or Disadvantage the story grants on the party's checks in conversations (docs/contracts/dialogue.md):
## `advantage <skill|checks> [next|<n>m|<n>h][: why]` and `disadvantage ...`. One for `next` (the default) counts on
## the next such check and is used up; a timed one counts on every such check until the clock passes it. `checks` is any
## skill. Kept in the story flag `_check_edges`, so a save keeps them. Pure logic.

const FLAG := "_check_edges"
const ANY := "checks"


## Grants `kind` ("adv" or "dis") on `skill` checks (or ANY): for the next one (`minutes` 0) or for `minutes`.
static func grant(st: StoryState, kind: String, skill: String, minutes: int, why: String) -> void:
	var edges := (st.flags.get(FLAG, []) as Array).duplicate(true)
	edges.append({"kind": kind, "skill": skill, "until": st.total_minutes() + minutes if minutes > 0 else -1,
		"why": why if why != "" else ("Advantage" if kind == "adv" else "Disadvantage")})
	st.flags[FLAG] = edges


## The edges that count on a `skill` check now: {adv: [why], dis: [why]}. Ones for the next check are used up, and
## timed ones past their time are dropped.
static func take(st: StoryState, skill: String) -> Dictionary:
	var out := {"adv": [] as Array[String], "dis": [] as Array[String]}
	var kept: Array = []
	for e: Variant in st.flags.get(FLAG, []):
		var edge := e as Dictionary
		var until := int(edge["until"])
		if until >= 0 and st.total_minutes() >= until:
			continue
		if str(edge["skill"]) != ANY and str(edge["skill"]) != skill:
			kept.append(edge)
			continue
		(out[str(edge["kind"])] as Array[String]).append(str(edge["why"]))
		if until >= 0:
			kept.append(edge)
	if kept.is_empty():
		st.flags.erase(FLAG)
	else:
		st.flags[FLAG] = kept
	return out
