extends TestCase
## Patrols (a waiting foe's `path`; LocationStealth.advance_patrols): the foe walks its round a square at a time, stands
## at its waypoints, turns its sight cone the way it goes, and holds while a hero is in its way.


func _view(hero_cell: Vector2i) -> Array:
	var view := LocationView.new()
	view.st = StoryState.new()
	var rows: Array[String] = []
	for z in 8:
		rows.append("....................")
	view.grid = CombatGrid.from_rows(rows)
	view.members.append(Combatant.new(TestChars.pregen("hedda_ironvow", 3), &"party", hero_cell))
	var foe := Combatant.new(TestChars.dummy(20, false, {"id": "test_guard", "name": "Test Guard"}), &"enemy", Vector2i(2, 2))
	var route: Array[Dictionary] = [{"cell": Vector2i(3, 2), "pause": 0.0}, {"cell": Vector2i(4, 2), "pause": 2.0},
		{"cell": Vector2i(3, 2), "pause": 0.0}, {"cell": Vector2i(2, 2), "pause": 0.0}]
	view.waiting.append({"encounter": "test_watch", "foe": foe, "token": null, "low": [], "facing": Vector2.LEFT, "route": route,
		"at": 0, "wait": 0.0, "clock": 0.0})
	return [view, foe]


func test_it_walks_its_round_and_turns_its_cone() -> void:
	var got := _view(Vector2i(9, 7))
	var view := got[0] as LocationView
	var foe := got[1] as Combatant
	assert_true(LocationStealth.advance_patrols(view, NpcRoutes.STEP_TIME))
	assert_eq(foe.cell, Vector2i(3, 2))
	assert_eq(view.waiting[0]["facing"], Vector2.RIGHT, "looking the way it walks")
	LocationStealth.advance_patrols(view, NpcRoutes.STEP_TIME)
	assert_eq(foe.cell, Vector2i(4, 2), "at the waypoint")
	assert_false(LocationStealth.advance_patrols(view, NpcRoutes.STEP_TIME), "standing there a while")
	LocationStealth.advance_patrols(view, 2.0)
	LocationStealth.advance_patrols(view, NpcRoutes.STEP_TIME)
	assert_eq(foe.cell, Vector2i(3, 2), "and back")
	assert_eq(view.waiting[0]["facing"], Vector2.LEFT)
	view.free()


func test_it_holds_while_a_hero_is_in_its_way() -> void:
	var got := _view(Vector2i(3, 2))
	var view := got[0] as LocationView
	var foe := got[1] as Combatant
	assert_false(LocationStealth.advance_patrols(view, NpcRoutes.STEP_TIME))
	assert_eq(foe.cell, Vector2i(2, 2))
	view.free()
