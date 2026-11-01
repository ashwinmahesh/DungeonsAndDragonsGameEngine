extends TestCase
## Things a creature shuns (traits `shuns_running_water`, `shuns_item`; MonsterActions): it won't go into deep water and
## is hurt and frightened if it starts a turn there, and a mirror held up in its sight hinders it.

const BLOCK := {"id": "test_stalker", "name": "Test Stalker", "speed": {"walk": 30},
	"traits": [{"id": "test_water", "name": "Test Water", "shuns_running_water": {"damage": 10, "type": "acid", "condition": "frightened"}},
		{"id": "test_mirror", "name": "Test Mirror", "shuns_item": {"items": ["test_mirror"], "range": 30}}]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	for z in e.grid.depth:
		e.grid.set_flag(Vector2i(6, z), CombatGrid.WATER, true)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var stalker := e.add(TestChars.dummy(80, false, BLOCK.duplicate(true)), &"enemy", Vector2i(4, 3))
	TestCombat.start_with(e, stalker)
	return [e, hero, stalker]


func test_it_wont_cross_the_water() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var reach := e.reachable_for(got[2] as Combatant, 30)
	assert_false(reach.has(Vector2i(6, 3)), "not into the stream")
	assert_false(reach.has(Vector2i(8, 3)), "nor over it")


func test_in_the_water_it_burns_and_cowers() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var stalker := got[2] as Combatant
	stalker.cell = Vector2i(6, 3)
	var hp := stalker.creature.hp
	e.monster_actions.turn_start(stalker)
	assert_eq(stalker.creature.hp, hp - 10)
	assert_true(stalker.creature.has_condition(&"frightened"))


func test_a_mirror_held_up() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var stalker := got[2] as Combatant
	assert_false(stalker.creature.roll_save(e.dice, &"wis", 10).disadvantage)
	((got[1] as Combatant).creature as Character).add_item("test_mirror", 1)
	assert_true(stalker.creature.roll_save(e.dice, &"wis", 10).disadvantage, "its reflection in sight")
