extends TestCase
## A free-fall fight (an encounter's `free_fall`; Encounter.free_fall): everyone falls together on one plane, so nobody
## flies up or down and teleports fail.


func _fight(free: bool) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var c := TestCombat.caster_with(e, ["misty_step"], Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	e.free_fall = free
	TestCombat.start_with(e, c)
	return [e, c]


func test_misty_step_goes_nowhere() -> void:
	var got := _fight(true)
	var e := got[0] as Encounter
	var c := got[1] as Combatant
	e.spells.cast(c, "misty_step", 2, [], Vector2(6.5, 3.5))
	assert_eq(c.cell, Vector2i(2, 3), "still where it was")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("nowhere to step to")))


func test_misty_step_works_on_firm_ground() -> void:
	var got := _fight(false)
	var e := got[0] as Encounter
	var c := got[1] as Combatant
	e.spells.cast(c, "misty_step", 2, [], Vector2(6.5, 3.5))
	assert_eq(c.cell, Vector2i(6, 3))


func test_nobody_flies_up_or_down() -> void:
	var got := _fight(true)
	var e := got[0] as Encounter
	var c := got[1] as Combatant
	assert_true(e.movement.vertical_why(c, 5).contains("falling together"))
