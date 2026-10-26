extends TestCase
## A stat-block caster the player runs (a story ally such as Ezmerelda; the core tests use the mage's block) has a Spells tab: the
## spells its Spellcasting block lists, at will or so many a day, cast with the block's DC and attack bonus and no slot
## (ActionCatalog.has_block_spells and _stat_block_spells; MonsterActions.block_spells, block_level and cast). Before, only a hero's
## own spellcasting reached the hotbar: the block's spells were the AI's alone.


func _fight() -> Dictionary:
	var e := TestCombat.open_field(4)
	var mage := e.add(TestCombat.monster("mage"), &"guest", Vector2i(3, 3))
	mage.controller = &"player"
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var foe := TestCombat.foe(e, "ghoul", Vector2i(8, 3))
	TestCombat.start_with(e, mage)
	return {"e": e, "mage": mage, "hero": hero, "foe": foe, "cat": ActionCatalog.new(e)}


func _spell(cat: ActionCatalog, c: Combatant, id: String) -> Dictionary:
	for a in cat.actions_for(c):
		if str(a["id"]) == "spell:" + id:
			return a
	return {}


func test_the_tab_appears_for_a_block_caster_and_not_for_a_monster_without_spells() -> void:
	var f := _fight()
	var cat := f["cat"] as ActionCatalog
	assert_true(ActionCatalog.SPELLS in cat.tabs_for(f["mage"] as Combatant), "the mage has a Spells tab")
	assert_false(ActionCatalog.SPELLS in cat.tabs_for(f["foe"] as Combatant), "a ghoul, with no Spellcasting block, has none")
	assert_true(cat.has_block_spells(f["mage"] as Combatant))
	assert_false(cat.has_block_spells(f["hero"] as Combatant), "a hero casts from their own sheet")


func test_it_lists_every_spell_of_the_block_with_how_many_are_left() -> void:
	var f := _fight()
	var cat := f["cat"] as ActionCatalog
	var mage := f["mage"] as Combatant
	var ids: Array[String] = []
	for a in cat.actions_for(mage):
		if str(a["tab"]) == ActionCatalog.SPELLS:
			ids.append(str(a["id"]).substr(6))
	for id: String in ["mage_hand", "light", "fireball", "invisibility", "cone_of_cold", "fly"]:
		assert_true(id in ids, "%s is on the Spells tab: %s" % [id, ids])
	var fb := _spell(cat, mage, "fireball")
	assert_true(str(fb["sub"]).contains("2 left today"), str(fb["sub"]))
	assert_true(bool(fb["legal"]), str(fb["reason"]))
	assert_eq(str(fb["cost"]), "action")
	assert_eq(int(fb["slot"]), 3, "at the level the spell is")
	assert_eq(cat.level_choices(mage, fb), [] as Array[int], "a stat block's spell has the one level, no slot to pick")
	assert_true(str(_spell(cat, mage, "mage_hand")["sub"]).contains("at will"))


func test_casting_it_spends_a_use_and_the_block_numbers_apply() -> void:
	var f := _fight()
	var e := f["e"] as Encounter
	var cat := f["cat"] as ActionCatalog
	var mage := f["mage"] as Combatant
	var foe := f["foe"] as Combatant
	var fb := _spell(cat, mage, "fireball")
	var preview := cat.cast_preview(mage, fb, 3)
	assert_eq((preview["save_dc"] as Breakdown).total(), 14, "the block's DC")
	assert_eq(str(preview["damage_dice"]), "8d6")
	var hp := foe.creature.hp
	var r := cat.perform(mage, fb, [], Vector2(foe.cell) + Vector2(0.5, 0.5))
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.hp < hp, "it hurt the ghoul")
	assert_false(mage.action_available, "an action was spent")
	assert_eq(int(mage.get_meta("cast_fireball", 0)), 1, "one of two uses is gone")
	assert_eq(e.monster_actions.block_spells(mage).filter(func(s: Dictionary) -> bool: return str(s["id"]) == "fireball")[0]["left"], 1)
	assert_true(str(_spell(cat, mage, "fireball")["reason"]).contains("Action already used"), "and the rest of the turn it says why: %s" % _spell(cat, mage, "fireball")["reason"])


func test_a_spell_with_no_uses_left_is_greyed_with_why_and_the_next_turn_does_not_bring_it_back() -> void:
	var f := _fight()
	var cat := f["cat"] as ActionCatalog
	var mage := f["mage"] as Combatant
	mage.set_meta("cast_cone_of_cold", 1)
	var cone := _spell(cat, mage, "cone_of_cold")
	assert_false(bool(cone["legal"]))
	assert_eq(str(cone["reason"]), "None left today")
	assert_true(str(cone["sub"]).contains("0 left today"))


func test_a_cantrip_of_no_use_in_a_fight_says_so_and_the_detail_says_where_the_spell_is_known_from() -> void:
	var f := _fight()
	var cat := f["cat"] as ActionCatalog
	var mage := f["mage"] as Combatant
	var light := _spell(cat, mage, "detect_magic")
	assert_false(bool(light["legal"]), "Detect Magic does nothing in a fight")
	assert_true(str(light["reason"]).begins_with("No effect in a fight"), str(light["reason"]))
	var detail := cat.details(mage, _spell(cat, mage, "fireball"))
	assert_true((detail["lines"] as Array).any(func(l: Variant) -> bool: return str(l).contains("a day, 2 left today")), "the detail says where the spell is known from: %s" % [detail["lines"]])


func test_the_ai_and_the_player_share_one_count_of_uses() -> void:
	var f := _fight()
	var e := f["e"] as Encounter
	var mage := f["mage"] as Combatant
	var foe := f["foe"] as Combatant
	var r := e.monster_actions.cast(mage, "fireball", [], Vector2(foe.cell) + Vector2(0.5, 0.5))
	assert_true(r.ok, r.reason)
	var fb := _spell(f["cat"] as ActionCatalog, mage, "fireball")
	assert_true(str(fb["sub"]).contains("1 left today"), "a use the AI path spent shows on the tab: %s" % fb["sub"])
