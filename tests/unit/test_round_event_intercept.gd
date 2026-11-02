extends TestCase
## A round event's `intercept`: the nearest hero within their Speed may take the strike meant for a captive.

const EVENT := {"id": "test_bonfire", "name": "The bonfire", "kind": "strike", "kill": true, "damage": {"type": "fire"},
	"affects": "all", "area": {"cells": [[6, 3]]}, "one": true, "at": 0, "every": 1,
	"intercept": {"save": {"ability": "dex", "dc": 40}, "damage": {"dice": "2d6", "type": "fire"}, "half": true}}


func _fight(reaction: String) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = reaction
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 5)
	TestCombat.punching_bag(e, Vector2i(10, 6), 300)
	var captive := e.add(TestChars.dummy(20, false, {"name": "Test Captive"}), &"guest", Vector2i(6, 3))
	e.legendary.set_round_events([EVENT.duplicate(true)])
	TestCombat.start_with(e, hero)
	return [e, hero, captive]


func _to_event(e: Encounter) -> void:
	for i in 12:
		if e.pending != null or e.events.any(func(ev: Dictionary) -> bool: return str(ev.get("type", "")) == "round_event"):
			return
		e.end_turn()


func test_a_hero_takes_the_flame_instead() -> void:
	var got := _fight("ask")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var captive := got[2] as Combatant
	_to_event(e)
	assert_true(e.pending != null and e.pending.kind == "intercept", "asked")
	var hp := hero.creature.hp
	e.answer_reaction(true)
	assert_true(captive.is_alive(), "the captive is spared")
	assert_true(hero.creature.hp < hp, "the hero takes it")
	assert_false(hero.reaction_available)
	assert_true(e.distance(hero, captive) <= 5, "beside the captive")


func test_declined_the_captive_burns() -> void:
	var got := _fight("ask")
	var e := got[0] as Encounter
	_to_event(e)
	e.answer_reaction(false)
	assert_false((got[2] as Combatant).is_alive(), "the flame takes the captive")
