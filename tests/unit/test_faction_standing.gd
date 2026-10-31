extends TestCase
## Faction standing (story/factions.gd; docs/contracts/campaign.md): a number per faction, moved by `standing <id> +n`
## and by crimes against a member, read by conditions (`standing.<id>`) and, past the thresholds, as every member's
## attitude unless they have one of their own.

const DIALOGUE := """
~ praise
standing test_guild +2

~ insult
standing test_guild -5

~ ask
if standing.test_guild >= 2
Narrator: The guild nods you through.
else
Narrator: The guild looks away.
endif
"""

var content := FixtureContent.new()


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/standing"))
	content.add("npcs", {"id": "test_guild_baker", "name": "Test Baker", "summary": "A guild member.", "attitude": "indifferent",
		"tags": ["faction_test_guild"]})
	content.add("npcs", {"id": "test_loner", "name": "Test Loner", "summary": "Nobody's.", "attitude": "indifferent",
		"tags": ["faction_none"]})


func after_each() -> void:
	content.restore()
	Campaign.use_config(null)


func _story() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	return st


func _play(st: StoryState, node: String) -> Dictionary:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/standing:" + node))
	return r.next()


func test_membership_comes_from_the_faction_tag() -> void:
	assert_eq(Factions.of_npc("test_guild_baker"), "test_guild")
	assert_eq(Factions.of_npc("test_loner"), "", "faction_none is no faction")
	assert_eq(Factions.of_npc("no_such_npc"), "")
	assert_eq(Factions.name_of("test_guild"), "Test Guild", "named from its id without the campaign's name")


func test_the_statement_moves_it_and_conditions_read_it() -> void:
	var st := _story()
	assert_eq(Factions.standing(st, "test_guild"), 0)
	assert_eq(str(_play(st, "ask")["text"]), "The guild looks away.")
	var beat := _play(st, "praise")
	assert_eq(str(beat["text"]), "Test Guild: standing +2 (now 2)")
	assert_eq(Factions.standing(st, "test_guild"), 2)
	assert_eq(str(_play(st, "ask")["text"]), "The guild nods you through.", "standing.test_guild >= 2 holds")
	assert_true(StoryConditions.check("standing.test_guild", st), "bare: above 0")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(Factions.standing(back, "test_guild"), 2, "a save keeps it (a story flag)")


func test_past_the_thresholds_every_member_follows_it() -> void:
	var st := _story()
	_play(st, "praise")
	assert_eq(st.attitude("test_guild_baker"), "indifferent", "2 is short of friendly")
	_play(st, "praise")
	assert_eq(st.attitude("test_guild_baker"), "friendly", "at 3 the guild's members are friendly")
	assert_eq(st.attitude("test_loner"), "indifferent", "and no one outside it")
	st.attitudes["test_guild_baker"] = "indifferent"
	assert_eq(st.attitude("test_guild_baker"), "indifferent", "a member's own opinion wins")
	st.attitudes.erase("test_guild_baker")
	_play(st, "insult")
	_play(st, "insult")
	assert_eq(Factions.standing(st, "test_guild"), -6)
	assert_eq(st.attitude("test_guild_baker"), "hostile", "at -3 or less, hostile")


func test_the_campaign_sets_the_thresholds_limits_and_name() -> void:
	Campaign.use_config({"standing": {"friendly_at": 1, "max": 2}, "factions": {"test_guild": {"name": "the Bakers' Guild"}}})
	var st := _story()
	var beat := _play(st, "praise")
	_play(st, "praise")
	assert_eq(Factions.standing(st, "test_guild"), 2, "never past the campaign's max")
	assert_eq(st.attitude("test_guild_baker"), "friendly", "friendly from 1")
	assert_true(str(beat["text"]).begins_with("the Bakers' Guild: standing +2"))


func test_a_crime_against_a_member_costs_the_faction() -> void:
	var st := _story()
	Crime.offence(st, {"region": ""}, "test_guild_baker")
	assert_eq(Factions.standing(st, "test_guild"), -1, "word gets round")
	assert_eq(st.attitude("test_guild_baker"), "hostile", "and the victim thinks less of the party, as before")
	Crime.offence(st, {"region": ""}, "test_loner")
	assert_eq(Factions.standing(st, "test_guild"), -1, "a crime against an outsider costs the faction nothing")
