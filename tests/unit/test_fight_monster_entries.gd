extends TestCase
## A fight entry's creatures go on the board once each (LocationFights.add_monsters), whatever they carry: an ally on
## the party's side, a nonlethal one, one that turns only when harmed, a rider seated on its steed.


func test_each_entry_is_added_once_with_all_it_carries() -> void:
	var view := LocationView.new()
	view.st = StoryState.new()
	view.loc = {"id": "test_field", "region": ""}
	var e := TestCombat.open_field(3)
	var spec := {"id": "test_fight", "monsters": [
		{"monster": "wolf", "cell": [6, 1], "name": "Test Steed"},
		{"monster": "wolf", "cell": [6, 2], "name": "Test Rider", "rides": "Test Steed"},
		{"monster": "wolf", "cell": [6, 4], "name": "Test Militia", "side": "ally"},
		{"monster": "wolf", "cell": [6, 5], "name": "Test Reveller", "nonlethal": true, "hostile_if_harmed": true, "side": "neutral"}]}
	var by_name := LocationFights.add_monsters(view, e, spec)
	assert_eq(e.combatants.size(), 4, "four entries, four creatures")
	assert_eq(by_name.size(), 4)
	assert_eq((by_name["Test Militia"] as Combatant).side, &"guest", "an ally fights as a guest")
	var reveller := by_name["Test Reveller"] as Combatant
	assert_true(reveller.has_meta(Encounter.NONLETHAL))
	assert_true(reveller.has_meta(Encounter.PROVOKED_BY_HARM))
	assert_eq(e.mounts.mount_of(by_name["Test Rider"] as Combatant), by_name["Test Steed"], "the rider is in the saddle")
	view.free()
