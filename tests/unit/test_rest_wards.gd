extends TestCase
## Wards drawn on by resting in them (a spell's `rest_ward`; Wards.after_long_rest): cast while exploring, the spell is
## paid before the rest; a Long Rest finished where it was cast ends it, and its caster and up to its spellcasting
## modifier of others gain its modifiers for what is left of its duration.

var _fx := FixtureContent.new()


func before_each() -> void:
	_fx.add("spells", {"id": "test_rest_ward", "name": "Test Rest Ward", "level": 1, "school": "abjuration", "classes": ["cleric"],
		"casting_time": {"unit": "minute", "amount": 1}, "range": {"kind": "feet", "feet": 5}, "components": {"v": true, "s": true},
		"duration": {"kind": "hours", "amount": 24}, "targets": {"kind": "area"}, "summary": "A test ward.",
		"rest_ward": {"modifiers": [{"stat": "ac", "value": 1}]}})


func after_each() -> void:
	_fx.restore()


func _party() -> StoryState:
	var st := StoryState.new()
	st.location = "test_place"
	var cleric := TestChars.custom("cleric", "human", 5)
	((cleric.spellcasting[0] as Dictionary)["prepared"] as Array).append("test_rest_ward")
	cleric.finish_long_rest()
	st.party.append(cleric)
	for id: String in ["ilse_varga", "hedda_ironvow", "kip_smudgewick", "silvain_aster"]:
		st.party.append(TestChars.pregen(id, 5))
	return st


func _warded(ch: Character) -> bool:
	return ch.effects.any(func(fx: Effect) -> bool: return fx.source_id == "test_rest_ward")


func test_resting_in_it_wards_the_caster_and_its_chosen() -> void:
	var st := _party()
	var cleric := st.party[0] as Character
	var res := FieldCasting.cast_utility(st, cleric, "test_rest_ward", false, 1)
	assert_true(bool(res["ok"]), str(res.get("text", "")))
	assert_eq(cleric.slots_used[0], 1, "paid before the rest")
	var ac := cleric.armor_class().total()
	var lines := LongRest.finish(st, DiceRoller.new(1))
	assert_false(st.spell_active("test_rest_ward"), "the rest ends the spell")
	var n := maxi(1, cleric.ability_mod(&"wis"))
	var warded := st.party.filter(func(ch: Character) -> bool: return _warded(ch))
	assert_eq(warded.size(), 1 + n, "its caster and %d more" % n)
	assert_true(_warded(cleric))
	assert_eq(cleric.armor_class().total(), ac + 1, "+1 AC")
	var fx := cleric.effects.filter(func(f: Effect) -> bool: return f.source_id == "test_rest_ward")[0] as Effect
	assert_eq(fx.minutes_left, 16 * 60, "what is left of the 24 hours after the rest")
	assert_true(lines.any(func(l: String) -> bool: return l.contains("Test Rest Ward")))


func test_resting_somewhere_else_gives_nothing() -> void:
	var st := _party()
	var cleric := st.party[0] as Character
	FieldCasting.cast_utility(st, cleric, "test_rest_ward", false, 1)
	st.location = "test_elsewhere"
	LongRest.finish(st, DiceRoller.new(1))
	assert_false(_warded(cleric))
