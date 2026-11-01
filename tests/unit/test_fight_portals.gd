extends TestCase
## Paired squares that lead into each other (an encounter's `portals`; FightPortals): stepping onto one comes out on the
## other and the move ends; shoved onto one goes through too; a pair can wait for a fight flag.


func _fight(pair: Dictionary) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	TestCombat.punching_bag(e, Vector2i(11, 7), 300)
	e.portals.set_portals([pair])
	TestCombat.start_with(e, hero)
	return [e, hero]


func test_through_one_and_out_of_the_other() -> void:
	var got := _fight({"name": "a test window", "cells": [[4, 3], [10, 3]]})
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	e.move(hero, Vector2i(6, 3))
	assert_eq(hero.cell, Vector2i(10, 3), "out of the far window, and the move ends")


func test_shoved_through() -> void:
	var got := _fight({"cells": [[4, 3], [10, 3]]})
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	e.forced_move(hero, Vector2(1.5, 3.5), 10)
	assert_eq(hero.cell, Vector2i(10, 3))


func test_only_once_it_opens() -> void:
	var got := _fight({"cells": [[4, 3], [10, 3]], "when_flag": "test_broken"})
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	e.move(hero, Vector2i(4, 3))
	assert_eq(hero.cell, Vector2i(4, 3), "shut: just a square")
	e.legendary.story_flags["test_broken"] = true
	e.move(hero, Vector2i(5, 3))
	e.move(hero, Vector2i(4, 3))
	assert_eq(hero.cell, Vector2i(10, 3), "open now")
