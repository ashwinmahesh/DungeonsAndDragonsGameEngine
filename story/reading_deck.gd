class_name ReadingDeck
extends RefCounted
## The cards a campaign reads fortunes from (plan E22), for the dialogue's `reading draw|read|give` statements and the
## module that answers them (CampaignModule.ensure_drawn, reading). The deck is data: data/<deck>/cards.json holds
## {"cards": [{id, name, deck?, suit?, value?, art?}]}, any number of them. The campaign's `reading` settings in
## data/campaign.json name the folder (`deck`), where each card's picture is (`art`: <art>/<card art or id>.png), who
## reads by default (`reader`, a speaker id) and how many cards each hero is dealt (`cards_per_hero`, 1 or 2). A game
## that names none reads the first game's deck. Pure logic: no nodes, and the draw takes the playthrough's seed, not the
## dice, so a reload never changes it.

const DEFAULTS := {"deck": "tarokka", "art": "res://art/tarokka", "reader": "madam_eva", "cards_per_hero": 1}


## One of the `reading` settings.
static func setting(key: String) -> Variant:
	return (Campaign.setting("reading", {}) as Dictionary).get(key, DEFAULTS[key])


## Every card of the deck, in the file's order; with `deck_name`, only the cards whose `deck` is that (a high deck).
static func cards(deck_name: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Variant in Compendium.shared().get_entry(str(setting("deck")), "cards").get("cards", []):
		var d := c as Dictionary
		if deck_name == "" or str(d.get("deck", "")) == deck_name:
			out.append(d)
	return out


static func card(card_id: String) -> Dictionary:
	for c in cards():
		if str(c["id"]) == card_id:
			return c
	return {}


## The picture of `card_id`, or "" when the campaign has none for it (the card face then shows its name).
static func art(card_id: String) -> String:
	var at := "%s/%s.png" % [str(setting("art")).trim_suffix("/"), str(card(card_id).get("art", card_id))]
	return at if ResourceLoader.exists(at) else ""


## The slots a party of `size` is dealt, in party order: hero_1 .. hero_N, then hero_1b .. hero_Nb when each hero is
## dealt two cards.
static func hero_slots(size: int) -> Array[String]:
	var out: Array[String] = []
	for i in range(1, size + 1):
		out.append("hero_%d" % i)
	if int(setting("cards_per_hero")) >= 2:
		for i in range(1, size + 1):
			out.append("hero_%db" % i)
	return out


## A card for every slot, none twice, from `seed_value`: {slot: card id}. Same seed, same reading. {} when the deck
## (or its `deck_name` part) has fewer cards than slots.
static func draw(slots: Array[String], seed_value: int, deck_name: String = "") -> Dictionary:
	var ids: Array[String] = []
	for c in cards(deck_name):
		ids.append(str(c["id"]))
	if ids.size() < slots.size():
		return {}
	ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := ids[i]
		ids[i] = ids[j]
		ids[j] = t
	var out := {}
	for i in slots.size():
		out[slots[i]] = ids[i]
	return out
