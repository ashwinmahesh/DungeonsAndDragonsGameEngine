extends TestCase
## A stable's horses for hire (Services `mounts`; docs/contracts/dialogue.md `services`): a price per hero for the
## hire's days, and while it lasts the roads go faster (FieldItems.travel_mult), the best way to speed up counting once.

var content := FixtureContent.new()


func before_each() -> void:
	content.add("npcs", {"id": "test_stablehand", "name": "Test Stablehand", "summary": "Hires out horses.", "attitude": "indifferent",
		"services": [{"id": "mounts", "price": 3, "days": 2}]})
	content.add("npcs", {"id": "test_ostler", "name": "Test Ostler", "summary": "Hires out horses by the day.", "attitude": "indifferent",
		"services": [{"id": "mounts"}]})


func after_each() -> void:
	content.restore()


func _story() -> StoryState:
	var st := StoryState.new()
	for id: String in ["thistle", "hedda_ironvow"]:
		st.party.append(TestChars.pregen(id, 3))
	st.gold = 100.0
	return st


func _line(st: StoryState, npc: String) -> Dictionary:
	return Services.offered(st, npc)[0]


func test_the_hire_is_priced_per_hero_for_its_days() -> void:
	var st := _story()
	var line := _line(st, "test_stablehand")
	assert_eq(int(line["days"]), 2, "the stable's own days")
	assert_eq(float(line["price"]), 6.0, "3 gp a hero, two heroes")
	assert_eq(int(_line(st, "test_ostler")["days"]), 1, "a day unless the stable says")


func test_hired_horses_speed_the_roads_until_the_hire_is_up() -> void:
	var st := _story()
	assert_eq(FieldItems.travel_mult(st), 1.0)
	var line := _line(st, "test_stablehand")
	var said := Services.buy(st, "test_stablehand", line, null, DiceRoller.new(1))
	assert_eq(said, "Riding horses for 2 days: the roads go faster until the hire is up.")
	assert_eq(st.gold, 94.0)
	assert_eq(FieldItems.travel_mult(st), 1.5, "half again as fast")
	assert_eq(Services.why_not(st, _line(st, "test_stablehand"), null), "Already hired", "one hire at a time")
	st.advance_minutes(2 * 24 * 60 - 1)
	assert_eq(FieldItems.travel_mult(st), 1.5, "still theirs a minute before it ends")
	st.advance_minutes(1)
	assert_eq(FieldItems.travel_mult(st), 1.0, "the horses go back")
	assert_eq(Services.why_not(st, _line(st, "test_stablehand"), null), "", "and can be hired again")


func test_faster_magic_wins_and_they_do_not_stack() -> void:
	var st := _story()
	Services.buy(st, "test_ostler", _line(st, "test_ostler"), null, DiceRoller.new(1))
	st.set_flag("travel_speed_today", st.day)
	assert_eq(FieldItems.travel_mult(st), 2.0, "the faster one counts, once")


func test_no_hire_without_the_gold() -> void:
	var st := _story()
	st.gold = 1.0
	assert_eq(Services.why_not(st, _line(st, "test_stablehand"), null), "Not enough gold")
	assert_eq(Services.buy(st, "test_stablehand", _line(st, "test_stablehand"), null, DiceRoller.new(1)), "")
	assert_eq(FieldItems.travel_mult(st), 1.0)
