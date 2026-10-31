extends TestCase
## Food on the battlefield and things that break open (combat/object_fuel.gd; docs/reference/contracts/combat.md "Fuel
## and what breaks open"): a creature whose block `devours` eats food in reach as its turn starts (healing, Advantage
## until its next turn), what an object held comes out when it's eaten or broken (once), it leaves with its boss, and
## the AI walks to food it can reach before striking a foe.


## A test boss with 100 Hit Points that eats "fuel" within 10 ft: 20 Hit Points and Advantage.
static func _eater(extra: Dictionary = {}) -> Dictionary:
	var d := {"id": "test_engine", "name": "Test Engine", "size": "large", "type": "construct", "ac": 15,
		"hp": {"average": 100, "dice": "10d10+45"}, "speed": {"walk": 30},
		"abilities": {"str": 18, "dex": 12, "con": 16, "int": 10, "wis": 10, "cha": 10}, "cr": 4, "proficiency_bonus": 2,
		"actions": [{"id": "slam", "name": "Slam", "kind": "melee", "attack": {"bonus": 6, "reach": 5},
			"damage": [{"average": 5, "dice": "1d1+4", "type": "bludgeoning"}], "summary": "A slam."}],
		"ai_profile": "brute", "devours": {"fuel": ["fuel"], "within": 10, "heal": 20, "advantage": true, "name": "Fuel"},
		"minions": {"when_it_falls": "vanish"}}
	d.merge(extra, true)
	return d


## A canister of fuel at `cell` holding a ghost that serves the test engine.
static func _can(cell: Vector2i, id: String = "can") -> Dictionary:
	return {"id": id, "kind": "vessel", "cell": [cell.x, cell.y], "name": "a canister", "model": "jars", "fuel": "fuel",
		"ac": 11, "hp": 1, "immune": ["lightning"],
		"releases": {"monster": "ghost", "name": "The Echo", "hp": "half", "minion_of": "test_engine"}}


func _field() -> Encounter:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	return e


static func _echoes(e: Encounter) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in e.combatants:
		if c.name() == "The Echo":
			out.append(c)
	return out


func test_an_entry_puts_an_object_down_with_its_own_numbers() -> void:
	var e := _field()
	var o := e.objects.put(_can(Vector2i(8, 3)))
	assert_eq(o.id, "can")
	assert_eq([o.ac, o.hp, o.hp_max], [11, 1, 1], "the entry's Armor Class and Hit Points beat the kind's")
	assert_true("lightning" in o.immune and "poison" in o.immune and "psychic" in o.immune, "its immunities, and every object's")
	assert_eq(o.blocks, 0, "a jar takes no square from anyone")
	var back := BattleObject.from_dict(o.to_dict())
	assert_eq([back.model, back.fuel, str(back.releases.get("monster", ""))], ["jars", "fuel", "ghost"], "a round's save keeps it")


func test_it_eats_food_in_reach_as_its_turn_starts() -> void:
	var e := _field()
	var boss := e.add(Monster.from_data(_eater()), &"enemy", Vector2i(5, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(0, 0), 5)
	var near := e.objects.put(_can(Vector2i(8, 3), "near"))
	var far := e.objects.put(_can(Vector2i(11, 7), "far"))
	boss.creature.hp = 50
	TestCombat.start_with(e, boss)
	assert_true(near.destroyed, "the canister 10 ft away is eaten")
	assert_false(far.destroyed, "one farther off is not, and only one a turn")
	assert_eq(boss.creature.hp, 70, "it regains 20 Hit Points")
	assert_true(_has_fx(boss, "devour"), "Advantage on its attacks")
	assert_true(e.events.any(func(ev: Variant) -> bool: return str((ev as Dictionary)["type"]) == "object_eaten"), "the scene is told")
	var echoes := _echoes(e)
	assert_eq(echoes.size(), 1, "what the canister held comes out")
	var echo := echoes[0]
	assert_eq(echo.cell, Vector2i(8, 3), "on its square")
	assert_eq(echo.creature.hp, ceili(echo.creature.max_hp() / 2.0), "at half its Hit Points")
	assert_eq(e.order.find(echo), e.order.find(boss) + 1, "acting right after the boss it serves")
	assert_true(hero.is_alive())
	# Its Advantage lasts until its next turn starts.
	e.end_turn()
	while e.current() != boss and e.state == Encounter.State.ACTIVE:
		e.end_turn()
	assert_false(_has_fx(boss, "devour"), "the Advantage ends as its next turn starts")


func test_breaking_it_lets_out_what_it_held_once_and_the_boss_takes_it_along() -> void:
	var e := _field()
	var boss := e.add(Monster.from_data(_eater()), &"enemy", Vector2i(1, 1))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(9, 6), 5)
	var can := e.objects.put(_can(Vector2i(10, 6)))
	TestCombat.start_with(e, hero)
	e.objects.damage(can, [{"amount": 3, "type": "lightning"}], hero, "a spark")
	assert_false(can.destroyed, "lightning doesn't harm it")
	e.objects.damage(can, [{"amount": 3, "type": "bludgeoning"}], hero, "a blow")
	assert_true(can.destroyed, "a blow breaks it")
	assert_eq(_echoes(e).size(), 1, "and lets the echo out")
	e.objects.smash(can, "again")
	assert_eq(_echoes(e).size(), 1, "only once")
	e.deal_damage(null, boss, [{"amount": 200, "type": "force"}], false, "test")
	assert_eq(str(e.legendary.departed.get(_echoes(e)[0].id, "")), "vanish", "the echo goes with its boss")


func test_the_ai_walks_to_food_it_can_reach_before_a_foe_it_could_strike() -> void:
	var e := _field()
	var boss := e.add(Monster.from_data(_eater()), &"enemy", Vector2i(0, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 5), 5)
	var can := e.objects.put(_can(Vector2i(8, 3)))
	TestCombat.start_with(e, boss)
	assert_false(can.destroyed, "out of reach as its turn starts")
	e.ai.play_turn(boss)
	assert_eq(str(e.ai.last_plan.get("kind", "")), "fuel", "its plan is the food")
	assert_true(e.objects.distance_ft(boss, can) <= 10, "it ends its move in reach of the canister")
	assert_true(hero.is_alive())


func test_food_out_of_its_reach_this_turn_leaves_its_plan_alone() -> void:
	var e := _field()
	var boss := e.add(Monster.from_data(_eater({"speed": {"walk": 10}})), &"enemy", Vector2i(0, 3))
	TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 4), 5)
	e.objects.put(_can(Vector2i(11, 7)))
	TestCombat.start_with(e, boss)
	e.ai.play_turn(boss)
	assert_ne(str(e.ai.last_plan.get("kind", "")), "fuel", "too far: it fights as it would")


static func _has_fx(c: Combatant, source_id: String) -> bool:
	for fx: Effect in c.creature.effects:
		if fx.source_id == source_id:
			return true
	return false
