extends TestCase
## A guide who leads without a word (an NPC placement's or entry's `leads`; LocationInteraction.lead_of,
## docs/contracts/locations.md): Follow on its menu while `when` holds; the placement's own wins over the entry's.


func _view() -> LocationView:
	var view := LocationView.new()
	view.st = StoryState.new()
	view.loc = {"id": "test_bayou", "region": ""}
	return view


func test_a_placement_offers_its_lead_while_its_when_holds() -> void:
	var view := _view()
	var spec := {"npc": "test_mute_guide", "cell": [1, 1], "leads": {"to": "test_shack", "when": "flag.test_guide_ready", "flag": "test_followed"}}
	assert_true(LocationInteraction.lead_of(view, spec).is_empty(), "not before its when")
	view.st.set_flag("test_guide_ready")
	assert_eq(str(LocationInteraction.lead_of(view, spec)["to"]), "test_shack")
	view.free()


func test_no_leads_no_follow() -> void:
	var view := _view()
	assert_true(LocationInteraction.lead_of(view, {"npc": "test_mute_guide", "cell": [1, 1]}).is_empty())
	assert_true(LocationInteraction.lead_of(view, {"npc": "test_mute_guide", "cell": [1, 1], "leads": {"to": ""}}).is_empty(), "a lead goes somewhere")
	view.free()


func test_the_npc_entry_leads_wherever_it_is_placed() -> void:
	var view := _view()
	var table := Compendium.shared().table("npcs")
	table["test_mute_guide"] = {"id": "test_mute_guide", "name": "Test Guide", "leads": {"to": "test_dock"}}
	assert_eq(str(LocationInteraction.lead_of(view, {"npc": "test_mute_guide", "cell": [1, 1]})["to"]), "test_dock")
	assert_eq(str(LocationInteraction.lead_of(view, {"npc": "test_mute_guide", "cell": [1, 1], "leads": {"to": "test_shack"}})["to"]),
		"test_shack", "the placement's own wins")
	table.erase("test_mute_guide")
	view.free()
