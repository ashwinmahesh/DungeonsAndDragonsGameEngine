extends TestCase
## A loose creature the heroes can catch (a location monster entry's `catch: {flag}`; EncounterGrapples.catch_creature,
## docs/contracts/locations.md): one of a hero's attacks within 5 ft, a Str or Dex save against their grapple DC, and on
## a failure it is carried out of the fight with its flag for the story.


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(10, 6))
	var lamb := TestChars.dummy(4, false, {"name": "Lamb", "size": "small", "abilities": {"str": 1, "dex": 1, "con": 10, "int": 2, "wis": 10, "cha": 5}})
	lamb.set_meta(EncounterGrapples.CATCH, {"flag": "test_lamb_caught"})
	var critter := e.add(lamb, &"neutral", Vector2i(7, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, foe, critter]


func test_a_hero_near_it_can_catch_it_out_of_the_fight() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var lamb := got[3] as Combatant
	var cat := ActionCatalog.new(e)
	var act := cat.find(hero, "catch:" + lamb.id)
	assert_false(act.is_empty(), "the hotbar offers to catch it")
	assert_false(bool(act["legal"]), "not from across the field")
	assert_eq(str(act["reason"]), "Get within 5 ft first")
	hero.cell = Vector2i(6, 3)
	act = cat.find(hero, "catch:" + lamb.id)
	assert_true(bool(act["legal"]), "within 5 ft it can")
	TestCombat.next_d20(e, 2)
	assert_true(cat.perform(hero, act).ok)
	assert_eq(str(lamb.get_meta("left_fight", "")), "caught", "carried out of the fight")
	assert_true(bool(e.legendary.story_flags.get("test_lamb_caught", false)), "its flag goes to the story")
	assert_true(e.events.any(func(ev: Dictionary) -> bool: return str(ev["type"]) == "vanish" and str(ev.get("left", "")) == "caught"))
	assert_eq(hero.attacks_left, e.attacks_per_action(hero) - 1, "it took one of the hero's attacks")
	assert_eq(e.state, Encounter.State.ACTIVE, "the fight goes on")
	assert_true(cat.find(hero, "catch:" + lamb.id).is_empty(), "nothing left to catch")


func test_a_good_save_slips_away_and_spends_the_attack() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var lamb := got[3] as Combatant
	hero.cell = Vector2i(6, 3)
	TestCombat.next_d20(e, 20)
	assert_true(e.grappling.catch_creature(hero, lamb).ok)
	assert_false(lamb.has_meta("left_fight"), "it slipped away")
	assert_false(e.legendary.story_flags.has("test_lamb_caught"))
	assert_false(hero.action_available, "the try cost the Attack action")


func test_only_a_catchable_creature_can_be_caught() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	hero.cell = Vector2i(9, 6)
	assert_false(e.grappling.catch_creature(hero, foe).ok, "an ordinary foe is fought, not caught")
	assert_true(ActionCatalog.new(e).find(hero, "catch:" + foe.id).is_empty())


func test_the_place_marks_it_from_its_entry() -> void:
	var view := LocationView.new()
	view.st = StoryState.new()
	view.loc = {"id": "test_pasture", "region": ""}
	var spec := {"id": "test_wolves", "monsters": [{"monster": "wolf", "cell": [1, 1]},
		{"monster": "wolf", "cell": [5, 5], "side": "neutral", "name": "The Stray", "catch": {"flag": "test_stray_caught"}}]}
	var made := LocationFights.monsters_for(view, spec)
	assert_false((made[0]["creature"] as Monster).has_meta(EncounterGrapples.CATCH))
	assert_eq((made[1]["creature"] as Monster).get_meta(EncounterGrapples.CATCH), {"flag": "test_stray_caught"})
	assert_eq(made[1]["side"], &"neutral")
	view.free()
