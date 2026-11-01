extends TestCase
## A leap as its turn starts (a trait's `turn_start_leap`; MonsterActions.leap_ft and leap, AiBrain._leap): up to its
## Speed to an open square without Opportunity Attacks, here only while it is Bloodied, and the AI takes it.

const BLOCK := {"id": "test_bounder", "name": "Test Bounder", "speed": {"walk": 40},
	"traits": [{"id": "test_bounding", "name": "Test Bounding", "turn_start_leap": {"when": "bloodied"}}],
	"actions": [{"id": "claw", "name": "Claw", "kind": "melee", "attack": {"bonus": 5, "reach": 5}, "damage": [{"dice": "1d4", "type": "slashing"}]}]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "auto"
	var near := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var far := TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 3), 5)
	var b := e.add(TestChars.dummy(100, false, BLOCK.duplicate(true)), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, b)
	return [e, near, far, b]


func test_only_while_bloodied() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var b := got[3] as Combatant
	assert_eq(e.monster_actions.leap_ft(b), 0, "unhurt: no leap")
	b.creature.hp = 40
	assert_eq(e.monster_actions.leap_ft(b), b.speed())


func test_the_leap_provokes_nothing_and_keeps_its_movement() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var near := got[1] as Combatant
	var b := got[3] as Combatant
	b.creature.hp = 40
	var move := b.movement_left
	assert_true(e.monster_actions.leap(b, Vector2i(8, 3)).ok)
	assert_eq(b.cell, Vector2i(8, 3))
	assert_eq(b.movement_left, move, "its own movement is left")
	assert_true(near.reaction_available, "no Opportunity Attack")
	assert_eq(e.monster_actions.leap_ft(b), 0, "once a turn")
	assert_false(e.monster_actions.leap(b, Vector2i(7, 3)).ok)


func test_the_ai_leaps_beside_a_foe_out_of_reach() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "auto"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 3), 5)
	var b := e.add(TestChars.dummy(100, false, BLOCK.duplicate(true)), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, b)
	b.creature.hp = 40
	var move := b.movement_left
	e.ai._leap(b)
	assert_true(e.distance(b, hero) <= 5, "beside the hero it wants")
	assert_eq(b.movement_left, move, "and its movement still to use")


func test_no_leap_beside_the_foe_already() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var b := got[3] as Combatant
	b.creature.hp = 40
	var t := e.ai.boss._best_target(b)
	b.cell = t.cell + Vector2i(1, 0)
	e.ai._leap(b)
	assert_false(b.has_meta("leapt_round"), "it stays and strikes")
