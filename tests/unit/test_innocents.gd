extends TestCase
## Innocents in peril (Encounter.INNOCENT, a meter action's `rescue`, `store_add`): foes hunt a bystander, a hero's
## rescue takes it out of the fight saved, and the tallies add up in the story.

const METERS := [
	{"id": "saved", "label": "Saved", "store": "test_saved", "store_add": true,
		"actions": [{"id": "pull", "label": "Pull a villager free", "near": "Test Villager", "range": 5, "rescue": true}]},
	{"id": "slain", "label": "Slain", "store": "test_slain", "store_add": true,
		"on": [{"event": "defeat", "who": ["Test Villager"]}]}]


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	var near := e.add(TestChars.dummy(5, false, {"name": "Test Villager"}), &"neutral", Vector2i(3, 3))
	var far := e.add(TestChars.dummy(5, false, {"name": "Test Villager"}), &"neutral", Vector2i(9, 5))
	for v in [near, far]:
		(v as Combatant).set_meta(Encounter.INNOCENT, true)
	e.meters.setup(METERS.duplicate(true))
	TestCombat.start_with(e, hero)
	return [e, hero, foe, near, far]


func test_foes_hunt_innocents_and_the_party_counts_them_friends() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var foe := got[2] as Combatant
	var near := got[3] as Combatant
	assert_true(foe.hostile_to(near), "the foe hunts it")
	assert_true(e.hostiles_of(foe).has(near))
	assert_false((got[1] as Combatant).hostile_to(near), "the party doesn't")
	assert_false(near.hostile_to(foe), "it fights nobody")


func test_a_rescue_saves_the_nearest_and_the_tallies_go_to_the_story() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var cat := ActionCatalog.new(e)
	assert_true(cat.perform(hero, cat.find(hero, "meter:saved:pull")).ok)
	assert_eq(str((got[3] as Combatant).get_meta("left_fight", "")), "rescued", "the one beside the hero is saved")
	assert_false((got[4] as Combatant).has_meta("left_fight"), "the far one isn't")
	e.deal_damage(null, got[4] as Combatant, [{"amount": 50, "type": "slashing"}], false, "Test", [])
	e.meters.scan()
	assert_eq([e.meters.value("saved"), e.meters.value("slain")], [1, 1])
	e.meters.store_values()
	assert_eq(e.legendary.story_flags["test_saved"], {"add": 1}, "added to what the story has")
	assert_eq(e.legendary.story_flags["test_slain"], {"add": 1})
