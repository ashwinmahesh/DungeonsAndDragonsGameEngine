extends TestCase
## What rescues need beside clocks and meters: a round event that strikes one creature at random and takes a round off
## the clock when it catches the captive (`one`, `clock`, `clock_if`), meter actions with no check, once a fight, and
## only when the story allows (FightMeters.for_story), and a failure's damage of a random type.

const METER := {"id": "test_trust", "label": "Trust", "start": 0, "max": 6,
	"actions": [
		{"id": "token", "label": "Show the token", "cost": "bonus", "success": 3, "once": true, "when": "flag.test_token"},
		{"id": "trick", "label": "Try the trick", "check": {"skill": "athletics", "dc": 30},
			"failure_damage": {"dice": "1d4", "type": ["fire", "poison", "piercing"]}}]}


func _fight(ends: Dictionary = {}) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	e.ends_when = ends
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	TestCombat.punching_bag(e, Vector2i(10, 6), 500)
	var captive := e.add(TestChars.dummy(40, false, {"name": "Test Captive"}), &"guest", Vector2i(5, 5))
	return [e, hero, captive]


func test_a_round_lost_brings_the_clock_nearer_and_it_rings_once() -> void:
	var got := _fight({"rounds": 4, "rounds_outcome": "none", "rounds_flag": "test_time_up"})
	var e := got[0] as Encounter
	TestCombat.start_with(e, got[1] as Combatant)
	assert_eq(e.turns.clock_left(), 4)
	e.meters.shift_clock(-1)
	assert_eq(e.turns.clock_left(), 3, "a round lost")
	for i in 30:
		if e.round_no >= 4:
			break
		e.end_turn()
	assert_true(bool(e.legendary.story_flags.get("test_time_up", false)), "it ran out as round 3 ended")
	assert_eq(e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "clock").size(), 1)
	for i in 6:
		e.end_turn()
	assert_eq(e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "clock").size(), 1, "once")
	var back := FightMeters.new(e)
	back.from_dict(e.meters.to_dict())
	assert_eq([back.clock_lost, back.clock_rang], [1, true], "kept in a round's save")


func test_a_burst_on_one_creature_takes_a_round_when_it_catches_the_captive() -> void:
	var got := _fight({"rounds": 10, "rounds_outcome": "none"})
	var e := got[0] as Encounter
	e.legendary.set_round_events([{"id": "test_burst", "kind": "text", "affects": "party", "one": true, "clock": -1,
		"clock_if": ["Test Captive"], "at": 20, "every": 1}])
	TestCombat.start_with(e, got[1] as Combatant)
	for i in 30:
		if e.round_no >= 8:
			break
		e.end_turn()
	var bursts := e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "round_event")
	assert_true(bursts.size() >= 6)
	var on_captive := 0
	for b: Dictionary in bursts:
		assert_eq((b["targets"] as Array).size(), 1, "one creature each time")
		if (b["targets"] as Array)[0] == (got[2] as Combatant).id:
			on_captive += 1
	assert_true(on_captive > 0 and on_captive < bursts.size(), "sometimes the captive, sometimes the hero")
	assert_eq(e.meters.clock_lost, on_captive, "a round off for each burst on the captive")


func test_meter_actions_without_a_check_once_and_by_the_story() -> void:
	var st := StoryState.new()
	assert_eq(((FightMeters.for_story([METER], st)[0] as Dictionary)["actions"] as Array).size(), 1, "no token, no word")
	st.flags["test_token"] = true
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	e.meters.setup(FightMeters.for_story([METER], st))
	TestCombat.start_with(e, hero)
	var cat := ActionCatalog.new(e)
	var act := cat.find(hero, "meter:test_trust:token")
	assert_eq(str(act["sub"]), "No check")
	assert_true(cat.perform(hero, act).ok)
	assert_eq(e.meters.value("test_trust"), 3, "+3, no roll")
	e.end_turn()
	e.end_turn()
	while e.current() != hero:
		e.end_turn()
	assert_false(bool(cat.find(hero, "meter:test_trust:token")["legal"]), "once a fight")
	var hp := hero.creature.hp
	assert_true(cat.perform(hero, cat.find(hero, "meter:test_trust:trick")).ok)
	assert_true(hero.creature.hp < hp, "a failure hurts")
	var dmg := e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "damage")
	assert_true(dmg.is_empty() or str((dmg[-1] as Dictionary).get("damage_type", "fire")) in ["fire", "poison", "piercing"])
