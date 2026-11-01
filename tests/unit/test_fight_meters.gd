extends TestCase
## A fight's meters (an encounter's `meters`; FightMeters, docs/contracts/combat.md "Meters"): the heroes move a count
## with checks beside what it names, a failure can hurt, and reaching a mark sets a flag or ends the fight.

const METER := {"id": "test_trust", "label": "Trust", "start": 1, "min": 0, "max": 4,
	"actions": [{"id": "calm", "label": "Calm the guide", "cost": "bonus", "near": "Test Guide", "range": 10,
		"check": {"skill": "persuasion", "dc": 5}, "success": 2, "failure": -1, "failure_damage": {"dice": "1d4", "type": "psychic"}}],
	"marks": [{"value": 3, "flag": "test_trust_half"}, {"value": 4, "outcome": "victory"}, {"value": 0, "falling": true, "outcome": "defeat"}]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	TestCombat.punching_bag(e, Vector2i(10, 6), 300)
	var guide := e.add(TestChars.dummy(20, false, {"name": "Test Guide"}), &"neutral", Vector2i(4, 3))
	e.meters.setup([METER.duplicate(true)])
	TestCombat.start_with(e, hero)
	return [e, hero, guide]


func test_the_hotbar_moves_the_meter_and_its_marks_go_off() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var cat := ActionCatalog.new(e)
	var act := cat.find(hero, "meter:test_trust:calm")
	assert_false(act.is_empty())
	assert_eq(str(act["cost"]), "bonus")
	assert_true(bool(act["legal"]), "10 ft from the guide")
	assert_eq(e.meters.lines(), ["Trust 1 / 4"] as Array[String], "for the HUD")
	TestCombat.next_d20(e, 20)
	assert_true(cat.perform(hero, act).ok)
	assert_eq(e.meters.value("test_trust"), 3, "+2")
	assert_true(bool(e.legendary.story_flags.get("test_trust_half", false)), "the mark at 3 sets its flag")
	assert_eq(e.state, Encounter.State.ACTIVE)
	e.meters.change("test_trust", 5)
	assert_eq(e.meters.value("test_trust"), 4, "never past its max")
	assert_eq(e.outcome, "victory", "the mark at 4 wins the fight")


func test_a_failure_hurts_and_falling_to_the_bottom_loses() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var hp := hero.creature.hp
	TestCombat.next_d20(e, 1)
	assert_true(e.meters.take(hero, "test_trust", "calm").ok)
	assert_true(hero.creature.hp < hp, "the failure hurts whoever tried")
	assert_eq(e.meters.value("test_trust"), 0, "-1")
	assert_eq(e.outcome, "defeat", "falling to 0 loses")


func test_only_beside_what_it_names() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	hero.cell = Vector2i(11, 0)
	assert_true(e.meters.why_not(hero, (METER["actions"] as Array)[0] as Dictionary).begins_with("Get within 10 ft"))


func test_a_saved_round_keeps_the_count() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	e.meters.change("test_trust", 2)
	var other := FightMeters.new(e)
	other.from_dict(e.meters.to_dict())
	other.setup([METER.duplicate(true)])
	assert_eq(other.value("test_trust"), 3, "the value comes back, not the start")
	other.change("test_trust", -1)
	other.change("test_trust", 1)
	assert_false(e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "meter_mark").size() > 1, "a mark reached once stays reached")
