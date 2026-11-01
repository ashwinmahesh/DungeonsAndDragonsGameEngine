extends TestCase
## An affliction's symptoms (`symptoms` {when, save, table}; Afflictions.roll_symptom): a level gained where they strike
## brings one the creature hasn't got (after a failed save), they stack, and all of them go on any reduction.

const ID := "test_rot"
const DEF := {"id": ID, "name": "Test Rot", "modifiers": [],
	"symptoms": {"when": "flag.test_heart", "table": [
		{"id": "blind", "summary": "blind", "conditions": ["blinded"]},
		{"id": "weak", "summary": "weak", "modifiers": [{"stat": "disadvantage", "on": "check:str"}]}]}}


func before_each() -> void:
	Compendium.shared().table("afflictions")[ID] = DEF.duplicate(true)


func after_each() -> void:
	Compendium.shared().table("afflictions").erase(ID)


func test_symptoms_stack_without_repeats_and_go_on_a_reduction() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 3)
	Afflictions.set_level(ch, ID, 1)
	var dice := DiceRoller.new(4)
	assert_ne(Afflictions.roll_symptom(ch, ID, dice), "")
	assert_ne(Afflictions.roll_symptom(ch, ID, dice), "")
	var got := Afflictions.symptoms_of(ch, ID)
	got.sort()
	assert_eq(got, ["blind", "weak"] as Array[String], "both, each once")
	assert_eq(Afflictions.roll_symptom(ch, ID, dice), "", "nothing left to get")
	assert_true(ch.has_condition(&"blinded"), "a symptom's condition lands")
	Afflictions.add(ch, ID, 1)
	assert_eq(Afflictions.symptoms_of(ch, ID).size(), 2, "gaining a level keeps them")
	Afflictions.add(ch, ID, -1)
	assert_true(Afflictions.symptoms_of(ch, ID).is_empty(), "any reduction clears them")
	assert_false(ch.has_condition(&"blinded"))


func test_a_save_keeps_a_symptom_off() -> void:
	Compendium.shared().table("afflictions")[ID]["symptoms"]["save"] = {"ability": "con", "dc": 1}
	var ch := TestChars.pregen("hedda_ironvow", 3)
	Afflictions.set_level(ch, ID, 1)
	assert_eq(Afflictions.roll_symptom(ch, ID, DiceRoller.new(TestChars.seed_for_d20(10))), "", "DC 1 is made")


func test_afflict_rolls_them_only_where_they_strike() -> void:
	var st := StoryState.new()
	var ch := TestChars.pregen("hedda_ironvow", 3)
	st.party.append(ch)
	var talk := "~ start\nafflict test_rot +1\n"
	var r := DialogueRunner.new(st, DiceRoller.new(2))
	r.file = DialogueFile.parse(talk, "test/sym")
	r.start("start")
	r.speaker = ch
	r.next()
	assert_true(Afflictions.symptoms_of(ch, ID).is_empty(), "not here")
	st.set_flag("test_heart")
	r.file = DialogueFile.parse(talk, "test/sym2")
	r.start("start")
	r.speaker = ch
	r.next()
	assert_eq(Afflictions.symptoms_of(ch, ID).size(), 1, "in the heart, a level gained brings one")
