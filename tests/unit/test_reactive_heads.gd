extends TestCase
## More of Multiple Heads: Reactive Heads (`oa_per_head`: an Opportunity Attack a round for each head beyond the first),
## named heads (`head_names`, legendary options with `requires_head`), and a grapple rider that lets go by itself
## (`until: target_turn_end`).

const BLOCK := {"id": "test_hydra", "name": "Test Hydra", "traits": [{"id": "test_heads", "name": "Test Heads", "heads": 3,
		"head_damage": 20, "oa_per_head": true, "head_names": ["test_red", "test_green", "test_blue"]}],
	"actions": [{"id": "bite", "name": "Bite", "kind": "melee", "attack": {"bonus": 5, "reach": 5}, "damage": [{"dice": "1d4", "type": "piercing"}]}],
	"legendary_actions": {"per_round": 2, "options": [
		{"id": "test_snap", "name": "Snap", "summary": "A bite.", "action": "bite"},
		{"id": "test_glare", "name": "Glare", "summary": "The red head's.", "action": "bite", "requires_head": "test_red"}]}}


func _fight(block: Dictionary = BLOCK) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var hydra := e.add(TestChars.dummy(300, false, block.duplicate(true)), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, hydra]


func _oas(e: Encounter) -> int:
	return e.log.texts().filter(func(t: String) -> bool: return t.contains("makes an Opportunity Attack")).size()


func test_an_opportunity_attack_for_each_head() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var hydra := got[2] as Combatant
	assert_eq(e.monster_actions.spare_oa(hydra), 2, "two heads beyond the first")
	for cell: Vector2i in [Vector2i(1, 3), Vector2i(2, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(1, 3)]:
		e.move(hero, cell)
	assert_eq(_oas(e), 3, "three heads, three Opportunity Attacks")
	assert_false(hydra.reaction_available)
	assert_eq(e.monster_actions.spare_oa(hydra), 0)
	hydra.set_meta("heads", 1)
	hydra.set_meta("oa_spare", {})
	assert_eq(e.monster_actions.spare_oa(hydra), 0, "one head: just its Reaction")


func test_without_the_flag_one_opportunity_attack() -> void:
	var block := BLOCK.duplicate(true)
	((block["traits"] as Array)[0] as Dictionary).erase("oa_per_head")
	var got := _fight(block)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	for cell: Vector2i in [Vector2i(1, 3), Vector2i(2, 3), Vector2i(1, 3)]:
		e.move(hero, cell)
	assert_eq(_oas(e), 1)


func test_named_heads_die_and_their_options_go_with_them() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var hydra := got[2] as Combatant
	assert_eq(e.legendary.options(hydra).size(), 2)
	e.deal_damage(hero, hydra, [{"amount": 25, "type": "slashing"}], false, "test")
	var alive := e.monster_actions.heads_alive(hydra)
	assert_eq(alive.size(), 2, "one of the three, at random")
	assert_eq(e.legendary.options(hydra).size(), 2 if "test_red" in alive else 1)
	hydra.set_meta("heads_alive", ["test_green", "test_blue"])
	assert_eq(e.legendary.options(hydra).map(func(o: Variant) -> String: return str((o as Dictionary)["id"])), ["test_snap"], "no glare without the red head")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Test Hydra's heads dies")))
	e.monster_actions.heads_regrow(hydra)
	assert_eq(e.monster_actions.heads_of(hydra), 4)
	assert_true("test_red" in e.monster_actions.heads_alive(hydra), "regrown heads come back by name")
	assert_eq(e.legendary.options(hydra).size(), 2)


func test_a_hold_that_lets_go_at_the_end_of_the_held_creatures_next_turn() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var hydra := got[2] as Combatant
	var rd := {"do": "grapple", "escape_dc": 30, "until": "target_turn_end"}
	e.monster_actions.apply_riders(hydra, hero, [rd], {}, "Test Grip")   # during the hero's own turn
	assert_eq(str(e.grapples.get(hero.id, "")), hydra.id)
	e.end_turn()   # this turn does not count
	assert_true(e.grapples.has(hero.id), "held through the turn it began in")
	while e.current() != hero:
		e.end_turn()
	e.end_turn()
	assert_false(e.grapples.has(hero.id), "let go at the end of its next turn")
	assert_false(hero.creature.has_condition(&"grappled"))


func test_a_plain_hold_stays() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var hydra := got[2] as Combatant
	e.monster_actions.apply_riders(hydra, hero, [{"do": "grapple", "escape_dc": 30}], {}, "Test Grip")
	for i in 4:
		e.end_turn()
	assert_true(e.grapples.has(hero.id))
