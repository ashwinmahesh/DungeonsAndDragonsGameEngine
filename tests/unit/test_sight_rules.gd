extends TestCase
## A place's own sight rules in a fight (a location map's `sight`; EncounterSight): mist that hides what is beyond a
## distance, a gloom that halves every light and holds Darkvision short, and the creatures they spare.


func _fight(rule: Dictionary) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	e.ambient_light = "dark"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var far := e.add(TestChars.dummy(50, false, {"id": "test_lurker", "name": "Test Lurker", "type": "monstrosity",
		"senses": {"darkvision": 60}}), &"enemy", Vector2i(6, 3))
	e.sight_rule = rule
	TestCombat.start_with(e, hero)
	return [e, hero, far]


func test_a_darkvision_cap() -> void:
	var got := _fight({"darkvision_cap": 15})
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var far := got[2] as Combatant
	assert_true(hero.creature.darkvision() >= 60, "the hero has Darkvision")
	assert_false(e.can_see(hero, far), "20 ft away in the dark: past 15 ft of Darkvision")
	far.cell = Vector2i(4, 3)
	assert_true(e.can_see(hero, far), "10 ft: within it")


func test_those_it_spares_see_as_ever() -> void:
	var got := _fight({"darkvision_cap": 15, "immune": {"names": ["test_lurker"]}})
	var e := got[0] as Encounter
	assert_true(e.can_see(got[2] as Combatant, got[1] as Combatant), "the lurker's own Darkvision")
	assert_false(e.can_see(got[1] as Combatant, got[2] as Combatant))


func test_mist_hides_what_is_far() -> void:
	var got := _fight({"sight_ft": 15})
	var e := got[0] as Encounter
	e.ambient_light = "bright"
	assert_false(e.can_see(got[1] as Combatant, got[2] as Combatant), "20 ft into the mist")
	(got[2] as Combatant).cell = Vector2i(4, 3)
	assert_true(e.can_see(got[1] as Combatant, got[2] as Combatant))


func test_the_gloom_halves_every_light() -> void:
	var got := _fight({"light_scale": 0.5})
	var e := got[0] as Encounter
	var o := FieldObject.new(FieldObject.Kind.ZONE, "", "test_lamp")
	o.cell = Vector2i(10, 3)
	o.rules = {"light": {"bright": 20, "dim": 20}}
	e.spells.zones.objects.append(o)
	assert_eq(e.light_at(Vector2i(8, 3)), "bright", "10 ft: within half of 20")
	assert_eq(e.light_at(Vector2i(6, 3)), "dim", "20 ft: dim now")
	assert_eq(e.light_at(Vector2i(3, 3)), "dark", "35 ft: past half of 40")
