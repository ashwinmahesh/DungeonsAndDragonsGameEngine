extends TestCase
## Multiple Heads (a trait's `heads`; MonsterActions.heads_*) and a round event that strikes one creature at random
## (`one`): heads die to heavy damage in a turn, grow back two for one unless seared, a bite for each, and none left is death.

const BLOCK := {"id": "test_hydra", "name": "Test Hydra", "traits": [{"id": "test_heads", "name": "Test Heads", "heads": 3, "head_damage": 20}],
	"actions": [{"id": "multiattack", "name": "Multiattack", "kind": "multiattack", "multiattack": [{"action": "bite", "count": 3, "per_head": true}]},
		{"id": "bite", "name": "Bite", "kind": "melee", "attack": {"bonus": 5, "reach": 5}, "damage": [{"dice": "1d6", "type": "piercing"}]}]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var hydra := e.add(TestChars.dummy(300, false, BLOCK.duplicate(true)), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, hydra]


func test_heads_die_and_grow_back() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var hydra := got[2] as Combatant
	assert_eq(e.monster_actions.heads_of(hydra), 3)
	assert_eq(e.attacks.multiattack_total(hydra), 3, "a bite for each head")
	e.deal_damage(hero, hydra, [{"amount": 12, "type": "slashing"}], false, "test")
	e.deal_damage(hero, hydra, [{"amount": 12, "type": "slashing"}], false, "test")
	assert_eq(e.monster_actions.heads_of(hydra), 2, "24 in a turn: one head")
	e.deal_damage(hero, hydra, [{"amount": 30, "type": "slashing"}], false, "test")
	assert_eq(e.monster_actions.heads_of(hydra), 2, "one head a turn")
	assert_eq(e.attacks.multiattack_total(hydra), 2)
	var hp := hydra.creature.hp
	e.monster_actions.heads_regrow(hydra)
	assert_eq(e.monster_actions.heads_of(hydra), 4, "two for the one lost")
	assert_eq(hydra.creature.hp, hp + 20, "and 20 Hit Points")


func test_fire_stops_the_regrowth_and_the_last_head_is_death() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var hydra := got[2] as Combatant
	e.deal_damage(hero, hydra, [{"amount": 25, "type": "fire"}], false, "test")
	e.monster_actions.heads_regrow(hydra)
	assert_eq(e.monster_actions.heads_of(hydra), 2, "seared: nothing grows")
	hydra.set_meta("heads", 1)
	e.turn_index = 1 - e.turn_index   # another creature's turn
	e.deal_damage(hero, hydra, [{"amount": 25, "type": "slashing"}], false, "test")
	assert_true(hydra.creature.dead, "no heads left")


func test_a_round_event_that_strikes_one_at_random_even_a_captive() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var captive := e.add(TestChars.dummy(300, false, {"name": "Test Captive"}), &"neutral", Vector2i(8, 3))
	TestCombat.punching_bag(e, Vector2i(11, 7), 500)   # a foe, so the fight goes on
	e.legendary.set_round_events([{"id": "test_lash", "kind": "save", "affects": "all", "one": true, "at": 20, "every": 1,
		"save": {"ability": "dex", "dc": 40}, "damage": {"dice": "1d4", "type": "force"}}])
	var start := [hero.creature.hp, captive.creature.hp]
	TestCombat.start_with(e, hero)
	for i in 12:
		e.end_turn()
	var lashes := e.log.texts().filter(func(t: String) -> bool: return t.contains("Force damage")).size()
	var rounds := e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "round_event").size()
	assert_true(rounds >= 2, "the table acted each round")
	assert_eq(lashes, rounds, "one creature a round")
	assert_true(hero.creature.hp < start[0] or captive.creature.hp < start[1])


func test_one_head_back_a_turn() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hydra := got[2] as Combatant
	((hydra.creature as Monster).data["traits"] as Array)[0]["regrow_one"] = true
	((hydra.creature as Monster).data["traits"] as Array)[0]["stops_regrowth"] = []
	hydra.set_meta("heads", 1)
	e.monster_actions.heads_regrow(hydra)
	assert_eq(e.monster_actions.heads_of(hydra), 2, "one back")
	e.monster_actions.heads_regrow(hydra)
	e.monster_actions.heads_regrow(hydra)
	assert_eq(e.monster_actions.heads_of(hydra), 3, "never past three")
