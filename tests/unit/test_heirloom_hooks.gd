extends TestCase
## What a growing heirloom needs (docs/contracts/modifiers.md, magic_items.md): the formula term `tier`, a power's
## `min_level`, uses that come back at dusk, extra weapon damage only against a creature with a condition, a game's own
## item powers (GameFeatures.handles_item_power), and a condition that lands through immunity (`pierce`).

var content := FixtureContent.new()


## A game whose own item power is "test_song".
class SongGame extends GameFeatures:
	var asked := 0
	var used := 0

	func handles_item_power(custom: String) -> bool:
		return custom == "test_song"

	func item_power_why(_c: Combatant, _p: Dictionary) -> String:
		asked += 1
		return ""

	func item_power_use(_c: Combatant, _p: Dictionary, _targets: Array, _point: Vector2, _opts: Dictionary) -> CombatResult:
		used += 1
		return CombatResult.new()


func before_each() -> void:
	content.add("items", {"id": "test_heirloom", "name": "Test Heirloom", "category": "wondrous", "summary": "It grows with you.",
		"powers": [
			{"id": "early", "name": "Early Trick", "cost": "action", "uses": {"count": 1, "per": "dusk"}, "custom": "test_song"},
			{"id": "late", "name": "Late Trick", "cost": "action", "min_level": 7, "custom": "test_song"},
			{"id": "other", "name": "Engine Trick", "cost": "action", "custom": "test_not_ours"}]})


func after_each() -> void:
	content.restore()


func _fight(level: int) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), level)
	(hero.creature as Character).add_item("test_heirloom", 1)
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, foe]


func test_tier_grows_with_the_bearers_level() -> void:
	for pair: Array in [[1, 1], [6, 1], [7, 2], [12, 2], [13, 3], [20, 3]]:
		assert_eq(Creature.tier_for(int(pair[0])), int(pair[1]), "level %d is tier %d" % [pair[0], pair[1]])
	for level: int in [4, 7]:
		var ch := TestChars.pregen("hedda_ironvow", level)
		assert_eq(ch.character_level(), level, "(the pregen is level %d)" % level)
		assert_eq(Formula.evaluate("tier", ch.formula_context()), Creature.tier_for(level), "the formula term at level %d" % level)
	assert_eq(Formula.evaluate("2*tier", TestChars.pregen("hedda_ironvow", 7).formula_context()), 4, "it scales like any term")


func test_a_later_power_waits_for_its_level() -> void:
	var low := _fight(4)
	var e := low[0] as Encounter
	assert_eq(e.items.power_why(low[1] as Combatant, e.items.find_power(low[1] as Combatant, "test_heirloom", "late")), "From level 7")
	var high := _fight(7)
	var e2 := high[0] as Encounter
	e2.game = SongGame.new(e2)
	assert_eq(e2.items.power_why(high[1] as Combatant, e2.items.find_power(high[1] as Combatant, "test_heirloom", "late")), "", "at 7 it can")


func test_uses_per_dusk_come_back_at_dusk_not_dawn() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 4)
	ch.add_item("test_heirloom", 1)
	var entry := ch.entry_of("test_heirloom")
	entry["uses"] = {"early": 1}
	ch.on_dawn(DiceRoller.new(1))
	assert_eq((entry["uses"] as Dictionary).get("early", 0), 1, "dawn brings it back no sooner")
	ch.on_dusk(DiceRoller.new(1))
	assert_false((entry["uses"] as Dictionary).has("early"), "dusk does")


func test_extra_damage_only_against_a_creature_with_the_condition() -> void:
	var got := _fight(4)
	var e := got[0] as Encounter
	var foe := got[2] as Combatant
	var rule := {"dice": "1d6", "type": "psychic", "vs_condition": "frightened"}
	assert_false(e.items._rule_applies(got[1] as Combatant, foe, "test_heirloom", rule, {}), "not frightened: no extra")
	foe.creature.add_condition(&"frightened", "test")
	assert_true(e.items._rule_applies(got[1] as Combatant, foe, "test_heirloom", rule, {}), "frightened: the extra dice")


func test_a_games_own_item_power_goes_to_the_game() -> void:
	var got := _fight(4)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var game := SongGame.new(e)
	e.game = game
	var early := e.items.find_power(hero, "test_heirloom", "early")
	assert_eq(e.items.specials.why(hero, early), "", "the game answers")
	assert_eq(game.asked, 1)
	assert_true(e.items.specials.use(hero, early, [got[2]], Vector2.INF, Vector2.ZERO, 0, {}).ok)
	assert_eq(game.used, 1, "and uses it")
	e.items.specials.why(hero, e.items.find_power(hero, "test_heirloom", "other"))
	assert_eq(game.asked, 1, "an id it doesn't claim stays the engine's")


func test_a_pierced_condition_lands_through_immunity() -> void:
	var m := TestChars.dummy(20)
	m.base_condition_immunities.append("charmed")
	assert_false(m.add_condition(&"charmed", "test"), "immune")
	assert_true(m.add_condition(&"charmed", "test", true), "pierced: it lands")
	var m2 := TestChars.dummy(20)
	m2.base_condition_immunities.append("charmed")
	var fx := Effect.new("Test Song", &"item", "test_heirloom").with_condition(&"charmed")
	assert_false(m2.add_effect(fx), "an ordinary effect is turned away")
	var fx2 := Effect.new("Test Song", &"item", "test_heirloom").with_condition(&"charmed")
	fx2.data["pierce"] = true
	assert_true(m2.add_effect(fx2), "one with pierce lands")
	assert_true(m2.has_condition(&"charmed"))
