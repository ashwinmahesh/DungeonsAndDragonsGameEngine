extends TestCase
## What a fog-walker's elixir needs: item spell powers with no Concentration (`no_concentration`), one that works only
## into or out of a spell's zone (`in_zone`), and eyes that see through fog (`sees_through_fog`).


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var bag := TestCombat.punching_bag(e, Vector2i(10, 3), 300)
	var fx := Effect.new("Test Elixir", &"item", "test_elixir")
	fx.data["powers"] = [
		{"id": "fog", "name": "Fog", "spell": "fog_cloud", "cost": "magic", "no_concentration": true, "uses": {"count": 3, "per": "never"}},
		{"id": "step", "name": "Step", "spell": "misty_step", "cost": "bonus", "in_zone": "fog_cloud", "uses": {"count": 3, "per": "never"}}]
	fx.data["id"] = "test_elixir"
	hero.creature.add_effect(fx)
	TestCombat.start_with(e, hero)
	return [e, hero, bag]


func test_fog_without_concentration_and_a_step_out_of_it() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var r0 := e.items.use(hero, "test_elixir", "step", [], Vector2(5.5, 3.5))
	assert_false(r0.ok, "no fog yet: %s" % r0.reason)
	var r := e.items.use(hero, "test_elixir", "fog", [], Vector2(2.5, 3.5))
	assert_true(r.ok, r.reason)
	assert_true(hero.creature.concentration == null, "no Concentration")
	hero.creature.add_effect(Effect.new("Test Eyes", &"item", "test_eyes").with_modifier("flag", {"value": "sees_through_fog"}))
	var r2 := e.items.use(hero, "test_elixir", "step", [], Vector2(6.5, 3.5))
	assert_true(r2.ok, r2.reason)
	assert_eq(hero.cell, Vector2i(6, 3), "out of the fog")


func test_eyes_that_see_through_fog() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var bag := got[2] as Combatant
	assert_true(e.items.use(hero, "test_elixir", "fog", [], Vector2(6.5, 3.5)).ok)
	assert_false(e.can_see(hero, bag), "the fog hides it")
	hero.creature.add_effect(Effect.new("Test Eyes", &"item", "test_eyes").with_modifier("flag", {"value": "sees_through_fog"}))
	assert_true(e.can_see(hero, bag), "not from these eyes")


func test_a_drink_grants_modifiers_with_its_powers() -> void:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	TestCombat.punching_bag(e, Vector2i(10, 3), 300)
	TestCombat.start_with(e, hero)
	var p := {"item_id": "test_elixir", "data": {"name": "Test Elixir"}, "entry": {},
		"power": {"id": "drink", "grants": {"minutes": 10, "powers": [], "modifiers": [{"stat": "flag", "value": "sees_through_fog"}]}}}
	e.items._grant(hero, hero, p)
	assert_true(hero.creature.has_flag("sees_through_fog"))
