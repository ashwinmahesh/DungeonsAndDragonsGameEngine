extends TestCase
## Afflictions with levels (rules/model/afflictions.gd, docs/reference/contracts/afflictions.md): a level held as a
## saved effect, modifiers that grow with it, a threshold that halves Hit Points, healing worn down by it, a recovery
## save after a Long Rest, and cures by spell or by a condition a spell ends.

const ID := "test_rot"
const DEF := {"id": ID, "name": "Test Rot", "summary": "A rot for tests.",
	"modifiers": [{"stat": "save", "ability": "con", "per_level": -1}, {"stat": "attack", "per_level": -1},
		{"stat": "healing_received", "per_level": -1}],
	"thresholds": [{"at": 6, "halve_hp": true, "modifiers": [{"stat": "hp_max_percent", "value": 50}]}],
	"long_rest": {"save": {"ability": "con", "dc": 10}, "success": "mod:con", "failure": "half_mod:con", "min": 1},
	"cures": [{"ends": "poisoned", "remove": 1}, {"spells": ["greater_restoration", "heal"], "remove": "all"}],
	"blocked_by": "test_rot_proof"}


func before_each() -> void:
	Compendium.shared().table("afflictions")[ID] = DEF.duplicate(true)


func after_each() -> void:
	Compendium.shared().table("afflictions").erase(ID)


func _hero() -> Character:
	var ch := TestChars.pregen("hedda_ironvow", 5)
	ch.finish_long_rest()
	return ch


func test_levels_add_up_and_their_modifiers_follow() -> void:
	var ch := _hero()
	var save := ch.save_bonus(&"con").total()
	assert_eq(Afflictions.add(ch, ID, 2), 2)
	assert_eq(Afflictions.level_of(ch, ID), 2)
	assert_eq(ch.save_bonus(&"con").total(), save - 2, "its level off Constitution saves")
	assert_eq(Afflictions.add(ch, ID, 1), 3)
	assert_eq(ch.save_bonus(&"con").total(), save - 3, "the modifiers follow the level")
	assert_eq(ch.effects.filter(func(fx: Effect) -> bool: return fx.source_kind == Afflictions.SOURCE).size(), 1, "one effect holds it")
	assert_eq(Afflictions.of(ch), {ID: 3})
	Afflictions.clear(ch, ID)
	assert_eq(Afflictions.level_of(ch, ID), 0)
	assert_eq(ch.save_bonus(&"con").total(), save, "gone with the last level")


func test_healing_received_loses_the_level() -> void:
	var ch := _hero()
	Afflictions.set_level(ch, ID, 3)
	ch.hp = 10
	assert_eq(ch.heal(5, "test"), 2, "5 healing less 3")
	assert_eq(ch.heal(2, "test"), 0, "never below 0")
	assert_eq(ch.hp, 12)


func test_the_threshold_halves_hit_points_once_and_lifts_below_it() -> void:
	var ch := _hero()
	var full := ch.max_hp()
	Afflictions.set_level(ch, ID, 5)
	assert_eq(ch.max_hp(), full, "no halving below 6")
	Afflictions.add(ch, ID, 1)
	assert_eq(ch.max_hp(), floori(full / 2.0), "level 6 halves the maximum")
	assert_eq(ch.hp, floori(full / 2.0), "and the current Hit Points")
	Afflictions.add(ch, ID, 1)
	assert_eq(ch.max_hp(), floori(full / 2.0), "level 7 doesn't halve again")
	Afflictions.set_level(ch, ID, 5)
	assert_eq(ch.max_hp(), full, "back below 6 the maximum comes back")


func test_a_long_rest_save_takes_levels_off() -> void:
	var ch := _hero()
	Afflictions.set_level(ch, ID, 4)
	var con := ch.ability_mod(&"con")
	var lines := Afflictions.after_long_rest(ch, DiceRoller.new(TestChars.seed_for_d20(20)))
	assert_eq(Afflictions.level_of(ch, ID), maxi(0, 4 - maxi(1, con)), "a good save takes off the Con modifier")
	assert_eq(lines.size(), 1, "a line for the rest screen")
	Afflictions.set_level(ch, ID, 4)
	Afflictions.after_long_rest(ch, DiceRoller.new(TestChars.seed_for_d20(1)))
	assert_eq(Afflictions.level_of(ch, ID), 4 - maxi(1, floori(con / 2.0)), "a failed save takes off half, at least 1")


func test_a_long_rest_restores_hit_points_a_threshold_took() -> void:
	var ch := _hero()
	Afflictions.set_level(ch, ID, 6)
	Afflictions.after_long_rest(ch, DiceRoller.new(TestChars.seed_for_d20(20)))
	assert_true(Afflictions.level_of(ch, ID) < 6)
	assert_eq(ch.hp, ch.max_hp(), "the rest gives back the whole maximum")


func test_cures_by_condition_and_by_spell() -> void:
	var ch := _hero()
	Afflictions.set_level(ch, ID, 4)
	Afflictions.cure_by_spell(ch, "lesser_restoration", ["blinded"])
	assert_eq(Afflictions.level_of(ch, ID), 4, "ending Blindness does nothing for it")
	Afflictions.cure_by_spell(ch, "lesser_restoration", ["poisoned"])
	assert_eq(Afflictions.level_of(ch, ID), 3, "a spell ending Poisoned takes off 1")
	Afflictions.cure_by_spell(ch, "greater_restoration", ["charmed"])
	assert_eq(Afflictions.level_of(ch, ID), 0, "Greater Restoration takes every level")


func test_lesser_restoration_in_a_fight_eases_it_once() -> void:
	var e := TestCombat.open_field(3)
	var cleric := TestCombat.caster_with(e, ["lesser_restoration"], Vector2i(2, 3), 5)
	var ally := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 5)
	TestCombat.punching_bag(e, Vector2i(10, 6))
	TestCombat.start_with(e, cleric)
	Afflictions.set_level(ally.creature, ID, 3)
	var r := e.spells.cast(cleric, "lesser_restoration", 0, [ally], Vector2.INF, Vector2.ZERO, {"choice": "poisoned"})
	assert_true(r.ok, str(r.reason))
	assert_eq(Afflictions.level_of(ally.creature, ID), 2, "one level off, though it wasn't Poisoned")


func test_a_creature_immune_to_its_blocker_isnt_afflicted_and_others_are() -> void:
	var m := TestChars.dummy(30, false, {"condition_immunities": ["poisoned"]})
	assert_eq(Afflictions.add(m, ID, 2), 2, "poison immunity doesn't keep it out")
	var proof := TestChars.dummy(30, false)
	proof.add_effect(Effect.new("Proof", &"effect", "").with_modifier("condition_immunity", {"value": "test_rot_proof"}))
	assert_eq(Afflictions.add(proof, ID, 2), 0, "immunity to its blocker does")


func test_it_saves_and_loads_with_the_creature() -> void:
	var ch := _hero()
	Afflictions.set_level(ch, ID, 6)
	var saved := ch.state_to_dict()
	var back := _hero()
	back.state_from_dict(saved)
	assert_eq(Afflictions.level_of(back, ID), 6)
	assert_eq(back.max_hp(), ch.max_hp(), "its threshold comes back too")
