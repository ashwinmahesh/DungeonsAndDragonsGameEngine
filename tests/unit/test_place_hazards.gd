extends TestCase
## Places whose air harms whoever stays (a location's `hazard`; PlaceHazards): a save on entering and every ten minutes
## inside, Poisoned on a failure, then an hourly save wherever they go that adds Exhaustion until one succeeds.

var _fx := FixtureContent.new()


func _place(dc: int, lasting_dc_note: String = "") -> void:
	_fx.add("locations", {"id": "test_haze", "name": "Test Haze", "map": {"rows": ["...."]},
		"hazard": {"name": "the test haze", "every_min": 10, "save": {"ability": "con", "dc": dc}, "condition": "poisoned",
			"lasting": {"every_min": 60, "exhaustion": 1}, "immune_flags": ["test_marked"], "when": "not flag.test_cleared"}})


func after_each() -> void:
	_fx.restore()


func _party() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("hedda_ironvow", 5))
	st.party.append(TestChars.pregen("ilse_varga", 5))
	st.location = "test_haze"
	return st


func test_entering_poisons_and_the_hours_tire() -> void:
	_place(40)
	var st := _party()
	PlaceHazards.entered(st)
	for ch in st.party:
		assert_true(ch.has_condition(&"poisoned"), "%s fails DC 40" % ch.name)
	assert_eq(PlaceHazards.drain(st).size(), 2, "a line each")
	st.advance_minutes(60)
	for ch in st.party:
		assert_eq(ch.exhaustion, 1, "an hour on: a level of Exhaustion")
	st.location = "elsewhere"
	PlaceHazards.entered(st)
	st.advance_minutes(60)
	assert_eq((st.party[0] as Character).exhaustion, 2, "it goes on away from the place")


func test_an_easy_save_and_the_story_clearing_it() -> void:
	_place(1)
	var st := _party()
	PlaceHazards.entered(st)
	st.advance_minutes(30)
	assert_false((st.party[0] as Character).has_condition(&"poisoned"), "DC 1: never")
	_fx.restore()
	_place(40)
	st.flags["test_cleared"] = true
	PlaceHazards.entered(st)
	assert_false((st.party[0] as Character).has_condition(&"poisoned"), "the source is gone")


func test_the_marked_are_spared() -> void:
	_place(40)
	var st := _party()
	var fx := Effect.new("Test Mark", &"feature", "test_mark").with_modifier("flag", {"value": "test_marked"})
	(st.party[0] as Character).add_effect(fx)
	PlaceHazards.entered(st)
	assert_false((st.party[0] as Character).has_condition(&"poisoned"))
	assert_true((st.party[1] as Character).has_condition(&"poisoned"))
