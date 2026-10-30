class_name StoryBoons
extends RefCounted
## Gifts the story gives a hero for good (plan E1, E13): a score raised past the usual 20, up to the campaign's
## `boon_ability_max` (Campaign.boon_ability_max; 20 when a game names none). Kept like a manual's gift (the build's
## `item_boons`), so the score's breakdown names where it came from and a save keeps it.


## Raises `ability` ("str" .. "cha") of `ch` by `amount`, never past the campaign's limit. Returns how much it rose.
static func raise_ability(ch: Character, ability: String, amount: int, source: String) -> int:
	var before := ch.ability_score(StringName(ability))
	if not ch.build.has("item_boons"):
		ch.build["item_boons"] = []
	var boons := ch.build["item_boons"] as Array
	# Each boon raises the score's maximum by its `max_raise`; the story's lift it to the campaign's limit and no further.
	var raised := 0
	for b: Variant in boons:
		if str((b as Dictionary).get("ability", "")) == ability:
			raised += int((b as Dictionary).get("max_raise", 0))
	boons.append({"ability": ability, "value": amount, "max_raise": maxi(0, Campaign.boon_ability_max() - 20 - raised),
		"source": source})
	ch.refresh()
	return ch.ability_score(StringName(ability)) - before
