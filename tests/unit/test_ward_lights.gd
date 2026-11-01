extends TestCase
## A guest's warding light (an NPC's `ward_light`; WardLights): it lights the field, keeps the creatures it names out
## and puts them at Disadvantage inside.

const SPEC := {"radius": 10, "bright": 10, "dim": 10, "keep_out": ["test_shade"], "disadvantage": ["test_shade"]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	e.ambient_light = "dark"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var shade := e.add(TestChars.dummy(50, false, {"id": "test_shade", "name": "Test Shade"}), &"enemy", Vector2i(9, 3))
	WardLights.place(e, Vector2i(3, 3), SPEC, "Test Keeper")
	TestCombat.start_with(e, shade)
	return [e, hero, shade]


func test_it_lights_the_field() -> void:
	var e := _fight()[0] as Encounter
	assert_eq(e.light_at(Vector2i(4, 3)), "bright")
	assert_eq(e.light_at(Vector2i(7, 3)), "dim")


func test_the_named_cant_step_in() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var shade := got[2] as Combatant
	var reach := e.reachable_for(shade, 30)
	assert_false(reach.has(Vector2i(4, 3)), "inside the light")
	assert_true(reach.has(Vector2i(7, 3)), "outside it")


func test_disadvantage_inside() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var shade := got[2] as Combatant
	var hero := got[1] as Combatant
	assert_true(WardLights.disadvantage(e, shade).is_empty(), "outside")
	shade.cell = Vector2i(4, 4)
	assert_eq(WardLights.disadvantage(e, shade).size(), 1)
	assert_true(shade.creature.roll_save(e.dice, &"dex", 10).disadvantage)
	assert_true(WardLights.disadvantage(e, hero).is_empty(), "only those it names")
