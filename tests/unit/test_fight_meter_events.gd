extends TestCase
## Meters moved by what happens in a fight (`on`: defeat, crit, failed_save), a mark that frees a captive (`take`), a
## fight foes don't end (`ends_when.foes_end_it: false`), and a round event that possesses a hero (`possess`).

const METER := {"id": "test_hope", "label": "Hope", "max": 10,
	"on": [{"event": "defeat", "side": "enemy", "delta": 2}, {"event": "failed_save", "side": "party", "delta": -1}],
	"marks": [{"value": 2, "take": ["Test Captive"], "flag": "test_freed"}]}


func _fight(ends: Dictionary = {}) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	e.ends_when = ends
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3), 5)
	var second := TestCombat.punching_bag(e, Vector2i(9, 6), 500)
	var captive := e.add(TestChars.dummy(20, false, {"name": "Test Captive"}), &"guest", Vector2i(1, 6))
	e.meters.setup([METER.duplicate(true)])
	TestCombat.start_with(e, hero)
	return [e, hero, foe, captive, second]


func test_a_foe_falling_moves_the_meter_and_the_mark_frees_the_captive() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var captive := got[3] as Combatant
	e.deal_damage(null, got[2] as Combatant, [{"amount": 50, "type": "force"}], false, "Test", [])
	e.meters.scan()
	assert_eq(e.meters.value("test_hope"), 2, "a foe down: +2, once")
	e.meters.scan()
	assert_eq(e.meters.value("test_hope"), 2)
	assert_eq(str(captive.get_meta("left_fight", "")), "rescued", "the mark frees the captive")
	assert_true(bool(e.legendary.story_flags.get("test_freed", false)))
	var hero := got[1] as Combatant
	TestCombat.next_d20(e, 1)
	var t := hero.creature.roll_save(e.dice, &"wis", 30, [], [], "test")
	e.events.append({"type": "save", "id": hero.id, "test": t})
	e.drain_events()
	assert_eq(e.meters.value("test_hope"), 1, "a hero's failed save: -1, read before the view takes the events")


func test_a_fight_the_foes_dont_end() -> void:
	var got := _fight({"foes_end_it": false, "rounds": 2, "rounds_outcome": "victory"})
	var e := got[0] as Encounter
	for f in [got[2], got[4]]:
		e.deal_damage(null, f as Combatant, [{"amount": 900, "type": "force"}], false, "Test", [])
	e._check_over()
	assert_eq(e.state, Encounter.State.ACTIVE, "no foes, but the clock decides")
	for i in 20:
		if e.state != Encounter.State.ACTIVE:
			break
		e.end_turn()
	assert_eq(e.outcome, "victory", "as its clock ran out")


func test_a_possession_turns_a_hero_and_lets_go() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	TestCombat.hero(e, "thistle", Vector2i(3, 3), 5)
	TestCombat.punching_bag(e, Vector2i(9, 6), 500)
	e.legendary.set_round_events([{"id": "test_souls", "name": "Test Souls", "kind": "possess", "affects": "party", "one": true,
		"save": {"ability": "cha", "dc": 40}, "rounds": 2, "at": 20, "every": 1}])
	TestCombat.start_with(e, hero)
	var possessed: Combatant = null
	for i in 10:
		for c in e.combatants:
			if c.has_meta("possessed_by"):
				possessed = c
		if possessed != null:
			break
		e.end_turn()
	assert_true(possessed != null, "a hero is taken (DC 40)")
	assert_eq(possessed.side, &"enemy", "on the other side")
	assert_false(possessed.is_player_controlled(), "the AI plays it, as a ghost's body")
	for i in 20:
		if not possessed.has_meta("possessed_by"):
			break
		e.end_turn()
	assert_false(possessed.has_meta("possessed_by"), "its rounds run out")
	assert_eq(possessed.side, &"party")
	assert_true(possessed.is_player_controlled(), "the player has it back")
