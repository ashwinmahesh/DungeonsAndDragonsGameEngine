extends TestCase
## What the big d20 needs to show a roll that was rolled again or added to (Ashwin, 2026-10-26: "display the same green dice
## roll when rerolling for inspiration ... same thing with other abilities which add to rolls"): D20Test keeps each reroll
## (the dice before and after) and each addition (what it was, the number, the total and whether the roll then succeeded);
## Heroic Inspiration rerolls one die, so under Advantage the lower one and the other stays; a conversation's check beat
## carries both, and a reroll that turns a failure round takes the success branch.

const OWN := "dark_ones_own_luck"


## A seed whose first two d20s are both at most `top` (a roll under Advantage that failed on both dice).
func _seed_low_pair(top: int) -> int:
	for s in range(1, 3000):
		var d := DiceRoller.new(s)
		if d.d20() <= top and d.d20() <= top:
			return s
	return 0


func test_a_reroll_keeps_the_dice_before_and_after() -> void:
	var t := D20Test.from_natural(D20Test.Kind.ABILITY_CHECK, 4, 3, 14)
	assert_true(t.rerolls.is_empty() and t.added.is_empty(), "nothing yet")
	t.reroll_one(17, "Heroic Inspiration")
	assert_eq(t.rerolls.size(), 1)
	var r := t.rerolls[0]
	assert_eq(str(r["source"]), "Heroic Inspiration")
	assert_eq(r["before"], [4] as Array[int])
	assert_eq(int(r["before_kept"]), 4)
	assert_eq(r["after"], [17] as Array[int])
	assert_eq(int(r["after_kept"]), 17)
	assert_true(t.success, "20 meets 14")


func test_heroic_inspiration_rerolls_the_lower_die_under_advantage() -> void:
	var s := _seed_low_pair(6)
	assert_true(s > 0)
	var dice := DiceRoller.new(s)
	var t := D20Test.roll(dice, D20Test.Kind.ABILITY_CHECK, 2, 20, 1, 0)
	assert_eq(t.rolls.size(), 2)
	var hi := maxi(t.rolls[0], t.rolls[1])
	var lo := mini(t.rolls[0], t.rolls[1])
	var ch := TestChars.pregen("ilse_varga", 3)
	ch.heroic_inspiration = true
	CheckAids.apply("heroic_inspiration", ch, t, dice)
	assert_false(ch.heroic_inspiration, "spent")
	assert_eq(t.rerolls.size(), 1)
	var r := t.rerolls[0]
	assert_eq((r["before"] as Array).size(), 2, "both dice as they lay")
	assert_eq(int(r["before_kept"]), hi)
	assert_eq((r["after"] as Array).size(), 2, "and both still there after: one die was rolled again, not the roll")
	assert_true(hi in (r["after"] as Array), "the higher die stayed")
	assert_eq(t.rolls.size(), 2)
	assert_eq(t.kept, maxi(t.rolls[0], t.rolls[1]), "the better of the two still counts")
	assert_true(t.kept >= hi, "and a reroll under Advantage can only help (%d, was %d, the lower die was %d)" % [t.kept, hi, lo])


func test_an_addition_keeps_what_it_rolled_and_whether_it_helped() -> void:
	var t := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 5, 3, 14)   # 8 against 14
	assert_false(t.success)
	t.add_bonus(4, "Bardic Inspiration")
	assert_eq(t.added.size(), 1)
	var a := t.added[0]
	assert_eq(str(a["source"]), "Bardic Inspiration")
	assert_eq(int(a["amount"]), 4)
	assert_eq(int(a["total"]), 12)
	assert_false(bool(a["success"]), "12 is still short of 14")
	t.add_bonus(3, "Dark One's Own Luck")
	assert_eq(t.added.size(), 2)
	assert_eq(int(t.added[1]["total"]), 15)
	assert_true(bool(t.added[1]["success"]), "15 meets 14")
	assert_true(t.extra_label.begins_with("+ Bardic Inspiration 4"), t.extra_label)
	assert_true(t.extra_label.contains("+ Dark One's Own Luck 3"), t.extra_label)


