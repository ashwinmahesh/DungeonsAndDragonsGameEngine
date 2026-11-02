extends TestCase
## Several ways at a set piece (`undo.ways`, folded under one entry) and its backlash on a failed try or a blow.

const STONE := {"id": "test_stone", "kind": "vessel", "cell": [4, 3], "name": "a standing stone", "ac": 17, "hp": 30,
	"undo": {"label": "Disable", "dc": 15, "ways": [{"label": "brute force", "skills": ["athletics", "sleight_of_hand"]},
		{"label": "its old faith", "skills": ["nature", "religion"]}],
		"backlash": {"save": {"ability": "dex", "dc": 40}, "damage": {"dice": "2d6", "type": "fire"}, "half": true, "on_hit": true}}}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 5)
	TestCombat.punching_bag(e, Vector2i(10, 6), 300)
	var stone := e.objects.put(STONE.duplicate(true))
	TestCombat.start_with(e, hero)
	return [e, hero, stone]


func test_the_ways_fold_under_one_entry_and_a_failure_burns() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var cat := ActionCatalog.new(e)
	var group: Dictionary = {}
	for a: Dictionary in cat.slots(hero, ActionCatalog.COMMON):
		if bool(a.get("group", false)) and str(a.get("label", "")).begins_with("Disable"):
			group = a
	assert_eq((group.get("items", []) as Array).size(), 2, "two ways, one entry")
	var hp := hero.creature.hp
	TestCombat.next_d20(e, 1)
	assert_true(cat.perform(hero, cat.find(hero, "undo:test_stone|1")).ok)
	assert_false((got[2] as BattleObject).destroyed, "a 1 fails")
	assert_true(hero.creature.hp < hp, "and the stone's flame burns the one who tried")


func test_a_blow_on_it_lashes_back() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var hp := hero.creature.hp
	e.objects.damage(got[2] as BattleObject, [{"amount": 5, "type": "bludgeoning"}], hero, "test")
	assert_true(hero.creature.hp < hp, "on_hit: whoever strikes it is burned")
