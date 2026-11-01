extends TestCase
## A campaign's own approval roster (data/campaign.json `approval`): its companions score, see choices and survive a
## load; its romances and tier words replace Curse of Strahd's; without the key everything is as before.


func after_each() -> void:
	Campaign.use_config(null)


func test_without_the_key_the_six_stay() -> void:
	Campaign.use_config({})
	assert_eq(Approval.companions(), Approval.STRAHD_COMPANIONS)
	assert_eq(Approval.romances(), Approval.STRAHD_ROMANCES)
	assert_true(str(Approval.tier_for(60)["says"]).contains("castle"))
	var st := StoryState.new()
	st.party = [TestChars.pregen("thistle", 3)] as Array[Character]
	Approval.react(st, [["thistle", 10]], "test")
	assert_eq(Approval.score(st, "thistle"), 10)


func test_a_campaign_roster_scores_and_survives_a_load() -> void:
	Campaign.use_config({"approval": {"companions": ["silvain_aster"], "tier_says": {"devoted": "Would walk into the dark with you."},
		"romances": [{"flag": "romance_test", "pair": ["silvain_aster", "someone_else"]}]}})
	assert_eq(Approval.companions(), ["silvain_aster"] as Array[String])
	var st := StoryState.new()
	st.party = [TestChars.pregen("silvain_aster", 3), TestChars.pregen("thistle", 3)] as Array[Character]
	assert_eq(Approval.witnesses(st), ["silvain_aster"] as Array[String], "the six aren't this campaign's")
	Approval.react(st, [["silvain_aster", 60], ["thistle", 10]], "test")
	assert_eq(Approval.score(st, "silvain_aster"), 60)
	assert_eq(Approval.score(st, "thistle"), 0)
	assert_eq(str(Approval.tier(st, "silvain_aster")["says"]), "Would walk into the dark with you.")
	assert_eq(str(Approval.tiers()[1]["says"]), str(Approval.TIERS[1]["says"]), "the others keep theirs")
	var back := Approval.from_save(st.approval.duplicate(true))
	assert_eq(int((back["silvain_aster"] as Dictionary)["score"]), 60, "kept through a load")
	assert_eq(Approval.romances().size(), 1)
