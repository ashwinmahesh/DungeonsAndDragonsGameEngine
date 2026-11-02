extends TestCase
## A ring of fire held up by stones (FightWalls): nobody inside gets out, stepping onto it burns, and it falls once
## enough of its stones are down.


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var inside := TestCombat.hero(e, "hedda_ironvow", Vector2i(6, 4), 5)
	var outside := TestCombat.hero(e, "thistle", Vector2i(6, 0), 5)
	TestCombat.punching_bag(e, Vector2i(11, 7), 300)
	var a := e.objects.put({"id": "test_stone_a", "kind": "vessel", "cell": [1, 1], "name": "a stone", "ac": 5, "hp": 5})
	var b := e.objects.put({"id": "test_stone_b", "kind": "vessel", "cell": [1, 7], "name": "a stone", "ac": 5, "hp": 5})
	e.walls = [{"name": "The ring of fire", "center": [6, 4], "radius": 2, "damage": {"dice": "2d6", "type": "fire"},
		"held_by": ["test_stone_a", "test_stone_b"], "falls_at": 2}]
	TestCombat.start_with(e, inside)
	return [e, inside, outside, a, b]


func test_nobody_inside_gets_out_until_the_stones_fall() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var inside := got[1] as Combatant
	var reach := e.movement.reachable_for(inside, 30)
	assert_false(reach.has(Vector2i(6, 2)), "not onto the ring")
	assert_false(reach.has(Vector2i(6, 1)), "nor past it")
	assert_true(reach.has(Vector2i(6, 3)), "inside is fine")
	e.objects.damage(got[3] as BattleObject, [{"amount": 50, "type": "bludgeoning"}], null, "test")
	assert_false(e.movement.reachable_for(inside, 30).has(Vector2i(6, 1)), "one stone down of two: still up")
	e.objects.damage(got[4] as BattleObject, [{"amount": 50, "type": "bludgeoning"}], null, "test")
	assert_true(e.movement.reachable_for(inside, 30).has(Vector2i(6, 1)), "it falls")
	assert_true(e.events.any(func(ev: Dictionary) -> bool: return str(ev.get("type", "")) == "wall_down"))


func test_stepping_onto_it_from_outside_burns() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var outside := got[2] as Combatant
	assert_true(e.movement.reachable_for(outside, 30).has(Vector2i(6, 3)), "it can be crossed inward")
	var hp := outside.creature.hp
	var from := outside.cell
	outside.cell = Vector2i(6, 2)
	FightWalls.entered(e, outside, from)
	assert_true(outside.creature.hp < hp, "onto the ring: it burns")
	var again := outside.creature.hp
	FightWalls.entered(e, outside, Vector2i(6, 1))
	assert_eq(outside.creature.hp, again, "once a turn")
