extends TestCase
## The dialogue's gifts to the heroes (docs/contracts/dialogue.md): `temp_hp <dice> [party]`, `gold <n> each`,
## `bless [party] [<n>m|<n>h]` and `inspiration [party]`.

const DIALOGUE := """
~ shield_one
temp_hp 5

~ shield_all
temp_hp 1d1+3 party

~ purse
gold +5 each

~ purse_whole
gold +5

~ bless_one
bless

~ bless_all
bless party 2h

~ inspire_one
inspiration

~ inspire_all
inspiration party
"""


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/gifts"))


func _story() -> StoryState:
	var st := StoryState.new()
	for id: String in ["thistle", "hedda_ironvow", "silvain_aster"]:
		st.party.append(TestChars.pregen(id, 3))
	return st


## The first beat `node` plays.
func _play(st: StoryState, node: String) -> Dictionary:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/gifts:" + node))
	return r.next()


static func _blessed(ch: Character) -> Effect:
	for fx: Effect in ch.effects:
		if fx.source_id == "bless":
			return fx
	return null


func test_they_read() -> void:
	var f := DialogueFile.parse(DIALOGUE, "test/gifts")
	assert_true(f.errors.is_empty(), str(f.errors))
	var bless := (f.nodes["bless_all"] as Array)[0] as Dictionary
	assert_true(bool(bless["party"]))
	assert_eq(int(bless["minutes"]), 120)
	assert_eq(int(((f.nodes["bless_one"] as Array)[0] as Dictionary)["minutes"]), 60, "an hour unless it says")
	assert_true(bool(((f.nodes["purse"] as Array)[0] as Dictionary)["each"]))
	for bad: String in ["temp_hp", "temp_hp lots", "temp_hp 4 party party", "bless everyone", "bless 0m", "bless party 2h 3m",
			"inspiration all", "gold +5 every"]:
		assert_false(DialogueFile.parse("~ n\n%s\n" % bad, "test/bad").errors.is_empty(), "'%s' should not read" % bad)


func test_temporary_hit_points_for_one_or_all() -> void:
	var st := _story()
	var beat := _play(st, "shield_one")
	assert_eq(st.party[0].temp_hp, 5, "the hero in the conversation")
	assert_eq(st.party[1].temp_hp, 0)
	assert_eq(str(beat["text"]), "%s gains 5 Temporary Hit Points" % st.party[0].name.get_slice(" ", 0))
	st.party[2].dead = true
	beat = _play(st, "shield_all")
	assert_eq(st.party[0].temp_hp, 5, "more already: they keep theirs (no stacking)")
	assert_eq(st.party[1].temp_hp, 4)
	assert_eq(st.party[2].temp_hp, 0, "not the dead")
	assert_eq(str(beat["text"]), "%s gains 4 Temporary Hit Points" % st.party[1].name.get_slice(" ", 0))


func test_gold_each_pays_every_living_hero() -> void:
	var st := _story()
	st.party[2].dead = true
	var beat := _play(st, "purse")
	assert_eq(st.gold, 10.0, "5 for each of the two living")
	assert_eq(str(beat["text"]), "Gained 10 gp (5 each)")
	_play(st, "purse_whole")
	assert_eq(st.gold, 15.0, "without `each`, the plain amount")


func test_bless_from_the_story() -> void:
	var st := _story()
	var beat := _play(st, "bless_one")
	var fx := _blessed(st.party[0])
	assert_true(fx != null, "the hero in the conversation is blessed")
	assert_eq(fx.ends, Effect.Ends.MINUTES)
	assert_eq(fx.minutes_left, 60)
	assert_true(st.party[0].concentration == null, "nobody concentrates on it")
	assert_true(_blessed(st.party[1]) == null)
	assert_true(str(beat["text"]).ends_with("is blessed for 1 hour"))
	beat = _play(st, "bless_all")
	assert_eq(st.party.filter(func(ch: Character) -> bool: return _blessed(ch) != null).size(), 3)
	assert_eq(st.party[0].effects.filter(func(e: Effect) -> bool: return e.source_id == "bless").size(), 1, "a second replaces the first")
	assert_eq(_blessed(st.party[0]).minutes_left, 120)
	assert_true(str(beat["text"]).ends_with("are blessed for 2 hours"))
	st.advance_minutes(121)
	assert_true(_blessed(st.party[1]) == null, "and it runs out with the clock")


func test_heroic_inspiration_for_one_or_all() -> void:
	var st := _story()
	var beat := _play(st, "inspire_one")
	assert_true(st.party[0].heroic_inspiration)
	assert_false(st.party[1].heroic_inspiration)
	assert_eq(str(beat["text"]), "%s gains Heroic Inspiration" % st.party[0].name.get_slice(" ", 0))
	beat = _play(st, "inspire_all")
	assert_true(st.party.all(func(ch: Character) -> bool: return ch.heroic_inspiration))
	assert_eq(str(beat["text"]), "%s and %s gain Heroic Inspiration" % [st.party[1].name.get_slice(" ", 0), st.party[2].name.get_slice(" ", 0)],
		"only those who lacked it")
	st.party[0].heroic_inspiration = false
	_play(st, "inspire_one")
	assert_true(st.party[0].heroic_inspiration, "again whenever it runs")
