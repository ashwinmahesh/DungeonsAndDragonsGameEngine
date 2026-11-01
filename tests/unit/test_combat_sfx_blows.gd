extends TestCase
## A blow's own sounds (CombatSfx.blow, art/audio.json combat.keys, moment "hit"): a monster action keyed
## "<monster>.<action>" or an action or weapon keyed by its id plays its own sound when it lands, the monster's key over
## the plain one; a blow with neither keeps the sound of what struck and how hard (CombatSfx.hit), as before.

var _saved: Dictionary


func before_each() -> void:
	_saved = CombatSfx.data()
	var mine := _saved.duplicate(true)
	(mine["keys"] as Dictionary).merge({
		"wolf.bite": {"hit": ["thud_heavy"]},
		"claw": {"hit": ["bone_crack"]},
		"longsword": {"hit": ["stone_hit"]},
		"wolf.howl_test": {"cast": ["crow"]},
	}, true)
	CombatSfx._data = mine


func after_each() -> void:
	CombatSfx._data = _saved


func _foe(id: String) -> Combatant:
	return Combatant.new(TestCombat.monster(id), &"enemy", Vector2i.ZERO)


func test_a_monster_action_plays_its_own_hit() -> void:
	assert_eq(CombatSfx.own_hit(_foe("wolf"), "monster:bite"), ["thud_heavy"] as Array[String], "the wolf's bite has its own")


func test_a_plain_action_key_covers_any_monster() -> void:
	assert_eq(CombatSfx.own_hit(_foe("wolf"), "monster:claw"), ["bone_crack"] as Array[String], "any claw")


func test_a_weapon_plays_its_own_hit() -> void:
	assert_eq(CombatSfx.own_hit(null, "weapon:longsword@slash"), ["stone_hit"] as Array[String], "a keyed weapon")


func test_no_hit_key_keeps_the_old_sound() -> void:
	var wolf := _foe("wolf")
	assert_eq(CombatSfx.own_hit(wolf, "monster:tail"), [] as Array[String], "an unkeyed action has none of its own")
	assert_eq(CombatSfx.own_hit(wolf, "monster:howl_test"), [] as Array[String], "a cast key is not a hit")
	assert_eq(CombatSfx.own_hit(wolf, "weapon:dagger"), [] as Array[String], "an unkeyed weapon")
	assert_eq(CombatSfx.own_hit(wolf, ""), [] as Array[String], "no action at all")
	CombatSfx.blow(wolf, "monster:tail", 4, wolf, false)   # falls back to hit(); plays nothing headless, must not fail
	CombatSfx.blow(wolf, "monster:bite", 4, wolf, true)
