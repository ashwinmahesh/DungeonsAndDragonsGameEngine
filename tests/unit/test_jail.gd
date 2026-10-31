extends TestCase
## Jail (story/jail.gd; docs/contracts/dialogue.md `jail`): a conversation locks the party up in a place's cell, the
## jailers keep its gear, `jailed` holds until it is let out (`jail release`, or its `until` coming true), and the gear
## comes back as it was.

const DIALOGUE := """
~ arrest
Narrator: The constable's hand falls on your shoulder.
jail test_cells:block until flag.test_fine_paid
Narrator: This line is never reached.

~ lockup_light
jail test_cells keep_gear

~ pardon
jail release
"""


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/jail"))


func _story() -> StoryState:
	var st := StoryState.new()
	for id: String in ["hedda_ironvow", "thistle"]:
		st.party.append(TestChars.pregen(id, 3))
	return st


func _run(st: StoryState, node: String) -> Array[Dictionary]:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/jail:" + node))
	var out: Array[Dictionary] = []
	for i in 10:
		var b := r.next()
		out.append(b)
		if str(b["kind"]) == "end":
			break
	return out


func test_it_reads() -> void:
	var f := DialogueFile.parse(DIALOGUE, "test/jail")
	assert_true(f.errors.is_empty(), str(f.errors))
	var s := (f.nodes["arrest"] as Array)[1] as Dictionary
	assert_eq(str(s["t"]), "jail")
	assert_eq(str(s["location"]), "test_cells")
	assert_eq(str(s["spawn"]), "block")
	assert_eq(str(s["until"]), "flag.test_fine_paid")
	assert_false(bool(s["keep_gear"]))
	var light := (f.nodes["lockup_light"] as Array)[0] as Dictionary
	assert_eq(str(light["spawn"]), "default")
	assert_true(bool(light["keep_gear"]))
	assert_eq(str(((f.nodes["pardon"] as Array)[0] as Dictionary)["t"]), "jail_release")
	for bad: String in ["jail", "jail a:b:c", "jail cells until"]:
		assert_false(DialogueFile.parse("~ n\n%s\n" % bad, "test/bad").errors.is_empty(), "'%s' should not read" % bad)


func test_the_party_is_locked_up_and_its_gear_kept() -> void:
	var st := _story()
	var hedda := st.party[0]
	var armor := hedda.held_id("armor")
	var weapon := hedda.held_id("main_hand")
	var carried := hedda.inventory.size()
	var ac := hedda.armor_class().total()
	assert_true(armor != "" and weapon != "", "(the fixture hero wears armor and holds a weapon)")
	var beats := _run(st, "arrest")
	var end := beats[-1]
	assert_eq(str(end["kind"]), "end", "it ends the conversation")
	assert_eq(end["move"], {"location": "test_cells", "spawn": "block"}, "and takes the party to the cell, as `move` does")
	assert_eq(beats.size(), 2, "the line after it never plays")
	assert_true(StoryConditions.check("jailed", st), "jailed")
	assert_true(StoryConditions.check("days_since.jailed >= 0", st), "the day it began is stamped")
	assert_true(hedda.inventory.is_empty(), "the jailers keep everything")
	assert_eq(hedda.held_id("armor"), "", "the armor came off")
	assert_true(hedda.armor_class().total() < ac, "and it shows")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_true(Jail.held(back), "a save keeps the stay")
	var said := _run(st, "pardon")[0]
	assert_eq(str(said["text"]), "You are free to go, and your gear is handed back.")
	assert_false(StoryConditions.check("jailed", st), "free")
	assert_eq(hedda.inventory.size(), carried, "everything back")
	assert_eq(hedda.held_id("armor"), armor, "worn again")
	assert_eq(hedda.held_id("main_hand"), weapon, "held again")
	assert_eq(hedda.armor_class().total(), ac)


func test_until_lets_the_party_out_once_it_holds() -> void:
	var st := _story()
	_run(st, "arrest")
	assert_eq(Jail.settle(st), "", "the fine isn't paid: still held")
	assert_true(Jail.held(st))
	st.set_flag("test_fine_paid")
	assert_false(Jail.held(st), "the condition holds: the cell door's `not jailed` opens at once")
	assert_eq(Jail.settle(st), "You are free to go, and your gear is handed back.", "and the gear comes back as it is settled")
	assert_false(st.party[0].inventory.is_empty())
	assert_eq(Jail.settle(st), "", "once")


func test_keep_gear_leaves_the_party_its_things() -> void:
	var st := _story()
	var carried := st.party[1].inventory.size()
	_run(st, "lockup_light")
	assert_true(Jail.held(st), "held with no end but a release")
	assert_eq(st.party[1].inventory.size(), carried, "nothing taken")
	assert_eq(Jail.settle(st), "", "no `until`: only a release lets them out")
	assert_eq(Jail.release(st), "You are free to go.")
	assert_eq(Jail.release(st), "", "nobody to let out")
