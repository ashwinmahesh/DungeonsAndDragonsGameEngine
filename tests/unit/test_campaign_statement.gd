extends TestCase
## A dialogue's `campaign <verb> [args...]` goes to the campaign module (CampaignModule.statement) with the story and
## the dice, and its answer is the notice; the engine's base module answers nothing.

const DIALOGUE := """~ start
Narrator: Something happens.
campaign thread test_thread betrayal
Narrator: After.
campaign quiet
"""


class Hearing extends CampaignModule:
	var heard: Array[String] = []

	func statement(_st: StoryState, verb: String, args: Array[String], _dice: DiceRoller) -> String:
		heard.append("%s %s" % [verb, " ".join(args)])
		return "The thread turns" if verb == "thread" else ""


func after_each() -> void:
	Campaign.use(null)


func _run() -> Array[String]:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/campaign_statement"))
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/campaign_statement:start"))
	var notices: Array[String] = []
	for i in 20:
		var beat := r.next()
		if str(beat["kind"]) == "notice":
			notices.append(str(beat["text"]))
		if str(beat["kind"]) == "end":
			break
	return notices


func test_the_module_hears_it_and_answers() -> void:
	var m := Hearing.new()
	Campaign.use(m)
	var notices := _run()
	assert_eq(m.heard, ["thread test_thread betrayal", "quiet "] as Array[String])
	assert_eq(notices, ["The thread turns"] as Array[String])


func test_the_base_module_lets_it_pass() -> void:
	Campaign.use(CampaignModule.new())
	assert_eq(_run(), [] as Array[String])
