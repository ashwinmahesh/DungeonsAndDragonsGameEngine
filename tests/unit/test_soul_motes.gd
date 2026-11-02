extends TestCase
## A boss's count (Soul Motes): seeded from the story, grown by deaths near it (not constructs or undead), spent with
## its Reaction on a Critical Hit (`meter_crit`) or on mending as its turn starts (`meter_repair`).

const MOTES := {"id": "motes", "label": "Soul Motes", "start": 3,
	"start_from": {"flag": "test_deaths", "table": [[1, 1], [4, 2], [7, 3]]},
	"on": [{"event": "defeat", "near": "Test Effigy", "within": 30, "not_types": ["construct", "undead"]}]}


func _fight(deaths: int) -> Array:
	var st := StoryState.new()
	st.set_flag("test_deaths", deaths)
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var boss := e.add(TestChars.dummy(200, false, {"name": "Test Effigy", "type": "construct",
		"traits": [{"id": "crush", "name": "Crushing Blow", "meter_crit": {"meter": "motes", "cost": 1, "name": "Crushing Blow"}},
			{"id": "repair", "name": "Repair", "meter_repair": {"meter": "motes", "cost": 1, "heal": 20, "name": "Repair"}}]}),
		&"enemy", Vector2i(4, 3))
	var near := e.add(TestChars.dummy(5, false, {"name": "Cultist"}), &"enemy", Vector2i(6, 3))
	var gone := e.add(TestChars.dummy(5, false, {"name": "Husk", "type": "undead"}), &"enemy", Vector2i(6, 5))
	e.meters.setup(FightMeters.for_story([MOTES], st))
	TestCombat.start_with(e, hero)
	return [e, hero, boss, near, gone]


func test_seeded_from_the_story_and_grown_by_deaths_near_it() -> void:
	var got := _fight(5)
	var e := got[0] as Encounter
	assert_eq(e.meters.value("motes"), 5, "3 and 2 for five deaths on the vigil")
	e.deal_damage(null, got[3] as Combatant, [{"amount": 50, "type": "force"}], false, "Test", [])
	e.deal_damage(null, got[4] as Combatant, [{"amount": 50, "type": "force"}], false, "Test", [])
	e.meters.scan()
	assert_eq(e.meters.value("motes"), 6, "a cultist dying near it: +1; an undead: nothing")


func test_spent_on_a_critical_hit_and_on_mending() -> void:
	var got := _fight(0)
	var e := got[0] as Encounter
	var boss := got[2] as Combatant
	var details: Array = []
	assert_true(e.meters.crit_for(boss, details), "a hit made a Critical Hit")
	assert_eq(e.meters.value("motes"), 2)
	assert_false(boss.reaction_available)
	assert_false(e.meters.crit_for(boss, details), "its Reaction is spent")
	boss.reaction_available = true
	boss.creature.hp = boss.creature.max_hp() - 30
	e.meters.repair(boss)
	assert_eq(boss.creature.hp, boss.creature.max_hp() - 10, "Repair: 20 back")
	assert_eq(e.meters.value("motes"), 1)
