extends TestCase
## Boss phases and round events (combat/boss_phases.gd, combat/round_events.gd; docs/contracts/combat.md): a phase
## begins once when its trigger is met and changes the stat block, a second life holds a boss up at 0 Hit Points, a
## boss's minions go with it, and events act on their initiative count with no creature behind them.


## A test boss: 100 Hit Points, a claw that always hits for 5, plus `extra` stat-block fields.
static func _boss(extra: Dictionary = {}) -> Dictionary:
	var d := {"id": "test_boss", "name": "Test Boss", "size": "large", "type": "construct", "ac": 15,
		"hp": {"average": 100, "dice": "10d10+45"}, "speed": {"walk": 30},
		"abilities": {"str": 18, "dex": 12, "con": 16, "int": 10, "wis": 10, "cha": 10}, "cr": 4, "proficiency_bonus": 2,
		"actions": [_claw(), _multi()], "ai_profile": "brute", "legendary_resistance": 2}
	d.merge(extra, true)
	return d


static func _claw() -> Dictionary:
	return {"id": "claw", "name": "Claw", "kind": "melee", "attack": {"bonus": 30, "reach": 5},
		"damage": [{"average": 5, "dice": "1d1+4", "type": "slashing"}], "summary": "A claw."}


## Two claws, held back until the `switch` phase.
static func _multi() -> Dictionary:
	return {"id": "multiattack", "name": "Multiattack", "kind": "multiattack", "phase": "switch",
		"multiattack": [{"action": "claw", "count": 2}], "summary": "Two claws."}


static func _switch_phase() -> Dictionary:
	return {"id": "switch", "name": "The Switch", "summary": "Bloodied: its resistance comes back and it strikes twice.",
		"when": {"bloodied": true}, "legendary_resistance": "refill", "resistances": ["fire"], "flag": "boss_switched"}


func _field() -> Encounter:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	return e


static func _has_action(c: Combatant, id: String) -> bool:
	for a: Variant in MonsterActions.data_of(c).get("actions", []):
		if str((a as Dictionary)["id"]) == id:
			return true
	return false


func _hurt(e: Encounter, c: Combatant, amount: int) -> void:
	e.deal_damage(null, c, [{"amount": amount, "type": "force"}], false, "test")


# --- Phases --------------------------------------------------------------------------------------------------------------

