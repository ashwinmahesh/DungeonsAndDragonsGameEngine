extends TestCase
## The campaign's settings in data/campaign.json (Campaign.config, plan E1, E2, E22): each one a game leaves out keeps
## the engine's default; each one it names changes only what it names. Tests set them with Campaign.use_config.


func after_each() -> void:
	Campaign.use_config(null)


func _story() -> StoryState:
	var st := StoryState.new()
	st.party = [TestChars.pregen("silvain_aster", 5)] as Array[Character]
	return st


## The game's settings without `keys`, as if it had never named them.
func _without(keys: Array) -> void:
	var cfg := Campaign.config().duplicate(true)
	for k: Variant in keys:
		cfg.erase(k)
	Campaign._config = cfg


# --- The level cap -------------------------------------------------------------------------------------------------

func test_the_default_cap_is_eleven() -> void:
	_without(["level_cap"])
	assert_eq(Campaign.level_cap(), 11)
	assert_eq(Xp.level_for(900000), 11, "XP stops at the cap")
	assert_eq(StoryState.LEVEL_CAP, 11, "the old constant still reads")


func test_a_number_sets_the_cap() -> void:
	Campaign.use_config({"level_cap": 13})
	var st := _story()
	assert_eq(st.level_cap(), 13)
	assert_eq(Xp.level_for(900000, st.level_cap()), 13)
	st.milestones = 20
	assert_eq(st.story_level(), 13, "milestones stop at the cap")
	assert_eq(Xp.to_next(Xp.threshold(13), 13), 0, "nothing to the next level at the cap")


func test_the_story_raises_the_cap() -> void:
	Campaign.use_config({"level_cap": {"cap": 13, "raised": [{"when": "flag.endgame", "cap": 20}]}})
	var st := _story()
	st.milestones = 30
	assert_eq(st.story_level(), 13, "before the flag")
	assert_eq(Campaign.level_cap(), 13, "with no story, only the base cap")
	st.set_flag("endgame", true)
	assert_eq(st.level_cap(), 20)
	assert_eq(st.story_level(), 20, "the flag raises it")


func test_the_boon_limit() -> void:
	assert_eq(Campaign.boon_ability_max(), int(Campaign.config().get("boon_ability_max", 20)))
	Campaign.use_config({"boon_ability_max": 24})
	assert_eq(Campaign.boon_ability_max(), 24)


# --- Paths with the first game's defaults --------------------------------------------------------------------------

func test_paths_default_to_the_first_games() -> void:
	_without(Campaign.LEGACY.keys())
	for key: String in Campaign.LEGACY:
		assert_eq(Campaign.path(key), str(Campaign.LEGACY[key]), key)
	Campaign.use_config({"travel_map": "res://art/ui/map/elsewhere.png", "arena_encounter": "another_fight"})
	assert_eq(Campaign.path("travel_map"), "res://art/ui/map/elsewhere.png")
	assert_eq(CombatArena.encounter_id(), "another_fight")


func test_the_title_is_the_projects_name_by_default() -> void:
	_without(["title"])
	assert_eq(Campaign.title(), str(ProjectSettings.get_setting("application/config/name")))
	Campaign.use_config({"title": "Another Tale"})
	assert_eq(Campaign.title(), "Another Tale")


# --- The calendar --------------------------------------------------------------------------------------------------

func test_the_engines_day() -> void:
	_without(["calendar"])
	for spec: Array in [[5 * 60 + 59, true, "night"], [6 * 60, false, "dawn"], [7 * 60, false, "day"],
			[17 * 60 + 59, false, "day"], [18 * 60, false, "dusk"], [19 * 60, true, "night"], [0, true, "night"]]:
		assert_eq(Calendar.is_night(int(spec[0])), bool(spec[1]), "night at %d" % int(spec[0]))
		assert_eq(Calendar.phase(int(spec[0])), str(spec[2]), "phase at %d" % int(spec[0]))
	assert_eq(Calendar.clock(18 * 60 + 5), "18:05", "no hour names")
	assert_eq(Calendar.dawn_minute(), 6 * 60)
	assert_eq(Calendar.dusk_minute(), 18 * 60)
	assert_eq(Calendar.word("dawn"), "dawn")
	assert_eq(Calendar.start_minute(), 18 * 60)
	assert_eq(Calendar.moon(3), {"size": 1.0, "brightness": 1.0})


