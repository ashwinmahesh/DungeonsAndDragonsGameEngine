extends TestCase
## A feat the story gives a hero for good (StoryBoons.grant_feat): kept in the build's `story_feats`, it survives a
## rebuild and a save, the sheet names where it came from, and a feat can't be given twice unless it's repeatable.


func test_a_granted_feat_works_and_is_kept() -> void:
	var ch := TestChars.pregen("silvain_aster", 3)
	var before := ch.initiative_bonus().total() if ch.has_method("initiative_bonus") else 0
	assert_true(StoryBoons.grant_feat(ch, "alert", "A gift of the test"))
	var taken := ch.feats_taken.filter(func(f: Dictionary) -> bool: return str(f["id"]) == "alert")
	assert_eq(taken.size(), 1)
	assert_eq(str((taken[0] as Dictionary)["source"]), "A gift of the test", "named for where it came from")
	assert_false(StoryBoons.grant_feat(ch, "alert", "Again"), "not twice")
	assert_false(StoryBoons.grant_feat(ch, "no_such_feat", "Nobody"))
	var back := Character.from_build(ch.build.duplicate(true))
	assert_true(back.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "alert"), "a rebuild keeps it")
	if ch.has_method("initiative_bonus"):
		assert_true(ch.initiative_bonus().total() > before, "Alert works")
