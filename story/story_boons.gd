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


## A spell's own bonus given by the story (a blessing from a reading, a shrine, a priest): the `modifiers` of spell
## `spell_id` (Bless's 1d4 on attack rolls and saving throws) on `ch` for `minutes` of exploring and fighting time, not
## kept up by Concentration and costing no one a slot. A second one of the same spell replaces the first. False for the
## dead, or a spell with no modifiers to give.
static func spell_boon(ch: Character, spell_id: String, minutes: int) -> bool:
	var data := Compendium.shared().spell_data(spell_id)
	if ch.dead or data.is_empty():
		return false
	var fx := Effect.new(str(data.get("name", spell_id)), &"spell", spell_id)
	for f: Variant in data.get("effects", []):
		if str((f as Dictionary).get("effect", "")) != "modifiers":
			continue
		for md: Variant in ((f as Dictionary).get("params", {}) as Dictionary).get("modifiers", []):
			fx.modifiers.append(Modifier.make((md as Dictionary).duplicate(true), fx.name, &"spell", spell_id))
	if fx.modifiers.is_empty():
		return false
	fx.caster_id = ch.id
	fx.ends = Effect.Ends.MINUTES
	fx.minutes_left = minutes
	for old: Effect in ch.effects.duplicate():
		if old.key() == fx.key():
			ch.remove_effect(old)
	ch.add_effect(fx)
	return true