const NIGHTFALL := {"eternal_night": true, "dawn": "18:00", "dusk": "18:00", "words": {"dawn": "dusk"}, "start": "18:00",
	"hours": [{"from": "18:00", "name": "the Twilight Hour", "phase": "dusk"}, {"from": "22:00", "name": "the Witching Hour"},
		{"from": "02:00", "name": "the Dead Hour"}],
	"moon": {"size": 1.4, "brightness": 0.8, "nights": [{"brightness": 1.2}, {"size": 2.0}]}}


func test_an_eternal_night() -> void:
	Campaign.use_config({"calendar": NIGHTFALL})
	for m in [0, 6 * 60, 12 * 60, 18 * 60, 23 * 60]:
		assert_true(Calendar.is_night(m), "always night (%d)" % m)
	assert_eq(Calendar.phase(18 * 60 + 30), "dusk", "a named hour's phase sets its look")
	assert_eq(Calendar.phase(12 * 60), "night", "no day without a sun")
	assert_eq(Calendar.hour_name(23 * 60), "the Witching Hour")
	assert_eq(Calendar.hour_name(12 * 60), "the Dead Hour", "runs until the next named hour")
	assert_eq(Calendar.hour_name(17 * 60), "the Dead Hour")
	assert_eq(Calendar.hour_name(1 * 60), "the Witching Hour", "past midnight, before the day's first, the last still runs")
	assert_eq(Calendar.clock(22 * 60 + 15), "22:15 · the Witching Hour")
	assert_eq(Calendar.word("dawn"), "dusk")
	assert_eq(Calendar.dawn_minute(), Calendar.dusk_minute())
	assert_eq(Calendar.moon(1), {"size": 1.4, "brightness": 1.2}, "the first night's moon")
	assert_eq(Calendar.moon(2), {"size": 2.0, "brightness": 0.8})
	assert_eq(Calendar.moon(3), {"size": 1.4, "brightness": 1.2}, "the nights cycle")
	assert_eq(Calendar.minutes_of("the Dead Hour"), 2 * 60, "a named hour as a time")


func test_the_story_follows_the_calendar() -> void:
	Campaign.use_config({"calendar": NIGHTFALL})
	var st := _story()
	assert_eq(st.minute_of_day, 18 * 60, "a new game starts at the calendar's start")
	st.minute_of_day = 12 * 60
	assert_true(st.is_night())
	assert_true(StoryConditions.check("night", st))
	Campaign.use_config({"calendar": {"night": ["20:30", "05:00"]}})
	st.minute_of_day = 20 * 60
	assert_false(st.is_night())
	st.minute_of_day = 20 * 60 + 30
	assert_true(st.is_night())


func test_charges_come_back_at_the_calendars_dawn() -> void:
	Campaign.use_config({"calendar": {"dawn": "18:00"}})
	var st := _story()
	var ch := st.party[0]
	ch.add_item("wand_of_magic_missiles")
	assert_true(ch.spend_charges("wand_of_magic_missiles", 7))
	st.minute_of_day = 5 * 60
	st.advance_minutes(12 * 60)
	assert_eq(ch.charges_left("wand_of_magic_missiles"), 0, "nothing comes back at six in the morning")
	st.advance_minutes(2 * 60)
	assert_true(ch.charges_left("wand_of_magic_missiles") > 0, "the wand regains its charges at the calendar's dawn")


func test_shop_hours_take_named_hours() -> void:
	Campaign.use_config({"calendar": NIGHTFALL})
	var st := _story()
	var spec := {"hours": ["the Twilight Hour", "the Dead Hour"]}
	st.minute_of_day = 19 * 60
	assert_true(Schedule.in_hours(spec, st))
	st.minute_of_day = 3 * 60
	assert_false(Schedule.in_hours(spec, st))
	st.minute_of_day = 21 * 60
	assert_true(Schedule.in_hours({"hours": [8, 24]}, st), "an hour to midnight")
	assert_true(Schedule.in_hours({"hours": [0, 24]}, st), "all day")
	assert_false(Schedule.in_hours({"hours": [8, 20]}, st))


