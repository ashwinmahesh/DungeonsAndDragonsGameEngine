extends TestCase
## Fighting under water (Underwater, Encounter.underwater): weapons and fire by the 2024 rules.


func _fight(under: bool) -> Array:
	var e := TestCombat.open_field(3)
	e.underwater = under
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, hero)
	return [e, hero, foe]


func _option(e: Encounter, c: Combatant, melee: bool) -> Dictionary:
	for o in e.attack_options(c):
		if bool(o["melee"]) == melee and str(o["kind"]) != "unarmed":
			return o
	return {}


func test_a_heavy_blade_struggles_and_fire_is_muffled() -> void:
	var got := _fight(true)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var opt := _option(e, hero, true)
	var p := opt["profile"] as WeaponProfile
	var why := Underwater.attack_disadvantage(e, hero, p, true, str(opt["kind"]))
	if Underwater.MELEE_OK.has(p.item_id.get_slice("@", 0)):
		assert_eq(why, "", "a stabbing weapon works")
	else:
		assert_eq(why, "under water", "%s has Disadvantage" % p.item_id)
	var hp := hero.creature.hp
	e.deal_damage(null, hero, [{"amount": 10, "type": "fire"}], false, "Test", [])
	assert_eq(hero.creature.hp, hp - 5, "Resistance to Fire")
	EncounterSetup.clear_fight_effects(hero.creature)
	assert_false(hero.creature.effects.any(func(fx: Effect) -> bool: return fx.stack_key == Underwater.STACK), "gone with the fight")


func test_on_dry_land_nothing_changes() -> void:
	var got := _fight(false)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var opt := _option(e, hero, true)
	assert_eq(Underwater.attack_disadvantage(e, hero, opt["profile"] as WeaponProfile, true, str(opt["kind"])), "")
	assert_false(hero.creature.effects.any(func(fx: Effect) -> bool: return fx.stack_key == Underwater.STACK))
