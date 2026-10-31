extends TestCase
## The dialogue statement `heal <dice> [party] [temp]` (docs/contracts/dialogue.md): one roll heals the hero in the
## conversation or, with `party`, every hero who isn't dead; with `temp` what is past a hero's maximum becomes Temporary
## Hit Points; a notice says how much.

const DIALOGUE := """
~ one
heal 4

~ party
heal 1d1+5 party

~ overflow
heal 6 party temp
"""


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/heal"))


func _story() -> StoryState:
	var st := StoryState.new()
	for id: String in ["thistle", "hedda_ironvow", "silvain_aster"]:
		var ch := TestChars.pregen(id, 3)
		ch.hp = ch.max_hp() - 10
		st.party.append(ch)
	return st


## The beats `node` plays, to its end.
func _play(st: StoryState, node: String) -> Array[Dictionary]:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/heal:" + node))
	var out: Array[Dictionary] = []
	for i in 10:
		var b := r.next()
		out.append(b)
		if str(b["kind"]) == "end":
			break
	return out


func test_it_reads_dice_party_and_temp() -> void:
	var f := DialogueFile.parse(DIALOGUE, "test/heal")
	assert_true(f.errors.is_empty(), str(f.errors))
	var s := (f.nodes["overflow"] as Array)[0] as Dictionary
	assert_eq(str(s["t"]), "heal")
	assert_eq(str(s["dice"]), "6")
	assert_true(bool(s["party"]) and bool(s["temp"]))
	var p := (f.nodes["party"] as Array)[0] as Dictionary
	assert_eq(str(p["dice"]), "1d1+5")
	assert_true(bool(p["party"]) and not bool(p["temp"]))
	for bad: String in ["heal", "heal lots", "heal 1d6 everyone", "heal 1d6 party party", "heal 1d6 temp party extra"]:
		assert_false(DialogueFile.parse("~ n\n%s\n" % bad, "test/bad").errors.is_empty(), "'%s' should not read" % bad)


func test_it_heals_the_hero_in_the_conversation() -> void:
	var st := _story()
	var lead := st.leader_character()
	var before := lead.hp
	var beats := _play(st, "one")
	assert_eq(lead.hp, before + 4)
	assert_eq(st.party[1].hp, st.party[1].max_hp() - 10, "no one else")
	assert_eq(str(beats[0]["kind"]), "notice")
	assert_eq(str(beats[0]["text"]), "%s regains 4 Hit Points" % lead.name.get_slice(" ", 0))


func test_party_heals_every_living_hero_with_one_roll() -> void:
	var st := _story()
	st.party[2].dead = true
	var dead_hp := st.party[2].hp
	var beats := _play(st, "party")
	assert_eq(st.party[0].hp, st.party[0].max_hp() - 4, "1d1+5 is 6")
	assert_eq(st.party[1].hp, st.party[1].max_hp() - 4)
	assert_eq(st.party[2].hp, dead_hp, "the dead are not healed")
	assert_eq(str(beats[0]["text"]), "Each hero regains 6 Hit Points")


func test_temp_turns_the_overflow_into_temporary_hit_points() -> void:
	var st := _story()
	st.party[0].hp = st.party[0].max_hp() - 2
	st.party[1].hp = st.party[1].max_hp()
	var beats := _play(st, "overflow")
	assert_eq(st.party[0].hp, st.party[0].max_hp())
	assert_eq(st.party[0].temp_hp, 4, "6 healed, 2 of them to full: 4 Temporary Hit Points")
	assert_eq(st.party[1].temp_hp, 6, "all 6 for a hero already at full")
	assert_eq(st.party[2].temp_hp, 0, "none past the maximum for one 10 down")
	assert_eq(str(beats[0]["text"]), "Each hero regains 6 Hit Points (the rest as Temporary Hit Points)")
	var plain := _story()
	plain.party[1].hp = plain.party[1].max_hp()
	_play(plain, "party")
	assert_eq(plain.party[1].temp_hp, 0, "without temp, nothing past the maximum")
