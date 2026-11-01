extends TestCase
## Fling (`do: fling`; MonsterActions.fling, AiBrain._multi_step): a creature held is thrown at another foe in range,
## the grapple ends, and both save or take the damage and fall Prone.

const FLING := {"id": "test_fling", "name": "Test Fling", "kind": "special", "do": "fling", "save": {"ability": "dex", "dc": 40, "success": "half"},
	"targets": {"range": 30, "count": 1, "max_size": "large", "requires": ["grappled"]}, "damage": [{"dice": "2d8", "type": "bludgeoning"}],
	"on_fail": [{"do": "condition", "condition": "prone", "until": "permanent"}]}


func test_a_held_creature_thrown_at_another() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 3)
	var b := TestCombat.hero(e, "thistle", Vector2i(8, 5), 3)
	var reaper := e.add(TestChars.dummy(200, false, {"name": "Test Reaper", "actions": [FLING]}), &"enemy", Vector2i(4, 3))
	TestCombat.start_with(e, reaper)
	e.monster_actions.grapple(reaper, a, 15, 4, "Test Chain", false)
	assert_true(e.grapples.has(a.id))
	var hp := [a.creature.hp, b.creature.hp]
	var r := e.monster_actions.fling(reaper, FLING)
	assert_true(r.ok, r.reason)
	assert_false(e.grapples.has(a.id), "let go")
	assert_true(e.distance(a, b) <= 5, "lands beside the other")
	assert_true(a.creature.hp < hp[0] and b.creature.hp < hp[1], "both hurt")
	assert_true(a.creature.has_condition(&"prone") and b.creature.has_condition(&"prone"), "both down")
	assert_false(reaper.action_available, "its action")


func test_nobody_held_nothing_thrown() -> void:
	var e := TestCombat.open_field(3)
	var reaper := e.add(TestChars.dummy(200, false, {"name": "Test Reaper", "actions": [FLING]}), &"enemy", Vector2i(4, 3))
	TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 3)
	TestCombat.start_with(e, reaper)
	assert_false(e.monster_actions.fling(reaper, FLING).ok)


## A trait that answers a hit (`when_hit`: The Jailer's chain): once a turn, whoever hits it saves or is held.
func test_a_chain_that_answers_a_hit() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 3)
	var jailer := e.add(TestChars.dummy(300, false, {"name": "Test Jailer", "ac": 1, "traits": [{"id": "test_jailer", "name": "Test Jailer",
		"when_hit": {"riders": [{"do": "grapple", "escape_dc": 13, "save": {"ability": "str", "dc": 40}}]}}]}), &"enemy", Vector2i(4, 3))
	TestCombat.start_with(e, hero)
	e.monster_actions.when_hit(hero, jailer)
	assert_true(e.grapples.has(hero.id), "the chain holds whoever hit it")
	e.grapples.erase(hero.id)
	hero.creature.remove_condition(&"grappled")
	e.monster_actions.when_hit(hero, jailer)
	assert_false(e.grapples.has(hero.id), "once a turn")
