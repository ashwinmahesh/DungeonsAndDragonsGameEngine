extends TestCase
## Every action and Bonus Action the engine's summoned creatures have (SummonBlocks) is run by the engine, never handed
## to a game's features module (MonsterActions.ENGINE_DOS): when the game module came in, the summons' `heal`, `save` and
## `teleport` were left off the list, so Find Steed's Healing Touch, Fell Glare and Fey Step answered "Not available"
## in any game with a features module.

const FORMS := {
	"otherworldly_steed": ["celestial", "fey", "fiend"],
	"fey_spirit": ["fuming", "mirthful", "tricksy"],
	"undead_spirit": ["ghostly", "putrid", "skeletal"],
	"bestial_spirit": ["air", "land", "water"],
	"giant_insect": ["centipede", "spider", "wasp"],
	"aberrant_spirit": ["beholderkin", "mind_flayer", "slaad"],
	"construct_spirit": ["clay", "metal", "stone"],
	"elemental_spirit": ["air", "earth", "fire", "water"],
	"celestial_spirit": ["avenger", "defender"],
	"draconic_spirit": ["fire", "cold", "acid", "lightning", "poison"],
}


func test_no_summoned_creatures_action_goes_to_the_game() -> void:
	var seen := 0
	for maker: String in FORMS:
		for kind: String in FORMS[maker]:
			var block := _block(maker, kind)
			for group: String in ["actions", "bonus_actions", "reactions"]:
				for a: Variant in block.get(group, []):
					var act := a as Dictionary
					if act.has("do"):
						seen += 1
						assert_false(MonsterActions.game_action(act), "%s %s: %s (%s) is the engine's" % [maker, kind, act.get("name", ""), act["do"]])
	assert_true(seen >= 4, "(the summons' own dos were found: %d)" % seen)
	assert_true(MonsterActions.game_action({"do": "game"}), "a `do` the engine doesn't run is still the game's")


static func _block(maker: String, kind: String) -> Dictionary:
	match maker:
		"otherworldly_steed":
			return SummonBlocks.otherworldly_steed(2, kind, 5, 13)
		"fey_spirit":
			return SummonBlocks.fey_spirit(3, kind, 5, 13)
		"undead_spirit":
			return SummonBlocks.undead_spirit(3, kind, 5, 13)
		"bestial_spirit":
			return SummonBlocks.bestial_spirit(2, kind, 5)
		"giant_insect":
			return SummonBlocks.giant_insect(4, kind, 5, 13)
		"aberrant_spirit":
			return SummonBlocks.aberrant_spirit(4, kind, 5, 13)
		"construct_spirit":
			return SummonBlocks.construct_spirit(4, kind, 5, 13)
		"elemental_spirit":
			return SummonBlocks.elemental_spirit(4, kind, 5)
		"celestial_spirit":
			return SummonBlocks.celestial_spirit(5, kind, 5)
		"draconic_spirit":
			return SummonBlocks.draconic_spirit(5, kind, 5, 13)
	return {}