func test_a_phase_held_action_waits_for_its_phase_and_bloodied_begins_it_once() -> void:
	var e := _field()
	var boss := e.add(Monster.from_data(_boss({"phases": [_switch_phase()]})), &"enemy", Vector2i(6, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	TestCombat.start_with(e, hero)
	assert_false(_has_action(boss, "multiattack"), "the Multiattack is held back until the switch")
	boss.set_meta("legendary_resistance_used", 2)
	_hurt(e, boss, 40)
	assert_false(e.legendary.phases.is_active(boss, "switch"), "60 of 100 is not Bloodied")
	_hurt(e, boss, 15)
	assert_true(e.legendary.phases.is_active(boss, "switch"), "Bloodied begins the switch")
	assert_true(_has_action(boss, "multiattack"), "the Multiattack comes with it")
	assert_eq(int(boss.get_meta("legendary_resistance_used", 0)), 0, "its Legendary Resistance is refilled")
	assert_true(boss.creature.resistance_source(&"fire") != "", "the phase's resistances replace the block's")
	assert_true(bool(e.legendary.story_flags.get("boss_switched", false)), "the phase tells the story")
	boss.set_meta("legendary_resistance_used", 1)
	_hurt(e, boss, 5)
	assert_eq(int(boss.get_meta("legendary_resistance_used", 0)), 1, "a phase begins only once")
	var shared := Compendium.shared().monster_data("ghost")
	assert_false(shared.has("phases"), "(the shared compendium blocks are never touched)")


func test_a_second_life_holds_it_up_at_zero_once() -> void:
	var e := _field()
	var second := {"id": "risen", "name": "Risen", "summary": "Rises once.", "when": {"at_zero": true}, "hp": 30}
	var boss := e.add(Monster.from_data(_boss({"phases": [second]})), &"enemy", Vector2i(6, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	TestCombat.start_with(e, hero)
	_hurt(e, boss, 150)
	assert_true(boss.is_alive() and not boss.creature.dead, "it rises instead of dying")
	assert_eq(boss.creature.hp, 30, "at the phase's Hit Points")
	_hurt(e, boss, 40)
	assert_true(boss.creature.dead, "the second time it dies")


func test_minions_vanish_when_their_boss_falls() -> void:
	var e := _field()
	var boss := e.add(Monster.from_data(_boss({"minions": {"when_it_falls": "vanish"}})), &"enemy", Vector2i(6, 3))
	var echo := TestCombat.foe(e, "ghost", Vector2i(9, 5))
	echo.set_meta("summoner", boss.id)
	var other := TestCombat.foe(e, "ghost", Vector2i(10, 1))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	TestCombat.start_with(e, hero)
	_hurt(e, boss, 200)
	assert_true(boss.creature.dead, "the boss falls")
	assert_eq(str(e.legendary.departed.get(echo.id, "")), "vanish", "its summon goes with it")
	assert_true(other.is_alive(), "a creature it didn't bring stays")


func test_phases_survive_a_save_and_load() -> void:
	var e := _field()
	var boss := e.add(Monster.from_data(_boss({"phases": [_switch_phase()]})), &"enemy", Vector2i(6, 3))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 5)
	TestCombat.start_with(e, hero)
	_hurt(e, boss, 60)
	var saved := e.legendary.to_dict()
	var e2 := _field()
	var boss2 := e2.add(Monster.from_data(_boss({"phases": [_switch_phase()]})), &"enemy", Vector2i(6, 3))
	boss2.id = boss.id
	e2.legendary.from_dict(saved)
	e2.legendary.after_restore()
	assert_true(e2.legendary.phases.is_active(boss2, "switch"), "the phase is still on")
	assert_true(_has_action(boss2, "multiattack"), "and its block is rebuilt with it")


# --- Round events --------------------------------------------------------------------------------------------------------

static func _fumes(extra: Dictionary = {}) -> Dictionary:
	var d := {"id": "fumes", "name": "Fumes", "summary": "Con save or Exhaustion.", "at": 20,
		"save": {"ability": "con", "dc": 30}, "exhaustion": 1, "skip_if_resists": ["fire"]}
	d.merge(extra, true)
	return d


## A fight with a hero acting on 15 and a foe on 10, the events given, and the first turn begun.
func _event_fight(events: Array) -> Array:
	var e := _field()
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var other := TestCombat.hero(e, "ilse_varga", Vector2i(9, 6), 5)
	var foe := TestCombat.foe(e, "ghost", Vector2i(9, 3))
	e.legendary.set_round_events(events)
	e.lair = false
	e.start()
	for p in [[hero, 15], [other, 12], [foe, 10]]:
		(p[0] as Combatant).initiative = int(p[1])
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.turn_index = 0
	for c in [hero, other, foe]:
		c.creature.exhaustion = 0
	e.legendary.round_events.done.clear()
	e._lair_then_begin()
	return [e, hero, other, foe]


func test_a_round_event_acts_on_its_count_once_a_round() -> void:
	var got := _event_fight([_fumes()])
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[3] as Combatant
	assert_eq(hero.creature.exhaustion, 1, "count 20 comes before the hero on 15: DC 30 fails")
	assert_eq(foe.creature.exhaustion, 0, "it reaches the party only")
	e.end_turn()
	assert_eq(hero.creature.exhaustion, 1, "not again in the same round")
	assert_true(e.events.any(func(ev: Variant) -> bool: return str((ev as Dictionary)["type"]) == "round_event"), "the view hears of it")


func test_a_round_event_keeps_to_its_area_and_spares_the_resistant() -> void:
	var got := _event_fight([_fumes({"area": {"rect": [0, 0, 5, 7]}})])
	var hero := got[1] as Combatant
	var other := got[2] as Combatant
	assert_eq(hero.creature.exhaustion, 1, "inside the area")
	assert_eq(other.creature.exhaustion, 0, "outside it")
	other.creature.add_effect(Effect.new("Fire ward", &"test", "fire_ward").with_modifier("resistance", {"value": "fire"}))
	var e := got[0] as Encounter
	e.legendary.round_events.done.clear()
	other.cell = Vector2i(3, 3)
	e.legendary.round_events.act(_fumes({"area": {"rect": [0, 0, 5, 7]}}), false)
	assert_eq(other.creature.exhaustion, 0, "resistant to fire, it is spared")


func test_a_round_event_at_count_ten_waits_for_the_count() -> void:
	var got := _event_fight([_fumes({"at": 11})])
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	assert_eq(hero.creature.exhaustion, 0, "count 11 comes after the hero on 15")
	e.end_turn()
	assert_eq(hero.creature.exhaustion, 0, "nor before the hero on 12")
	e.end_turn()
	assert_eq(hero.creature.exhaustion, 1, "it acts before the foe on 10")
