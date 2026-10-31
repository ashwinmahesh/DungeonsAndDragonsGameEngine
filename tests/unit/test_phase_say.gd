extends TestCase
## A boss phase that speaks (combat/boss_phases.gd, CombatView._phase_begins; docs/contracts/combat.md): its `say` is a
## Narrator line the fight's view speaks as the phase begins, and its `cutscene` plays with that line as the caption
## (Cutscenes.for_moment), else a cutscene the key triggers.

const LINES := """
~ test_phase:turns
| The test boss turns on you.
"""


func after_each() -> void:
	Cutscenes.clear_cache()


static func _boss(phase: Dictionary) -> Dictionary:
	return {"id": "test_boss", "name": "Test Boss", "size": "large", "type": "construct", "ac": 15,
		"hp": {"average": 100, "dice": "10d10+45"}, "speed": {"walk": 30},
		"abilities": {"str": 18, "dex": 12, "con": 16, "int": 10, "wis": 10, "cha": 10}, "cr": 4, "proficiency_bonus": 2,
		"actions": [{"id": "claw", "name": "Claw", "kind": "melee", "attack": {"bonus": 30, "reach": 5},
			"damage": [{"average": 5, "dice": "1d1+4", "type": "slashing"}], "summary": "A claw."}],
		"ai_profile": "brute", "phases": [phase]}


static func _phase(extra: Dictionary = {}) -> Dictionary:
	var p := {"id": "turn", "name": "The Turn", "summary": "Bloodied: it turns on you.", "when": {"bloodied": true},
		"say": "test_phase:turns"}
	p.merge(extra, true)
	return p


func _fight(phase: Dictionary) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var boss := e.add(Monster.from_data(_boss(phase)), &"enemy", Vector2i(6, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	TestCombat.start_with(e, hero)
	e.drain_events()
	e.deal_damage(null, boss, [{"amount": 55, "type": "force"}], false, "test")
	return [e, boss]


static func _phase_event(e: Encounter) -> Dictionary:
	for ev in e.drain_events():
		if str(ev["type"]) == "phase":
			return ev
	return {}


func test_the_phase_event_carries_its_line_and_its_cutscene() -> void:
	var got := _fight(_phase({"cutscene": "test_phase_picture"}))
	var ev := _phase_event(got[0] as Encounter)
	assert_eq(str(ev.get("say", "")), "test_phase:turns", "the Narrator key")
	assert_eq(str(ev.get("cutscene", "")), "test_phase_picture", "and the cutscene it plays")
	var plain := _fight(_phase())
	assert_eq(str(_phase_event(plain[0] as Encounter).get("cutscene", "?")), "", "none named: empty")


func test_the_view_speaks_the_phase_line_in_the_fight() -> void:
	var got := _fight(_phase())
	var e := got[0] as Encounter
	var ev := _phase_event(e)
	var view := CombatView.new()
	view.e = e
	view._log_held = true   # no HUD in this test
	view.narrator = Narrator.new(1)
	view.narrator.add_file(DialogueFile.parse(LINES, "narrator/test_phase"))
	view.story = StoryState.new()
	view._phase_begins(ev)
	var said := e.log.entries.filter(func(en: Dictionary) -> bool: return str(en.get("kind", "")) == "narr")
	assert_eq(said.size(), 1, "one Narrator line in the fight's log")
	assert_true(str((said[0] as Dictionary).get("text", "")).contains("turns on you"))
	view._phase_begins({"type": "phase", "id": (got[1] as Combatant).id, "say": ""})
	assert_eq(e.log.entries.filter(func(en: Dictionary) -> bool: return str(en.get("kind", "")) == "narr").size(), 1,
		"a phase with no line says nothing")
	view.free()


func test_a_named_cutscene_wins_over_the_keys_own() -> void:
	var st := StoryState.new()
	Cutscenes.register({"id": "test_phase_triggered", "trigger": "test_phase:turns", "images": [{"image": "test_a"}]})
	Cutscenes.register({"id": "test_phase_picture", "images": [{"image": "test_b"}], "once": true})
	Cutscenes.register({"id": "test_phase_hidden", "images": [{"image": "test_c", "when": "flag.never_set"}]})
	assert_eq(Cutscenes.for_moment("test_phase:turns", "test_phase_picture", st), "test_phase_picture", "the phase's own")
	assert_eq(Cutscenes.for_moment("test_phase:turns", "", st), "test_phase_triggered", "none named: the key's trigger")
	assert_eq(Cutscenes.for_moment("test_phase:turns", "test_phase_hidden", st), "test_phase_triggered",
		"one with no picture for this story now falls back to the key's")
	Cutscenes.mark_played("test_phase_picture", st)
	assert_eq(Cutscenes.for_moment("test_phase:turns", "test_phase_picture", st), "test_phase_triggered", "a `once` one shown")
	assert_eq(Cutscenes.for_moment("no_such_key", "", st), "", "nothing for a key with none")
