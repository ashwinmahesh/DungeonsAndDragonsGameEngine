extends TestCase
## The campaign's counters beside the gold (campaign.json `counters`; ExploreHud.counters_text): a currency shown while
## its `when` holds and the party has some.


func after_each() -> void:
	Campaign.use_config(null)


func test_tickets_beside_the_gold() -> void:
	Campaign.use_config({"counters": [{"flag": "test_tickets", "label": "tickets", "when": "flag.test_at_fair"}]})
	var st := StoryState.new()
	assert_eq(ExploreHud.counters_text(st), "", "none yet")
	st.flags["test_tickets"] = 3
	assert_eq(ExploreHud.counters_text(st), "", "not at the fair")
	st.flags["test_at_fair"] = true
	assert_eq(ExploreHud.counters_text(st), " · 3 tickets")
