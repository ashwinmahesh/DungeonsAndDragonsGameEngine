extends TestCase
## The party composition's gaps that name a land (PartyCoverage.WORDS, CampaignModule.coverage_words): the engine's
## words unless the campaign gives its own.


func _party() -> Array[Character]:
	var out: Array[Character] = []
	out.append(TestChars.pregen("ilse_varga", 1))   # a human fighter: no darkvision, no Radiant damage
	return out


func _gap_with(gaps: Array, part: String) -> String:
	for g: Variant in gaps:
		if str(g).contains(part):
			return str(g)
	return ""


func test_the_engines_words_by_default() -> void:
	var cov := PartyCoverage.analyze(_party())
	var dark := _gap_with(cov["gaps"] as Array, "can't see in the dark")
	assert_true(dark.ends_with(str(PartyCoverage.WORDS["dark"])), dark)
	assert_true(str(PartyCoverage.WORDS["radiant"]) in (cov["gaps"] as Array))
	assert_eq(CampaignModule.new().coverage_words(), {}, "the base module keeps them")


func test_a_campaigns_own_words() -> void:
	var words := {"dark": "Test night never ends.", "radiant": "Test: nothing here burns the dead."}
	var cov := PartyCoverage.analyze(_party(), words)
	var gaps := cov["gaps"] as Array
	var dark := _gap_with(gaps, "can't see in the dark")
	assert_true(dark.ends_with("Test night never ends."), dark)
	assert_true("Test: nothing here burns the dead." in gaps)
	for g: Variant in gaps:
		assert_false(str(g).contains("Barovia"), str(g))
