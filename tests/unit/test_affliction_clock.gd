extends TestCase
## Afflictions on the clock (story/affliction_clock.gd, Afflictions): a slow onset, a daily save with successes that end
## it, a spell that holds it off a day, Exhaustion it won't let go of, Hit Points lost each rest, and a land that spreads it.

const ID := "test_plague"
const DEF := {"id": ID, "name": "Test Plague", "modifiers": [{"stat": "attack", "per_level": -1}], "onset_hours": 12, "onset_exhaustion": 1,
	"daily": {"hour": 18, "save": {"ability": "con", "dc": 10}, "successes_to_end": 3}, "held_off_by": ["lesser_restoration"],
	"exhaustion_lock": true, "long_rest": {"max_hp_loss": "2"},
	"exposure": {"when": "flag.test_miasma", "every_minutes": 60, "save": {"ability": "con", "dc": 40}}}


func before_each() -> void:
	Compendium.shared().table("afflictions")[ID] = DEF.duplicate(true)


func after_each() -> void:
	Compendium.shared().table("afflictions").erase(ID)


func _st() -> StoryState:
	var st := StoryState.new()
	var ch := TestChars.pregen("hedda_ironvow", 3)
	ch.finish_long_rest()
	st.party.append(ch)
	return st


func test_it_lies_dormant_then_takes_hold() -> void:
	var st := _st()
	var ch := st.party[0]
	var atk := ch.modifiers_for(&"attack").size()
	AfflictionClock.afflict(st, ch, ID, 1)
	assert_eq(ch.modifiers_for(&"attack").size(), atk, "nothing yet: it lies dormant")
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	st.advance_minutes(13 * 60)
	var lines := AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_true(lines.any(func(l: String) -> bool: return l.contains("take hold")), str(lines))
	assert_eq(ch.modifiers_for(&"attack").size(), atk + 1, "awake")
	assert_eq(ch.exhaustion, 1, "the fever's Exhaustion as it takes hold")


func test_three_good_days_end_it_and_a_spell_holds_off_one() -> void:
	var st := _st()
	var ch := st.party[0]
	Afflictions.set_level(ch, ID, 1)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	Afflictions.cure_by_spell(ch, "lesser_restoration", ["poisoned"])
	st.advance_minutes(DAY_MINUTES())
	var lines := AfflictionClock.catch_up(st, DiceRoller.new(TestChars.seed_for_d20(20)))
	assert_true(lines.any(func(l: String) -> bool: return l.contains("holds off")), str(lines))
	for i in 3:
		st.advance_minutes(DAY_MINUTES())
		AfflictionClock.catch_up(st, DiceRoller.new(TestChars.seed_for_d20(20)))
	assert_eq(Afflictions.level_of(ch, ID), 0, "three saves made: gone")


func test_a_failed_day_worsens_it() -> void:
	var st := _st()
	var ch := st.party[0]
	Afflictions.set_level(ch, ID, 1)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	st.advance_minutes(DAY_MINUTES())
	AfflictionClock.catch_up(st, DiceRoller.new(TestChars.seed_for_d20(1)))
	assert_eq(Afflictions.level_of(ch, ID), 2)


func test_exhaustion_stays_and_the_maximum_falls_each_rest() -> void:
	var st := _st()
	var ch := st.party[0]
	var full := ch.max_hp()
	Afflictions.set_level(ch, ID, 1)
	ch.exhaustion = 2
	ch.finish_long_rest()
	Afflictions.after_long_rest(ch, DiceRoller.new(1))
	assert_eq(ch.exhaustion, 2, "the rest takes none away")
	assert_eq(ch.max_hp(), full - 2, "2 off the maximum")
	ch.finish_long_rest()
	Afflictions.after_long_rest(ch, DiceRoller.new(1))
	assert_eq(ch.max_hp(), full - 4, "and 2 more")
	Afflictions.clear(ch, ID)
	assert_eq(ch.max_hp(), full, "back once it's gone")
	ch.finish_long_rest()
	assert_eq(ch.exhaustion, 1, "and Exhaustion eases again")


func test_a_land_that_spreads_it() -> void:
	var st := _st()
	var ch := st.party[0]
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	st.advance_minutes(180)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_eq(Afflictions.level_of(ch, ID), 0, "not out in it")
	st.set_flag("test_miasma")
	st.advance_minutes(180)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_eq(Afflictions.level_of(ch, ID), 3, "three hours in it, three failed DC 40 saves")


func DAY_MINUTES() -> int:
	return 24 * 60
