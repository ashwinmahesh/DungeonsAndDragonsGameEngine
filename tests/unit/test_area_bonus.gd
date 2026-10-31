extends TestCase
## A creature's `area_bonus_ft` (MonsterActions.area_size, area_cells; docs/contracts/monsters.md): its emanations,
## cones and lines reach that many feet further, and so does how far it can aim them, its legendary options' areas
## included; 0, missing or negative leaves them as the stat block says.


static func _block(area: Dictionary, legendary: bool = false) -> Dictionary:
	var d := {"id": "test_breather", "name": "Test Breather", "size": "medium", "type": "fiend", "ac": 12,
		"hp": {"average": 100, "dice": "10d10+45"}, "speed": {"walk": 30},
		"abilities": {"str": 14, "dex": 12, "con": 14, "int": 10, "wis": 10, "cha": 10}, "cr": 4, "proficiency_bonus": 2,
		"actions": [{"id": "burst", "name": "Burst", "kind": "save", "save": {"ability": "dex", "dc": 30},
			"area": area, "targets": {"range": int(area["size"])},
			"damage": [{"average": 10, "dice": "1d1+9", "type": "fire"}], "summary": "An area of fire."}],
		"ai_profile": "brute"}
	if legendary:
		d["legendary_actions"] = {"per_round": 3, "options": [{"id": "flare", "name": "Flare", "cost": 1, "action": "burst"}]}
	return d


func _fight(area: Dictionary, legendary: bool = false) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var boss := e.add(Monster.from_data(_block(area, legendary)), &"enemy", Vector2i(1, 3))
	var near := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 3)   # 15 ft away
	var far := TestCombat.hero(e, "thistle", Vector2i(6, 3), 3)          # 25 ft away
	TestCombat.start_with(e, boss)
	return [e, boss, near, far]


func test_a_cone_reaches_ten_feet_further_with_ten_more() -> void:
	var got := _fight({"shape": "cone", "size": 15})
	var e := got[0] as Encounter
	var boss := got[1] as Combatant
	var near := got[2] as Combatant
	var far := got[3] as Combatant
	var caught := e.monster_actions.save_victims(boss, (boss.creature as Monster).action("burst"), near)
	assert_true(near in caught, "15 ft: in its 15-ft cone")
	assert_false(far in caught, "25 ft: beyond it")
	assert_false(far in e.monster_actions.save_targets(boss, (boss.creature as Monster).action("burst")), "and not one it can aim at")
	boss.set_meta(MonsterActions.AREA_BONUS, 10)
	caught = e.monster_actions.save_victims(boss, (boss.creature as Monster).action("burst"), near)
	assert_true(far in caught, "a 25-ft cone now: it reaches")
	assert_true(far in e.monster_actions.save_targets(boss, (boss.creature as Monster).action("burst")), "and can be aimed that far")
	assert_eq(MonsterActions.area_size(boss, {"shape": "cone", "size": 15}), 25)
	assert_true(Vector2i(6, 3) in e.monster_actions.area_cells(boss, (boss.creature as Monster).action("burst"), near), "the preview's squares grow too")


func test_an_emanation_grows_and_nothing_below_zero_shrinks_it() -> void:
	var got := _fight({"shape": "emanation", "size": 15})
	var e := got[0] as Encounter
	var boss := got[1] as Combatant
	var near := got[2] as Combatant
	var far := got[3] as Combatant
	var act := (boss.creature as Monster).action("burst")
	assert_false(far in e.monster_actions.save_victims(boss, act, near), "25 ft: outside a 15-ft emanation")
	boss.set_meta(MonsterActions.AREA_BONUS, 0)
	assert_false(far in e.monster_actions.save_victims(boss, act, near), "0: as the block says")
	boss.set_meta(MonsterActions.AREA_BONUS, -10)
	assert_true(near in e.monster_actions.save_victims(boss, act, near), "negative: never smaller than the block's")
	assert_eq(MonsterActions.area_size(boss, act["area"] as Dictionary), 15)
	boss.set_meta(MonsterActions.AREA_BONUS, 10)
	assert_true(far in e.monster_actions.save_victims(boss, act, near), "+10: a 25-ft emanation catches them")
	assert_eq(MonsterActions.area_size(boss, {"shape": "space", "size": 5}), 5, "a shape it doesn't grow stays")


func test_a_legendary_options_area_grows_with_it() -> void:
	var got := _fight({"shape": "emanation", "size": 15}, true)
	var e := got[0] as Encounter
	var boss := got[1] as Combatant
	var near := got[2] as Combatant
	var far := got[3] as Combatant
	var opt := {"id": "flare", "name": "Flare", "cost": 1, "action": "burst"}
	var hp := far.creature.hp
	e.legendary._strike(boss, opt, near)
	assert_eq(far.creature.hp, hp, "the legendary Flare doesn't reach 25 ft")
	assert_true(near.creature.hp < near.creature.max_hp(), "(it burns the near hero)")
	boss.set_meta(MonsterActions.AREA_BONUS, 10)
	e.legendary._strike(boss, opt, near)
	assert_true(far.creature.hp < hp, "with 10 more feet it does")
