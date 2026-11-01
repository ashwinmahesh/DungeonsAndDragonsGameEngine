extends TestCase
## Ground that harms whoever stays in it (a location area's `hazard`; AreaHazards): Difficult Terrain, a save at the end
## of a turn in it, a condition that lasts only while inside, and the creature types it spares.

const LOC := {"areas": [{"id": "test_pool", "name": "the test pool", "cells": [[4, 2], [6, 4]],
	"hazard": {"difficult": true, "save": {"ability": "con", "dc": 40}, "condition": "poisoned", "except_types": ["undead"]}}]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 3), 5)
	var ghoul := e.add(TestChars.dummy(50, false, {"id": "test_ghoul", "name": "Test Ghoul", "type": "undead"}), &"enemy", Vector2i(4, 2))
	TestCombat.punching_bag(e, Vector2i(12, 7), 300)
	e.zones.from_location(LOC)
	TestCombat.start_with(e, hero)
	return [e, hero, ghoul]


func test_its_squares_are_difficult() -> void:
	var e := _fight()[0] as Encounter
	assert_true(e.grid.has_flag(Vector2i(5, 3), CombatGrid.DIFFICULT))
	assert_false(e.grid.has_flag(Vector2i(7, 3), CombatGrid.DIFFICULT))


func test_ending_a_turn_in_it_poisons_only_while_inside() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	e.zones.turn_end(hero)
	assert_true(hero.creature.has_condition(&"poisoned"), "failed the save")
	e.zones.turn_end(hero)
	assert_eq((hero.creature.conditions[&"poisoned"] as Array).size(), 1, "once")
	e.move(hero, Vector2i(8, 3))
	assert_false(hero.creature.has_condition(&"poisoned"), "out of it, no longer poisoned")


func test_it_spares_the_types_it_names() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var ghoul := got[2] as Combatant
	e.zones.turn_end(ghoul)
	assert_false(ghoul.creature.has_condition(&"poisoned"))


func test_a_turn_ending_outside_does_nothing() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	hero.cell = Vector2i(9, 6)
	e.zones.turn_end(hero)
	assert_false(hero.creature.has_condition(&"poisoned"))
