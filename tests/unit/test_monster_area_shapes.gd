extends TestCase
## Monster save actions by the shape of their area (MonsterActions.area_cells, _charge): a sphere hurled at a target
## within range lands round the target, and a `path` charges straight through whoever is in the way.


func _boulder() -> Dictionary:
	return {"id": "test_hurl", "name": "Test Hurl", "kind": "save", "save": {"ability": "dex", "dc": 40}, "area": {"shape": "sphere", "size": 10},
		"targets": {"range": 120}, "damage": [{"dice": "1d6", "type": "bludgeoning"}],
		"on_fail": [{"do": "condition", "condition": "prone", "until": "permanent"}]}


func test_a_hurled_sphere_lands_round_its_target() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var thrower := e.add(TestChars.dummy(100, false, {"name": "Test Thrower", "actions": [_boulder()]}), &"enemy", Vector2i(0, 0))
	var far := TestCombat.hero(e, "hedda_ironvow", Vector2i(10, 6), 3)
	var cells := e.monster_actions.area_cells(thrower, _boulder(), far)
	assert_true(far.cell in cells, "round the target, 50 ft off")
	assert_false(thrower.cell in cells, "not round the thrower")


func test_a_charge_goes_through_and_knocks_down() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var act := {"id": "test_charge", "name": "Test Charge", "kind": "save", "save": {"ability": "str", "dc": 40},
		"area": {"shape": "path", "size": 40}, "targets": {"in_path": true}, "damage": [{"dice": "1d6", "type": "force"}],
		"on_fail": [{"do": "condition", "condition": "prone", "until": "permanent"}]}
	var bull := e.add(TestChars.dummy(100, false, {"name": "Test Bull", "actions": [act]}), &"enemy", Vector2i(1, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 3)
	TestCombat.start_with(e, bull)
	e.monster_actions.save_action(bull, act, hero, CombatResult.new(), false)
	assert_true(hero.creature.has_condition(&"prone"), "trampled")
	assert_true(bull.cell.x > hero.cell.x, "through and past (%s)" % bull.cell)
	assert_true(e.events.any(func(ev: Dictionary) -> bool: return str(ev["type"]) == "move" and ev.has("charge")))
