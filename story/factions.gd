class_name Factions
extends RefCounted
## Faction standing (plan E11; docs/contracts/campaign.md): how a whole faction thinks of the party, a number every
## member reads. An NPC belongs to the faction its data's `faction_<id>` tag names (`faction_none`, or no such tag: none).
## The standing is a story flag, `standing_<id>` (0 until something moves it), moved by the dialogue's `standing <id> +n`
## and by a crime against a member; conditions read it as `standing.<id>`, so any placement's `when` can key on it (who
## stands in the square, what the village shows). Past the campaign's thresholds it sets a member's attitude, unless
## that member has an opinion of their own (StoryState.attitudes). Pure logic.

const FLAG := "standing_%s"
## The campaign's `standing` settings (data/campaign.json) and their defaults: at `friendly_at` or more every member is
## friendly, at `hostile_at` or less hostile; standing stays within `min`..`max`.
const DEFAULTS := {"friendly_at": 3, "hostile_at": -3, "min": -10, "max": 10}


static func setting(key: String) -> int:
	return int((Campaign.setting("standing", {}) as Dictionary).get(key, DEFAULTS[key]))


## The faction `npc_id` belongs to, or "".
static func of_npc(npc_id: String) -> String:
	for tag: Variant in Compendium.shared().get_entry("npcs", npc_id).get("tags", []):
		var t := str(tag)
		if t.begins_with("faction_") and t != "faction_none":
			return t.substr(8)
	return ""


## The faction's name for the player: the campaign's `factions.<id>.name`, else its id in words.
static func name_of(faction: String) -> String:
	var named := ((Campaign.setting("factions", {}) as Dictionary).get(faction, {}) as Dictionary).get("name", "")
	return str(named) if str(named) != "" else faction.replace("_", " ").capitalize()


static func standing(st: StoryState, faction: String) -> int:
	return int(st.get_flag(FLAG % faction, 0))


## Moves `faction`'s standing by `delta`, within the campaign's limits. Returns the standing now.
static func change(st: StoryState, faction: String, delta: int) -> int:
	var now := clampi(standing(st, faction) + delta, setting("min"), setting("max"))
	st.set_flag(FLAG % faction, now)
	return now


## `base` (an NPC's own attitude) as their faction's standing makes it: friendly or hostile past the thresholds.
static func attitude(st: StoryState, npc_id: String, base: String) -> String:
	var faction := of_npc(npc_id)
	if faction == "":
		return base
	var n := standing(st, faction)
	if n >= setting("friendly_at"):
		return "friendly"
	if n <= setting("hostile_at"):
		return "hostile"
	return base
