extends TestCase
## Openings a creature can be thrown out of (an encounter's `openings`, a trait's `throws_out`; FightOpenings): a held
## foe by a window goes out of it, falls the drop (more while the building is aloft), and climbs back in on its turn.

const BLOCK := {"id": "test_thrower", "name": "Test Thrower", "size": "medium",
	"traits": [{"id": "test_throw", "name": "Test Throw", "throws_out": {}}],
	"actions": [{"id": "claw", "name": "Claw", "kind": "melee", "attack": {"bonus": 5, "reach": 5}, "damage": [{"dice": "1d4", "type": "slashing"}]}]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var thrower := e.add(TestChars.dummy(100, false, BLOCK.duplicate(true)), &"enemy", Vector2i(3, 3))
	e.openings.set_openings([{"name": "the test window", "cells": [[1, 3]], "drop_ft": 20, "aloft": {"flag": "test_aloft", "drop_ft": 60},
		"climb": {"skill": "athletics", "dc": 5}}])
	TestCombat.start_with(e, thrower)
	return [e, hero, thrower]


func test_only_a_held_foe_by_a_window() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var thrower := got[2] as Combatant
	assert_true(e.openings.throw_why(thrower, hero).contains("isn't held"))
	hero.creature.add_condition(&"restrained", "test")
	assert_eq(e.openings.throw_why(thrower, hero), "")
	hero.cell = Vector2i(4, 4)
	thrower.cell = Vector2i(5, 4)
	assert_eq(e.openings.throw_why(thrower, hero), "Not by an opening")


func test_out_of_the_window_and_back_in() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var thrower := got[2] as Combatant
	hero.creature.add_condition(&"paralyzed", "test")
	var hp := hero.creature.hp
	assert_true(e.openings.ai_throw(thrower).ok)
	assert_true(hero.has_meta(FightOpenings.OUT), "outside")
	assert_eq(hero.cell, SpellSpecials.BANISHED_CELL)
	assert_true(hero.creature.hp < hp, "20 ft of fall")
	assert_false(thrower.action_available, "it took the action")
	hero.creature.remove_condition(&"paralyzed", "test")
	TestCombat.next_d20(e, 20)
	e.openings.turn_start(hero)
	assert_false(hero.has_meta(FightOpenings.OUT), "climbed back in")
	assert_true(e.grid.distance_ft(hero.cell, 1, Vector2i(1, 3), 1) <= 5, "by the window")


func test_aloft_the_drop_is_longer() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var op := e.openings.list[0]
	assert_eq(e.openings.drop_ft(op), 20)
	e.legendary.story_flags["test_aloft"] = true
	assert_eq(e.openings.drop_ft(op), 60)
