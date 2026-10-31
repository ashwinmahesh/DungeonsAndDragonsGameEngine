extends TestCase
## Flasks thrown in a fight (EncounterActions.throw_flask; docs/contracts/combat.md): an item whose effects have
## `damage` is thrown as one of a hero's attacks, its save or attack roll as the data says, its `creature_types` saying
## whom it hurts, Alchemist's Fire setting the target alight, and the flask used up either way.

var content := FixtureContent.new()


func after_each() -> void:
	content.restore()


func _fight(foe_type: String, item_id: String, qty: int = 2) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	(hero.creature as Character).add_item(item_id, qty)
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3), 80, foe_type)
	TestCombat.start_with(e, hero)
	return [e, hero, foe]


func _count(c: Combatant, item_id: String) -> int:
	return (c.creature as Character).entry_of(item_id).get("qty", 0) as int if not (c.creature as Character).entry_of(item_id).is_empty() else 0


func test_the_hotbar_offers_a_flask_as_one_of_your_attacks() -> void:
	var got := _fight("undead", "holy_water")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var act := ActionCatalog.new(e).find(hero, "flask:holy_water")
	assert_false(act.is_empty(), "Throw Holy Water is on the hotbar")
	assert_eq(str(act["label"]), "Throw Holy Water")
	assert_eq(int(act["range"]), 20)
	assert_true(bool(act["legal"]))


func test_holy_water_burns_the_undead_on_a_failed_save() -> void:
	var got := _fight("undead", "holy_water")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var before := foe.creature.hp
	TestCombat.next_d20(e, 2)
	assert_true(ActionCatalog.new(e).perform(hero, ActionCatalog.new(e).find(hero, "flask:holy_water"), [foe]).ok)
	assert_true(foe.creature.hp < before, "radiant damage")
	assert_eq(_count(hero, "holy_water"), 1, "one flask used up")
	assert_eq(hero.attacks_left, e.attacks_per_action(hero) - 1, "it took one of the hero's attacks")


func test_holy_water_leaves_a_living_creature_unharmed() -> void:
	var got := _fight("humanoid", "holy_water")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var before := foe.creature.hp
	TestCombat.next_d20(e, 2)
	assert_true(e.actions.throw_flask(hero, "holy_water", foe).ok)
	assert_eq(foe.creature.hp, before, "creature_types: only Fiends and Undead are hurt")
	assert_eq(_count(hero, "holy_water"), 1, "the flask is spent anyway")
	assert_true(e.log.entries.any(func(en: Dictionary) -> bool: return str(en["text"]).contains("unharmed")))


func test_a_good_save_avoids_it() -> void:
	var got := _fight("undead", "holy_water")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var before := foe.creature.hp
	TestCombat.next_d20(e, 20)
	e.actions.throw_flask(hero, "holy_water", foe)
	assert_eq(foe.creature.hp, before)


func test_alchemists_fire_sets_the_target_burning() -> void:
	var got := _fight("humanoid", "alchemists_fire")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	TestCombat.next_d20(e, 2)
	e.actions.throw_flask(hero, "alchemists_fire", foe)
	assert_true(foe.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "burning"), "it catches fire")


func test_out_of_range_and_the_last_flask() -> void:
	var got := _fight("undead", "acid", 1)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	foe.cell = Vector2i(11, 7)
	assert_false(e.actions.throw_flask(hero, "acid", foe).ok, "beyond 20 ft")
	assert_eq(_count(hero, "acid"), 1, "nothing spent on a throw that can't be made")
	foe.cell = Vector2i(5, 3)
	assert_true(e.actions.throw_flask(hero, "acid", foe).ok)
	assert_false(e.actions.throw_flask(hero, "acid", foe).ok, "none left")


func test_an_attack_roll_flask_hits_on_the_targets_armor_class() -> void:
	content.add("items", {"id": "test_firepot", "name": "Test Firepot", "category": "consumable", "stackable": true,
		"summary": "A pot of fire.", "effects": [{"effect": "damage", "params": {"dice": "1d1+9", "damage_type": "fire", "attack": true, "range": 30}}]})
	var got := _fight("humanoid", "test_firepot")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var before := foe.creature.hp
	TestCombat.next_d20(e, 19)
	e.actions.throw_flask(hero, "test_firepot", foe)
	assert_eq(foe.creature.hp, before - 10, "a hit against AC 1: 10 fire")
