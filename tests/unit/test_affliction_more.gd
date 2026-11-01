extends TestCase
## The last of an affliction's clock (story/affliction_clock.gd, Afflictions): an onset in dice, death once the maximum is
## worn to nothing, a body that rises as something else at an hour, and a spell that holds it down for hours.

const ID := "test_blight"
const DEF := {"id": ID, "name": "Test Blight", "modifiers": [{"stat": "attack", "per_level": -1}], "onset_hours": "2d4",
	"long_rest": {"max_hp_loss": "200"}, "suppressed_by": {"spells": ["lesser_restoration"], "hours": 24},
	"on_death": {"hour": 0, "becomes": "test_swarm", "flag": "test_risen", "only_types": ["humanoid"]}}


func before_each() -> void:
	Compendium.shared().table("afflictions")[ID] = DEF.duplicate(true)


func after_each() -> void:
	Compendium.shared().table("afflictions").erase(ID)


func _st() -> StoryState:
	var st := StoryState.new()
	for id: String in ["hedda_ironvow", "thistle"]:
		var ch := TestChars.pregen(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	return st


func test_a_dice_onset() -> void:
	var st := _st()
	AfflictionClock.afflict(st, st.party[0], ID, 1, DiceRoller.new(3))
	var until := int(Afflictions.effect_of(st.party[0], ID).data["dormant_until"])
	var hours := (until - st.total_minutes()) / 60
	assert_true(hours >= 2 and hours <= 8, "2d4 hours (%d)" % hours)
	assert_eq(AfflictionClock.onset({"onset_hours": "3d6"}, null), 3, "without dice, the least")


func test_a_maximum_worn_to_nothing_kills_and_the_body_rises_at_midnight() -> void:
	var st := _st()
	var ch := st.party[0]
	Afflictions.set_level(ch, ID, 1)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	var lines := Afflictions.after_long_rest(ch, DiceRoller.new(1))
	assert_true(ch.dead, "200 off the maximum: dead")
	assert_true(lines.any(func(l: String) -> bool: return l.contains("dies of")), str(lines))
	st.advance_minutes(60)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_true(ch in st.party, "not before midnight")
	st.advance_minutes(24 * 60)
	var risen := AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_false(ch in st.party, "at midnight the body rises")
	assert_eq(str((st.fallen[-1] as Dictionary)["becomes"]), "test_swarm")
	assert_eq(int(st.get_flag("test_risen", 0)), 1)
	assert_eq(risen.size(), 1, str(risen))


func test_a_spell_holds_it_down_for_its_hours() -> void:
	var st := _st()
	var ch := st.party[0]
	var atk := ch.modifiers_for(&"attack").size()
	Afflictions.set_level(ch, ID, 2)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_eq(ch.modifiers_for(&"attack").size(), atk + 1)
	Afflictions.cure_by_spell(ch, "lesser_restoration", ["poisoned"])
	assert_eq(ch.modifiers_for(&"attack").size(), atk, "held down at once")
	st.advance_minutes(10)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	st.advance_minutes(23 * 60)
	AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_eq(ch.modifiers_for(&"attack").size(), atk, "still, within the day")
	st.advance_minutes(2 * 60)
	var back := AfflictionClock.catch_up(st, DiceRoller.new(1))
	assert_eq(ch.modifiers_for(&"attack").size(), atk + 1, "back after 24 hours")
	assert_true(back.any(func(l: String) -> bool: return l.contains("stirs")), str(back))
	assert_eq(Afflictions.level_of(ch, ID), 2, "the level was never touched")
