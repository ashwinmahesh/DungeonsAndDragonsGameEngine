extends TestCase
## The Narrator's `cooldown n` (story/narrator.gd): n game minutes between a trigger's lines, or n rounds within one
## fight. Lane 24's find (2026-10-12): the parser's line number overwrote the minutes, so every cooldown was the line's
## number in its file instead (a "cooldown 30" became 10; combat lines cooled for hundreds of rounds).

const LINES := """# a comment, so the cooldown's line number isn't its minutes
~ test:minutes
| The wind changes.
| The water darkens.
cooldown 30

~ combat:test_crit
| A clean strike.
| A cruel strike.
cooldown 3
"""


func _story(location: String = "fixture_place") -> StoryState:
	return SideQuestPlay.party(["ilse_varga"], 3, location, 12)


func test_the_cooldown_keeps_its_minutes() -> void:
	var f := DialogueFile.parse(LINES, "narrator/test_cooldown")
	var cool := (f.nodes["test:minutes"] as Array).filter(func(s: Dictionary) -> bool: return str(s["t"]) == "cooldown")
	assert_eq(int((cool[0] as Dictionary)["minutes"]), 30)
	assert_eq(int((cool[0] as Dictionary)["n"]), 5, "n stays the line number (once-flags in saves are keyed on it)")


func test_a_cooldown_in_minutes_is_honoured() -> void:
	var n := Narrator.new(1)
	n.add_file(DialogueFile.parse(LINES, "narrator/test_cooldown"))
	var st := _story()
	assert_ne(n.line("test:minutes", st), "")
	st.advance_minutes(29)
	assert_eq(n.line("test:minutes", st), "", "29 minutes: still cooling")
	st.advance_minutes(1)
	assert_ne(n.line("test:minutes", st), "", "30 minutes: speaks again")


func test_a_cooldown_in_rounds_is_honoured_within_a_fight() -> void:
	var n := Narrator.new(1)
	n.add_file(DialogueFile.parse(LINES, "narrator/test_cooldown"))
	var st := _story()
	assert_ne(n.line("combat:test_crit", st, null, {"round": 1, "fight": "a"}), "")
	assert_eq(n.line("combat:test_crit", st, null, {"round": 3, "fight": "a"}), "", "two rounds on: cooling")
	assert_ne(n.line("combat:test_crit", st, null, {"round": 4, "fight": "a"}), "", "three rounds on: speaks")
	assert_ne(n.line("combat:test_crit", st, null, {"round": 1, "fight": "b"}), "", "a new fight's round 1 isn't cooling")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(n.line("combat:test_crit", back, null, {"round": 2, "fight": "b"}), "", "and the memory saves")


## The host game's own narrator files: every trigger with a cooldown in minutes stays quiet for all but the last minute of
## it, once it has spoken (the party is taken to the place the file is named for, as the file's conditions often ask).
func test_the_hosts_cooldowns_hold_for_their_minutes() -> void:
	var dir := DirAccess.open(DialogueFile.ROOT + "narrator")
	if dir == null:
		return
	var n := Narrator.new(1)
	for file: String in dir.get_files():
		if not file.ends_with(".dialogue"):
			continue
		var df := DialogueFile.load_key("narrator/" + file.get_basename())
		for key: String in df.order:
			if key.begins_with("combat:"):
				continue
			var minutes := 0
			for s: Dictionary in df.nodes[key]:
				if str(s["t"]) == "cooldown":
					minutes = int(s["minutes"])
			if minutes <= 1:
				continue
			var st := _story(file.get_basename())
			var spoke := false
			for i in 20:   # until its conditions let it speak
				if n.line(key, st) != "":
					spoke = true
					break
				st.advance_minutes(60)
			if not spoke:
				continue
			st.advance_minutes(minutes - 1)
			assert_eq(n.line(key, st), "", "%s cools for %d minutes, not its line number" % [key, minutes])
