extends TestCase
## A boss in the saddle (a location monster entry's `rides`; EncounterMounts.seat): on its steed's space, carried when the
## steed moves, the two on one Initiative count, each with its own turn.


func test_seated_carried_and_on_one_initiative() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3), 3)
	var brute := e.add(TestChars.dummy(80, false, {"id": "test_brute", "name": "Test Brute", "size": "huge", "speed": {"walk": 30}}), &"enemy", Vector2i(7, 3))
	var matron := e.add(TestChars.dummy(60, false, {"id": "test_matron", "name": "Test Matron"}), &"enemy", Vector2i(10, 6))
	e.mounts.seat(matron, brute)
	assert_eq(matron.cell, brute.cell, "on its back")
	e.start()
	assert_eq(matron.initiative, brute.initiative, "one Initiative")
	assert_true(e.order.has(matron) and e.order.has(brute), "each takes its own turn")
	e.turn_index = e.order.find(brute)
	var from := brute.cell
	brute.movement_left = 30
	e.movement.move(brute, from + Vector2i(-1, 0))
	assert_eq(matron.cell, brute.cell, "carried as it moves")
	assert_eq(e.mount_of(matron), brute)
	assert_true(hero.is_alive())