func test_every_way_of_changing_the_d20_is_recorded() -> void:
	var t := D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 3, 5, 15)
	t.set_natural(20, "Stroke of Luck")
	assert_eq(t.rerolls.size(), 1)
	assert_eq(int(t.rerolls[0]["before_kept"]), 3)
	assert_eq(int(t.rerolls[0]["after_kept"]), 20)
	var whole := D20Test.roll(DiceRoller.new(5), D20Test.Kind.SAVING_THROW, 0, 30)
	whole.reroll(DiceRoller.new(6), "Indomitable")
	assert_eq(whole.rerolls.size(), 1)
	assert_eq(str(whole.rerolls[0]["source"]), "Indomitable")


## A conversation: the check beat carries the reroll and the addition, and a reroll that turns the failure round takes
## the success branch, not the failure's.
func test_a_reroll_in_a_conversation_applies_before_the_branch_is_picked() -> void:
	var f := DialogueFile.parse("~ door\n* [Intimidation DC 14] Force it. -> ok | no\n~ ok\nset forced\n-> END\n~ no\nset refused\n-> END\n", "test/rerolls")
	DialogueFile.register(f)
	var seed_found := 0
	for s in range(1, 3000):
		var dd := DiceRoller.new(s)
		var a := dd.d20()
		var b := dd.d20()
		if a <= 4 and b >= 19:
			seed_found = s
			break
	assert_true(seed_found > 0)
	var st := StoryState.new()
	var ilse := TestChars.pregen("ilse_varga", 3)
	ilse.finish_long_rest()
	ilse.heroic_inspiration = true
	st.party.append(ilse)
	var r := DialogueRunner.new(st, DiceRoller.new(seed_found))
	r.start("test/rerolls:door")
	r.next()
	var b := r.choose(0)
	assert_false(bool(b["success"]), "the first throw fails")
	assert_true((b["rerolls"] as Array).is_empty())
	b = r.use_aid("heroic_inspiration")
	assert_true(bool(b["success"]), "the reroll turns it round")
	assert_eq((b["rerolls"] as Array).size(), 1, "and the beat carries it")
	assert_eq(int((b["rerolls"] as Array)[0]["before_kept"]), int((b["rerolls"] as Array)[0]["before"][0]))
	assert_eq(str(r.next()["kind"]), "end", "the branch picked is the success one")
	assert_true(bool(st.get_flag("forced")), "it happened")
	assert_false(bool(st.get_flag("refused")), "and the failure did not")


func test_dark_ones_own_luck_in_a_conversation_names_the_number_and_the_result() -> void:
	var f := DialogueFile.parse("~ door\n* [Persuasion DC 14] Talk. -> ok | no\n~ ok\nset won\n-> END\n~ no\nset lost\n-> END\n", "test/own_luck")
	DialogueFile.register(f)
	var st := StoryState.new()
	var kip := TestChars.pregen("kip_smudgewick", 6)
	kip.finish_long_rest()
	kip.heroic_inspiration = false
	st.party.append(kip)
	var seed_found := 0
	for s in range(1, 3000):
		var dd := DiceRoller.new(s)
		var a := dd.d20()
		if a >= 6 and a <= 9:
			seed_found = s
			break
	var r := DialogueRunner.new(st, DiceRoller.new(seed_found))
	r.start("test/own_luck:door")
	r.next()
	var b := r.choose(0)
	var ids: Array = (b["aids"] as Array).map(func(x: Dictionary) -> String: return str(x["id"]))
	if not bool(b["success"]):
		assert_true(OWN in ids, "Dark One's Own Luck is offered on the failure: %s" % [ids])
		b = r.use_aid(OWN)
		assert_eq((b["added"] as Array).size(), 1)
		var a := (b["added"] as Array)[0] as Dictionary
		assert_eq(str(a["source"]), "Dark One's Own Luck")
		assert_between(int(a["amount"]), 1, 10, "the d10 it rolled")
		assert_eq(int(a["total"]), int(b["total"]), "the total once it was added")
		assert_eq(bool(a["success"]), bool(b["success"]), "and whether that succeeded")
