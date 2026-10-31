extends TestCase
## What a conversation can do to the heroes' bodies and odds (docs/contracts/dialogue.md): `damage <dice> <type>
## [party]` (never below 1 Hit Point), Advantage and Disadvantage on checks (a check's own `adv`/`dis`, and the story's
## grants, CheckEdges), and `hit_dice restore|grant`. The repeated check is Athletics: a failed social one is spent.

const DIALOGUE := """
~ sting
damage 1d1+3 psychic

~ storm
damage 50 lightning party

~ favour
advantage athletics

~ fog
disadvantage checks 1h: the fog

~ ask
* [Athletics DC 30] Climb the wall -> yes | no

~ ask_adv
* [Persuasion DC 30 adv] Ask with the mayor's letter -> yes | no

~ yes
Narrator: Yes.

~ no
Narrator: No.

~ rest_some
hit_dice restore 1

~ rest_all
hit_dice restore all party

~ gift
hit_dice grant 2
"""


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/trials"))


func _story() -> StoryState:
	var st := StoryState.new()
	for id: String in ["thistle", "hedda_ironvow"]:
		st.party.append(TestChars.pregen(id, 4))
	return st


func _runner(st: StoryState, node: String) -> DialogueRunner:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/trials:" + node))
	return r


func _first(st: StoryState, node: String) -> Dictionary:
	return _runner(st, node).next()


## The check beat of `node`'s one option, picked.
func _checked(st: StoryState, node: String) -> Dictionary:
	var r := _runner(st, node)
	var menu := r.next()
	assert_eq(str(menu["kind"]), "options")
	return r.choose(0)


func test_they_read() -> void:
	var f := DialogueFile.parse(DIALOGUE, "test/trials")
	assert_true(f.errors.is_empty(), str(f.errors))
	assert_eq(str((((f.nodes["ask_adv"] as Array)[0] as Dictionary)["check"] as Dictionary)["edge"]), "adv")
	var fog := (f.nodes["fog"] as Array)[0] as Dictionary
	assert_eq(str(fog["kind"]), "dis")
	assert_eq(int(fog["minutes"]), 60)
	assert_eq(str(fog["why"]), "the fog")
	var stmt := DialogueFile.parse("~ n\ncheck Insight DC 12 dis -> a | b\n", "test/c")
	assert_eq(str(((stmt.nodes["n"] as Array)[0] as Dictionary)["edge"]), "dis")
	assert_eq(str(((stmt.nodes["n"] as Array)[0] as Dictionary)["ok"]), "a")
	for bad: String in ["damage 1d6", "damage 1d6 tickling", "damage lots fire", "advantage juggling", "advantage persuasion soon",
			"hit_dice restore", "hit_dice grant all", "hit_dice give 2", "hit_dice restore 0"]:
		assert_false(DialogueFile.parse("~ n\n%s\n" % bad, "test/bad").errors.is_empty(), "'%s' should not read" % bad)


func test_damage_hurts_through_defenses() -> void:
	var st := _story()
	var lead := st.leader_character()
	var before := lead.hp
	var beat := _first(st, "sting")
	assert_eq(lead.hp, before - 4)
	assert_eq(str(beat["text"]), "%s takes 4 Psychic damage" % lead.name.get_slice(" ", 0))
	assert_eq(st.party[1].hp, st.party[1].max_hp(), "only the hero in the conversation")
	lead.temp_hp = 3
	_first(st, "sting")
	assert_eq(lead.temp_hp, 0, "Temporary Hit Points first")
	assert_eq(lead.hp, before - 5)


func test_damage_never_drops_a_hero_below_1_hit_point() -> void:
	var st := _story()
	var beat := _first(st, "storm")
	for ch in st.party:
		assert_eq(ch.hp, 1, "50 lightning leaves %s at 1" % ch.name)
		assert_false(ch.dead)
		assert_false(ch.has_condition(&"unconscious"), "and standing")
	assert_eq(str(beat["text"]), "Each hero takes 50 Lightning damage")
	assert_eq(str(_first(st, "storm").get("kind", "")), "end", "at 1 already: nothing more to take, no notice")


func test_a_checks_own_advantage_rolls_two_dice() -> void:
	var st := _story()
	var plain := _checked(st, "ask")
	assert_eq(str(plain["kind"]), "check")
	var test := (_runner_last_test(st, "ask_adv"))
	assert_true(test.advantage, "the option's adv rolls with Advantage")
	assert_eq(test.rolls.size(), 2)


func _runner_last_test(st: StoryState, node: String) -> D20Test:
	var r := _runner(st, node)
	r.next()
	r.choose(0)
	return r._last_check["test"] as D20Test


func test_granted_advantage_counts_on_the_next_such_check_only() -> void:
	var st := _story()
	_first(st, "favour")
	assert_true(_runner_last_test(st, "ask").advantage, "granted for the next Athletics check")
	assert_false(_runner_last_test(st, "ask").advantage, "used up")


func test_granted_disadvantage_lasts_its_time() -> void:
	var st := _story()
	_first(st, "fog")
	assert_true(_runner_last_test(st, "ask").disadvantage, "any check, for an hour")
	assert_true(_runner_last_test(st, "ask").disadvantage, "still within the hour")
	st.advance_minutes(61)
	assert_false(_runner_last_test(st, "ask").disadvantage, "the fog lifts")
	_first(st, "fog")
	_first(st, "favour")
	var both := _runner_last_test(st, "ask")
	assert_false(both.advantage or both.disadvantage, "both at once cancel out, as the rules say")


func test_hit_dice_come_back_and_can_be_given() -> void:
	var st := _story()
	var hedda := st.party[1]
	var lead := st.leader_character()
	for ch in st.party:
		for k: String in ch.hit_dice():
			ch.hit_dice_spent[k] = 3
	var beat := _first(st, "rest_some")
	assert_eq(_spent(lead), 2, "one back")
	assert_eq(_spent(hedda), 3, "for the hero in the conversation only")
	assert_eq(str(beat["text"]), "%s regains 1 Hit Point Die" % lead.name.get_slice(" ", 0))
	_first(st, "rest_all")
	assert_eq(_spent(lead), 0)
	assert_eq(_spent(hedda), 0, "party: everyone's back")
	beat = _first(st, "gift")
	var top := _top_die(lead)
	assert_eq(int((lead.hit_dice()[top] as Dictionary)["total"]) - int((lead.hit_dice()[top] as Dictionary)["spent"]), 4 + 2, "two beyond their own")
	assert_eq(str(beat["text"]), "%s gains 2 Hit Point Dice" % lead.name.get_slice(" ", 0))
	lead.finish_long_rest()
	assert_eq(_spent(lead), 0, "a Long Rest ends the gift")


static func _spent(ch: Character) -> int:
	var n := 0
	for k: Variant in ch.hit_dice():
		n += int((ch.hit_dice()[k] as Dictionary)["spent"])
	return n


static func _top_die(ch: Character) -> String:
	var dies := ch.hit_dice().keys()
	dies.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) > int(b))
	return str(dies[0])
