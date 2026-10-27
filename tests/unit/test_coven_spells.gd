extends TestCase
## A coven's shared spells (MonsterActions.coven_casting; the night hag's `coven` state, the 2014 Monster Manual's hag
## covens): while two sisters with a coven of their own stand within 30 feet, a hag casts the coven's spells at its DC
## and attack, from slots the whole coven shares; apart, or with no coven, she has only her own block.


func _hag(e: Encounter, cell: Vector2i, coven: bool = true) -> Combatant:
	var data := Compendium.shared().monster_data("night_hag")
	if coven:
		data = LocationFights.with_states(data, ["coven"])
	return e.add(Monster.from_data(data), &"enemy", cell)


func _has(e: Encounter, c: Combatant, id: String) -> bool:
	return e.monster_actions.spells_now(c).any(func(s: Dictionary) -> bool: return str(s["id"]) == id)


func _left(e: Encounter, c: Combatant, id: String) -> int:
	for s in e.monster_actions.spells_now(c):
		if str(s["id"]) == id:
			return int(s["left"])
	return 0


func test_three_sisters_together_share_the_covens_spells_and_slots() -> void:
	var e := TestCombat.open_field(3)
	var a := _hag(e, Vector2i(2, 2))
	var b := _hag(e, Vector2i(4, 2))
	var c := _hag(e, Vector2i(6, 2))
	var h := TestCombat.punching_bag(e, Vector2i(10, 2), 200)
	h.side = &"party"
	TestCombat.start_with(e, a)
	for id: String in ["ray_of_sickness", "hold_person", "lightning_bolt", "counterspell", "polymorph", "eyebite"]:
		assert_true(_has(e, a, id), "the coven lends %s" % id)
	assert_true(_has(e, a, "magic_missile"), "and she keeps her own block")
	assert_eq(_left(e, b, "lightning_bolt"), 3, "three 3rd-level slots for the coven")
	var r := e.monster_actions.cast(a, "lightning_bolt", [], Vector2(h.cell) + Vector2(0.5, 0.5))
	assert_true(r.ok, r.reason)
	assert_eq(_left(e, b, "lightning_bolt"), 2, "one sister's Lightning Bolt spends the slot for all three")
	assert_eq(_left(e, c, "counterspell"), 2, "Counterspell shares the 3rd-level slots")
	assert_eq(e.monster_actions.reaction_spell_source(c, "counterspell"), "spellcasting", "a coven Counterspell is a Reaction too")
	assert_eq(e.monster_actions.spend_reaction_spell(c, "counterspell"), 3, "cast from a 3rd-level slot")
	assert_eq(_left(e, a, "lightning_bolt"), 1, "and spends one")


func test_apart_or_without_a_coven_she_has_only_her_own_block() -> void:
	var e := TestCombat.open_field(3)
	var a := _hag(e, Vector2i(2, 2))
	var b := _hag(e, Vector2i(4, 2))
	var far := _hag(e, Vector2i(14, 2))
	assert_false(_has(e, a, "lightning_bolt"), "the third sister is 60 ft. off")
	assert_false(_has(e, far, "lightning_bolt"), "and so is she")
	far.cell = Vector2i(6, 2)
	assert_true(_has(e, a, "lightning_bolt"), "back within 30 ft., the coven is whole")
	var e2 := TestCombat.open_field(3)
	var plain := _hag(e2, Vector2i(2, 2), false)
	_hag(e2, Vector2i(4, 2))
	_hag(e2, Vector2i(6, 2))
	assert_false(_has(e2, plain, "lightning_bolt"), "a hag with no coven of her own casts none of it")
	assert_true(_has(e2, plain, "phantasmal_killer"), "her own Phantasmal Killer stays")
	b.creature.hp = 0
	b.creature.dead = true
	assert_false(_has(e, a, "lightning_bolt"), "a sister down breaks the coven")
