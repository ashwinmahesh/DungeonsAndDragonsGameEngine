class_name CampaignModule
extends RefCounted
## What the story engine asks of the campaign it runs (docs/plans/engine_split.md). The engine names no campaign: where a
## story rule needs a fact only the campaign knows (a reading of the cards, a villain's attention, a field spell that
## reads the place, how the game ends), it asks the module `Campaign.module()` hands back. This base answers for a
## game with no such things: nothing is hidden anywhere, no one is watching, every spell is ordinary, the game never
## ends by itself. A campaign extends it and says which script in data/campaign.json (Curse of Strahd:
## story/strahd_campaign.gd).


# --- Text and facts the story data reaches for ------------------------------------------------------------------

## `text` with the campaign's {placeholders} filled from the story (quest journals, hints, warnings).
func fill(text: String, _st: StoryState) -> String:
	return text


## One fact of the campaign's own state, by dotted path (`ally.npc`); "" when there is none.
func field(_st: StoryState, _path: String) -> String:
	return ""


## The room the campaign's last fight waits in, or "".
func final_room(_st: StoryState) -> String:
	return ""


## The treasure ids hidden at `place` that the party hasn't taken.
func treasures_at(_place: String, _st: StoryState) -> Array[String]:
	return []


## Takes them: marks them found and returns their item ids.
func take_from(_place: String, _st: StoryState) -> Array[String]:
	return []


## The name the campaign gives one of its treasures ("The Sunsword"), or "" for any other item.
func treasure_name(_item_id: String) -> String:
	return ""


## Makes sure the campaign's reading (the story's seeded draw) exists.
func ensure_drawn(_st: StoryState) -> void:
	pass


## One slot of the reading, as {card, slot, title, verse} to show; {} when the slot holds nothing.
func reading(_slot: String, _st: StoryState) -> Dictionary:
	return {}


# --- A villain's attention ---------------------------------------------------------------------------------------

## The tier of attention the party has earned (its data: road_day, road_night, ...), or {}.
func presence_tier(_st: StoryState) -> Dictionary:
	return {}


## The attention level a named tier starts at, or -1 when there is none.
func presence_tier_min(_name: String) -> int:
	return -1


func presence_attention(_st: StoryState) -> int:
	return 0


## Whether `start` to `end` (minutes) spans a night.
func night_between(_start: int, _end: int) -> bool:
	return false


## Whether a visit due on `on` (for example "rest") with `ctx` would come to blows.
func visit_may_fight(_st: StoryState, _on: String, _ctx: Dictionary) -> bool:
	return false


## `enc` with its monsters placed on open ground near `near` (a visit finds room even on a crowded road).
func place_visitors(enc: Dictionary, _rows: Array, _taken: Array[Vector2i], _near: Vector2i) -> Dictionary:
	return enc


# --- Spells that read the place ----------------------------------------------------------------------------------

func handles_spell(_spell_id: String) -> bool:
	return false


## What the field spell tells, cast by `caster` where the party stands.
func cast_spell(_st: StoryState, _caster: Character, _spell_id: String, _choice: String = "") -> String:
	return ""


# --- How the game ends -------------------------------------------------------------------------------------------

## Records the ending that holds now (a dialogue's `end_game`).
func request_ending(_st: StoryState) -> void:
	pass


# --- Fights and places --------------------------------------------------------------------------------------------

## A talk the campaign plays before its final battle, as "<dialogue key>:<node>" (or "" for none), and who speaks it.
func parley_ref() -> String:
	return ""


func parley_speaker() -> String:
	return ""


## The party's answer to that parley ("" while unanswered).
func parley_answer(_st: StoryState) -> String:
	return ""


## Whether the final battle goes ahead after the parley (an answer that ends the game instead says no).
func parley_allows_fight(_st: StoryState) -> bool:
	return true


## The places in a location (ids) that the campaign's reading hid treasure in.
func treasure_spots(_loc: Dictionary) -> Array[String]:
	return []


## Takes the treasure hidden in `kind` ("container" or "encounter") `id` of a location, returning its item ids.
func take_treasure(_loc: Dictionary, _kind: String, _id: String, _st: StoryState) -> Array[String]:
	return []


## A final battle begins here: the campaign's quests may move on.
func final_battle_begun(_st: StoryState) -> void:
	pass


## Narrator keys (narrative/narrator) the campaign says when a fight starts or is won, besides the usual ones.
func fight_start_keys() -> Array[String]:
	return []


func fight_victory_keys() -> Array[String]:
	return []


## The stat block of the town watch when a crime brings them (data/npcs `monster` wins).
func guard_monster() -> String:
	return "guard"


## What the scouting spells find: the nearest trap within 30 ft (sprung harmlessly) and the nearest locked or secret way.
func spring_trap(_st: StoryState, _location_id: String, _cell: Vector2i, _ft: int = 30) -> Dictionary:
	return {}


func open_way(_st: StoryState, _location_id: String, _cell: Vector2i, _ft: int = 30) -> Dictionary:
	return {}


## What the campaign says when the party falls; shared by desktop and mobile.
func defeat_text() -> String:
	return "The adventure is not over. Load a save to try again."


# --- Endings and achievements -------------------------------------------------------------------------------------

## The campaign's endings (each {id, title, summary, ...}); each earns the achievement "ending_<id>".
func endings() -> Array[Dictionary]:
	return []


func ending(_id: String) -> Dictionary:
	return {}


## Achievements of the campaign's own beyond the engine's list: id -> [name, text].
func extra_achievements() -> Dictionary:
	return {}


## What a Skirmish with these foes (monster ids) earns beyond the engine's own.
func skirmish_achievements(_foe_monsters: Array[String]) -> Array[String]:
	return []