# --- Readings ------------------------------------------------------------------------------------------------------

func _deck(n: int) -> void:
	var cards: Array = []
	for i in n:
		cards.append({"id": "card_%02d" % i, "name": "Card %d" % i, "deck": "high" if i < 3 else "common"})
	Compendium.shared().tables["test_deck"] = {"cards": {"id": "cards", "cards": cards}}
	Campaign.use_config({"reading": {"deck": "test_deck", "art": "res://art/test_cards", "reader": "test_reader",
		"cards_per_hero": 1}})


func test_a_reading_deals_one_card_per_hero_without_repeats() -> void:
	_deck(22)
	var slots := ReadingDeck.hero_slots(4)
	assert_eq(slots, ["hero_1", "hero_2", "hero_3", "hero_4"] as Array[String])
	var a := ReadingDeck.draw(slots, 7)
	assert_eq(a.size(), 4)
	var seen := {}
	for s: String in a:
		assert_false(seen.has(a[s]), "no card twice")
		seen[a[s]] = true
		assert_false(ReadingDeck.card(str(a[s])).is_empty(), "every card is in the deck")
	assert_eq(ReadingDeck.draw(slots, 7), a, "the same seed deals the same reading")
	var other := false
	for seed_value in range(8, 20):
		if ReadingDeck.draw(slots, seed_value) != a:
			other = true
	assert_true(other, "other seeds deal other readings")
	Compendium.shared().tables.erase("test_deck")


func test_two_cards_per_hero_and_a_deck_part() -> void:
	_deck(22)
	Campaign.use_config({"reading": {"deck": "test_deck", "cards_per_hero": 2}})
	var slots := ReadingDeck.hero_slots(4)
	assert_eq(slots.size(), 8)
	assert_eq(slots[4], "hero_1b")
	assert_eq(ReadingDeck.draw(slots, 3).size(), 8)
	assert_eq(ReadingDeck.draw(slots, 3, "high"), {}, "too few high cards for every slot")
	assert_eq(ReadingDeck.draw(["a", "b"] as Array[String], 3, "high").size(), 2)
	assert_eq(ReadingDeck.art("card_01"), "", "no picture: the face shows the name")
	Compendium.shared().tables.erase("test_deck")


func test_a_campaigns_own_data_folder_loads_when_asked() -> void:
	var c := Compendium.new()
	c.load_all(Compendium.data_roots())
	assert_false(c.tables.has("no_such_folder"))
	assert_eq(c.table("no_such_folder"), {}, "an empty folder is an empty table")
	assert_true(c.tables.has("no_such_folder"), "and is read only once")


func test_reading_read_says_the_verse_in_the_readers_voice() -> void:
	var file := DialogueFile.parse("~ start\nreading read hero_2\nreading read hero_3 test_reader\n", "test_reading")
	assert_eq(file.errors, [] as Array[String])
	var lines := file.nodes["start"] as Array[Dictionary]
	assert_eq(str(lines[0].get("t", "")), "reading_read")
	assert_eq(str(lines[0].get("speaker", "?")), "", "no reader named in the file: the campaign's (ReadingDeck reader)")
	assert_eq(str(lines[1].get("speaker", "?")), "test_reader")


func test_a_story_boon_raises_a_score_to_the_campaigns_limit() -> void:
	Campaign.use_config({"boon_ability_max": 24})
	var ch := TestChars.pregen("silvain_aster", 5)
	var start := ch.ability_score(&"int")
	var got := 0
	for i in 6:
		got += StoryBoons.raise_ability(ch, "int", 2, "The Sun's gift")
	assert_eq(ch.ability_score(&"int"), 24, "up to 24 and no further")
	assert_eq(got, 24 - start)
	Campaign.use_config({"boon_ability_max": 20})
	var other := TestChars.pregen("silvain_aster", 5)
	for i in 6:
		StoryBoons.raise_ability(other, "int", 2, "A gift")
	assert_eq(other.ability_score(&"int"), 20, "the engine's limit without the setting")
