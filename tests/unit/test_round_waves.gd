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
