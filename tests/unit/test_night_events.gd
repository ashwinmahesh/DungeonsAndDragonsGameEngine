extends TestCase
## Named night events (NightEvents, data/camp/night_events.json): a real Long Rest in a place they name, while their
## condition holds, breaks before its benefits as the campaign's visit does; the game plays the dialogue, then the party
## sleeps on.

const EVENTS := {"id": "night_events", "events": [
	{"id": "swarm", "locations": ["test_inn"], "when": "flag.plague_on", "dialogue": "test/night:swarm",
		"text": "The floorboards crawl."},
	{"id": "forest_chain", "regions": ["test_forest"], "once": false, "when": "not flag.forest_done",
		"dialogue": "test/night:chain"},
]}

var _locations: Dictionary = {}


func before_each() -> void:
	NightEvents.use(EVENTS)
	var locs := Compendium.shared().table("locations")
	_locations = locs.duplicate()
	locs["test_glade"] = {"id": "test_glade", "region": "test_forest"}
	Compendium.shared().tables["locations"] = locs


func after_each() -> void:
	NightEvents.use({})
	Compendium.shared().tables["locations"] = _locations


func _state(at: String) -> StoryState:
	var st := StoryState.new()
	st.party = [TestChars.pregen("silvain_aster", 3)] as Array[Character]
	st.location = at
	return st


func test_an_event_breaks_the_rest_before_its_benefits_and_the_party_sleeps_on() -> void:
	var st := _state("test_inn")
	st.flags["plague_on"] = true
	var hero := st.party[0]
	hero.hp = 1
	var res := LongRest.take(st, "safe", DiceRoller.new(1))
	assert_eq(str(res["how"]), LongRest.VISIT)
	assert_eq(str(res["text"]), "The floorboards crawl.")
	assert_eq(hero.hp, 1, "no benefits yet")
	assert_eq(str(LongRest.night_event(st).get("dialogue", "")), "test/night:swarm")
	assert_true(LongRest.event_waiting(st))
	LongRest.event_played(st)
	assert_false(LongRest.event_waiting(st), "its dialogue has started")
	var after := LongRest.resume(st, DiceRoller.new(1))
	assert_eq(str(after["how"]), LongRest.SLEPT)
	assert_eq(hero.hp, hero.max_hp(), "the benefits after it")
	assert_eq(str(LongRest.take(st, "safe", DiceRoller.new(1))["how"]), LongRest.SLEPT, "a once event comes once")


func test_place_and_condition_must_hold() -> void:
	var st := _state("test_inn")
	assert_eq(str(LongRest.take(st, "safe", DiceRoller.new(1))["how"]), LongRest.SLEPT, "its condition doesn't hold")
	st = _state("elsewhere")
	st.flags["plague_on"] = true
	assert_true(NightEvents.due(st, DiceRoller.new(1)).is_empty(), "not its place")


func test_a_region_event_that_repeats_while_its_condition_holds() -> void:
	var st := _state("test_glade")
	assert_eq(str(NightEvents.due(st, DiceRoller.new(1)).get("id", "")), "forest_chain")
	assert_eq(str(NightEvents.due(st, DiceRoller.new(1)).get("id", "")), "forest_chain", "not once")
	st.flags["forest_done"] = true
	assert_true(NightEvents.due(st, DiceRoller.new(1)).is_empty())


func test_no_file_no_events() -> void:
	NightEvents.use({"events": []})
	var st := _state("test_glade")
	assert_eq(str(LongRest.take(st, "safe", DiceRoller.new(1))["how"]), LongRest.SLEPT)
