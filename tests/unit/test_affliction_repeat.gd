extends TestCase
## A curse that holds a hero charmed and asks a save again every so often (an affliction's `conditions` and `repeat`;
## AfflictionClock._repeat): a success ends it, failures deepen it, and at its worst no more saves come.

const ID := "test_lure"
const DEF := {"id": ID, "name": "Test Lure", "max_level": 3, "conditions": ["charmed"],
	"thresholds": [{"at": 3, "modifiers": [{"stat": "disadvantage", "on": ["attack"]}]}],
	"repeat": {"every_minutes": 10, "save": {"ability": "wis", "dc": 40}}}


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


func test_it_deepens_and_then_holds_for_good() -> void:
	var st := _st()
	var ch := st.party[0]
	Afflictions.set_level(ch, ID, 1)
	assert_true(ch.has_condition(&"charmed"), "charmed")
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	st.advance_minutes(10)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_eq(Afflictions.level_of(ch, ID), 2, "a failed repeat")
	st.advance_minutes(10)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_eq(Afflictions.level_of(ch, ID), 3, "captivated")
	assert_true(ch.modifiers_for(&"disadvantage").size() > 0, "the captivation's own hindrance")
	st.advance_minutes(60)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_eq(Afflictions.level_of(ch, ID), 3, "no more saves")


func test_a_success_ends_it() -> void:
	Compendium.shared().table("afflictions")[ID]["repeat"]["save"]["dc"] = 1
	var st := _st()
	var ch := st.party[0]
	Afflictions.set_level(ch, ID, 1)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	st.advance_minutes(10)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_eq(Afflictions.level_of(ch, ID), 0)
	assert_false(ch.has_condition(&"charmed"))
