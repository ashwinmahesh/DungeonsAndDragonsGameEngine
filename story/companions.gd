class_name Companions
extends RefCounted
## Bonded companions (docs/reference/contracts/campaign.md "Companions"): a creature bonded to one hero, not by a spell (a
## familiar won in a story, a doll that walks, a thing from a jar). It follows the party at the back of the line and
## fights on the party's side, played by the player. Held in the story's flags under KEY ({hero id: {monster, name}}),
## so a save keeps it with no change to what a save holds. Pure story logic.

## st.flags: {hero id: {monster: a stat block id, name: what it is called ("" for the block's name)}}.
const KEY := "_companions"


static func all(st: StoryState) -> Dictionary:
	var v: Variant = st.flags.get(KEY, {})
	return v as Dictionary if v is Dictionary else {}


## The companion bonded to hero `hero_id`, or {}.
static func of(st: StoryState, hero_id: String) -> Dictionary:
	return all(st).get(hero_id, {}) as Dictionary


## Bonds stat block `monster` to hero `hero_id` (one each: a new bond replaces the old), called `name`.
static func bond(st: StoryState, hero_id: String, monster: String, name: String = "") -> void:
	var table := all(st).duplicate(true)
	table[hero_id] = {"monster": monster, "name": name}
	st.flags[KEY] = table


## Ends hero `hero_id`'s bond (the companion is gone). True if there was one.
static func release(st: StoryState, hero_id: String) -> bool:
	var table := all(st).duplicate(true)
	if not table.has(hero_id):
		return false
	table.erase(hero_id)
	st.flags[KEY] = table
	return true


## A fresh creature for hero `hero_id`'s companion (full Hit Points), or null: id "companion_<hero id>", its name.
static func creature_for(st: StoryState, hero_id: String) -> Monster:
	var c := of(st, hero_id)
	var data := Compendium.shared().monster_data(str(c.get("monster", "")))
	if data.is_empty():
		return null
	var mon := Monster.from_data(data)
	mon.id = "companion_%s" % hero_id
	if str(c.get("name", "")) != "":
		mon.name = str(c["name"])
	return mon
