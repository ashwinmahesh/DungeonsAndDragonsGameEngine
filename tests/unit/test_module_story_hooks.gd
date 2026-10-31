extends TestCase
## What the story engine tells the campaign module as it happens (story/campaign_module.gd; docs/contracts/campaign.md):
## `reading_finished` once a conversation has turned every card the reading dealt, and `quest_finished` when a quest
## moves into a stage that ends it, whose words join the journal's notice.

const DIALOGUE := """
~ all
reading read hero_1
reading read hero_2
reading read hero_1
Narrator: The cards are put away.

~ some
reading read hero_1
"""


## A module that deals two cards and writes down what it is told.
class Listening extends CampaignModule:
	var finished := 0
	var cards_when_finished := 0
	var cards := 0
	var quests: Array[String] = []
	var rolled := 0

	func ensure_drawn(st: StoryState) -> void:
		if st.tarokka.is_empty():
			st.tarokka = {"hero_1": "card_a", "hero_2": "card_b"}

	func reading(slot: String, st: StoryState) -> Dictionary:
		if not st.tarokka.has(slot):
			return {}
		cards += 1
		return {"card": st.tarokka[slot], "slot": slot, "title": "Hero: %s" % st.tarokka[slot], "verse": "A verse."}

	func reading_finished(_st: StoryState) -> void:
		finished += 1
		cards_when_finished = cards

	func quest_finished(_st: StoryState, quest_id: String, ending: String, dice: DiceRoller) -> String:
		quests.append("%s:%s" % [quest_id, ending])
		rolled = int(dice.roll_expr("1d6")["total"])
		return "The test quest's reward is %d" % rolled if ending == "success" else ""


var module: Listening
var content := FixtureContent.new()


func before_each() -> void:
	module = Listening.new()
	Campaign.use(module)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/module_hooks"))


func after_each() -> void:
	Campaign.use(null)
	content.restore()


func _story() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	module.ensure_drawn(st)
	return st


func _play(st: StoryState, node: String) -> void:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/module_hooks:" + node))
	for i in 20:
		if str(r.next()["kind"]) == "end":
			return


func test_the_reading_is_finished_once_every_card_is_turned() -> void:
	var st := _story()
	_play(st, "all")
	assert_eq(module.finished, 1, "told once, though a card was read twice")
	assert_eq(module.cards_when_finished, 2, "after the last card's own reading, before the one read again")
	_play(st, "all")
	assert_eq(module.finished, 2, "a later conversation that reads them all again tells it again")


func test_a_reading_left_unfinished_tells_nothing() -> void:
	var st := _story()
	_play(st, "some")
	assert_eq(module.cards, 1)
	assert_eq(module.finished, 0, "a card left unturned: the reading isn't finished")
	_play(st, "some")
	assert_eq(module.finished, 0, "nor across conversations")


func test_a_finished_quest_tells_the_module_and_its_words_join_the_notice() -> void:
	var q := content.add_quest("test_hook_quest", "The Test Hook", [["begun", ""], ["done", "success"], ["lost", "failure"]])
	var st := _story()
	assert_true(st.set_quest_stage(q, "begun"))
	assert_eq(module.quests, [] as Array[String], "a stage that ends nothing tells it nothing")
	assert_true(st.set_quest_stage(q, "done"))
	assert_eq(module.quests, ["test_hook_quest:success"] as Array[String])
	assert_true(module.rolled >= 1 and module.rolled <= 6, "with dice to roll on")
	assert_eq(st.quest_notice(), "Quest complete: The Test Hook. The test quest's reward is %d" % module.rolled,
		"its words follow the journal's")
	assert_true(st.set_quest_stage(q, "done"))
	assert_eq(module.quests.size(), 1, "the same stage again tells it nothing")


func test_a_failed_quest_tells_it_too_and_silence_keeps_the_notice() -> void:
	var q := content.add_quest("test_hook_quest", "The Test Hook", [["begun", ""], ["done", "success"], ["lost", "failure"]])
	var st := _story()
	st.set_quest_stage(q, "begun")
	assert_true(st.set_quest_stage(q, "lost"))
	assert_eq(module.quests, ["test_hook_quest:failure"] as Array[String])
	assert_eq(st.quest_notice(), "Quest failed: The Test Hook", "nothing said: the journal's notice alone")


func test_the_base_module_says_nothing() -> void:
	Campaign.use(CampaignModule.new())
	var q := content.add_quest("test_hook_quest", "The Test Hook", [["begun", ""], ["done", "success"]])
	var st := StoryState.new()
	st.set_quest_stage(q, "begun")
	assert_true(st.set_quest_stage(q, "done"))
	assert_eq(st.quest_notice(), "Quest complete: The Test Hook")
