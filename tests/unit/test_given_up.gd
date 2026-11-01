extends TestCase
## Features and feats a hero gave up for good (the build's `given_up`, Character.give_up): refresh leaves them out, and
## a rebuild from the saved build does too.


func test_a_given_up_feature_is_gone_and_stays_gone() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 5)
	var picked := ""
	for f: Dictionary in ch.features:
		if str(f.get("source_kind", "")) == "class" and str(f["id"]) != "":
			picked = str(f["id"])
			break
	assert_ne(picked, "", "the hero has a class feature to give up")
	ch.give_up(picked)
	assert_false(ch.features.any(func(f: Dictionary) -> bool: return str(f["id"]) == picked), "gone")
	var back := Character.from_build(ch.build.duplicate(true))
	assert_false(back.features.any(func(f: Dictionary) -> bool: return str(f["id"]) == picked), "a rebuild keeps it gone")
	assert_eq(back.given_up(), [picked] as Array[String])


func test_a_given_up_feat_is_gone() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 5)
	assert_false(ch.feats_taken.is_empty())
	var feat := str(ch.feats_taken[0]["id"])
	ch.give_up(feat)
	assert_false(ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == feat))
