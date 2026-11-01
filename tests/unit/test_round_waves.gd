extends TestCase
## Round events in waves (combat/round_events.gd): a table taken once each in turn (`pick: "sequence"`), and an outcome
## that waits while enough of a kind stand (`unless_count`).


func _fight(events: Array) -> Encounter:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1), 5)
	TestCombat.punching_bag(e, Vector2i(11, 7), 500)
	e.legendary.set_round_events(events)
	TestCombat.start_with(e, hero)
	return e


func _count(e: Encounter, id: String) -> int:
	return e.combatants.filter(func(c: Combatant) -> bool: return c.creature is Monster and str((c.creature as Monster).data.get("id", "")) == id).size()


func test_one_arrival_a_round_then_no_more() -> void:
	var e := _fight([{"id": "test_arrivals", "kind": "summon", "at": 20, "every": 1, "pick": "sequence", "table": [
		{"id": "a", "kind": "summon", "monster": "rat", "count": 1, "side": "enemies", "cells": [[8, 4]]},
		{"id": "b", "kind": "summon", "monster": "raven", "count": 1, "side": "enemies", "cells": [[8, 5]]}]}])
	for i in 12:
		e.end_turn()
	assert_eq(_count(e, "rat"), 1, "the first, once")
	assert_eq(_count(e, "raven"), 1, "the second, once, and nothing after")


func test_none_while_enough_stand() -> void:
	var e := _fight([{"id": "test_dance", "kind": "summon", "monster": "rat", "count": 1, "side": "enemies", "cells": [[8, 4]], "at": 20, "every": 1,
		"unless_count": {"who": ["rat"], "at_least": 2}}])
	for i in 12:
		e.end_turn()
	assert_eq(_count(e, "rat"), 2, "joins until there are two")


func test_a_pelting_with_no_save_for_a_round() -> void:
	var e := _fight([{"id": "test_pelt", "kind": "effect", "affects": "party", "one": true, "at": 20, "every": 1, "until": "round",
		"modifiers": [{"stat": "attack", "value": -2}]}])
	var hero := e.combatants[0]
	e.legendary.round_events.act(e.legendary.round_events.events[0], false)
	assert_true(hero.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id.begins_with("round_event:")), "pelted")


func test_ribbons_that_hold_until_a_save() -> void:
	var e := _fight([{"id": "test_ribbon", "kind": "save", "affects": "party", "at": 20, "every": 1, "save": {"ability": "str", "dc": 40},
		"repeat_save": true, "modifiers": [{"stat": "speed_set", "value": 0}]}])
	var hero := e.combatants[0]
	e.legendary.round_events.act(e.legendary.round_events.events[0], false)
	var fx: Effect = null
	for f in hero.creature.effects:
		if f.source_id.begins_with("round_event:"):
			fx = f
	assert_true(fx != null, "bound")
	assert_eq(hero.speed(), 0)
	assert_eq(str(fx.repeat_save.get("ability", "")), "str", "the save comes again")
