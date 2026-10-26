extends TestCase
## The spells an item gives, on the combat hotbar's Spells tab (Ashwin, 2026-10-24: "showing spells from equipped / attuned
## magic items in the players spell list ... in combat"). They used to sit on the Items tab, folded under their item, and a
## hero with no spells of their own had no Spells tab at all. Now a spell of an item the hero works (worn or held, attuned
## where it asks) is a slot of its own on the Spells tab, by the spell's name, with the item and what it has left on its
## second line; the same spells the character sheet lists (story/item_spells.gd).

const STAFF := "staff_of_healing__quarterstaff"
const CIRCLET := "circlet_of_blasting"


func _labels(cat: ActionCatalog, c: Combatant, tab: String) -> Array[String]:
	var out: Array[String] = []
	for s in cat.slots(c, tab):
		out.append(str(s["label"]))
	return out


func _slot(cat: ActionCatalog, c: Combatant, tab: String, id: String) -> Dictionary:
	for s in cat.slots(c, tab):
		if str(s["id"]) == id:
			return s
	return {}


func _fighter() -> Array:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	return [e, ilse, ActionCatalog.new(e)]


func test_a_hero_with_no_spells_of_their_own_gets_the_tab_while_an_item_gives_one() -> void:
	var f := _fighter()
	var ilse := f[1] as Combatant
	var cat := f[2] as ActionCatalog
	var ch := ilse.creature as Character
	assert_true(ActionCatalog.SPELLS not in cat.tabs_for(ilse), "no Spells tab for a Fighter")
	ch.add_item(CIRCLET)
	assert_true(ActionCatalog.SPELLS not in cat.tabs_for(ilse), "in the pack, it gives nothing")
	assert_true(ch.equip(CIRCLET, "head"))
	assert_true(ActionCatalog.SPELLS in cat.tabs_for(ilse), "worn, it gives her the tab")
	var slot := _slot(cat, ilse, ActionCatalog.SPELLS, "item:%s:scorching_ray" % CIRCLET)
	assert_false(slot.is_empty(), "Scorching Ray is on the Spells tab: %s" % [_labels(cat, ilse, ActionCatalog.SPELLS)])
	assert_eq(str(slot["label"]), "Scorching Ray", "by the spell's name")
	assert_eq(str(slot["kind"]), "item_spell")
	assert_eq(str(slot["sub"]), "1/1 · Circlet of Blasting", "the item it comes from, and its daily use")
	assert_true(str(slot["help"]).begins_with("From your Circlet of Blasting: 1 of 1 use left"), str(slot["help"]))
	assert_true(bool(slot["legal"]))
	assert_true(_slot(cat, ilse, ActionCatalog.ITEMS, "item:%s:scorching_ray" % CIRCLET).is_empty(), "and no longer on the Items tab")
	# Taken off, the spell goes back to the Items tab, greyed with its reason, and the tab goes.
	ch.unequip_item(CIRCLET)
	assert_true(ActionCatalog.SPELLS not in cat.tabs_for(ilse))
	var back := _slot(cat, ilse, ActionCatalog.ITEMS, "item:%s:scorching_ray" % CIRCLET)
	assert_false(back.is_empty() or bool(back["legal"]), "greyed on the Items tab")


func test_each_spell_of_a_staff_is_a_slot_of_its_own_beside_the_heros() -> void:
	var e := TestCombat.open_field()
	var liriel := TestCombat.hero(e, "liriel_dawnsong", Vector2i(2, 2), 9)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, liriel)
	var cat := ActionCatalog.new(e)
	var ch := liriel.creature as Character
	ch.add_item(STAFF)
	ch.equip(STAFF, "main_hand")
	assert_true(_slot(cat, liriel, ActionCatalog.SPELLS, "item:%s:cure_wounds" % STAFF).is_empty(), "not attuned: not listed")
	assert_true(ch.attune(STAFF))
	var ids: Array[String] = []
	for s in cat.slots(liriel, ActionCatalog.SPELLS):
		if str(s["kind"]) == "item_spell":
			ids.append(str(s["id"]))
			assert_false(bool(s.get("group", false)), "never folded into one slot for the staff")
			assert_true(str(s["sub"]).ends_with(" · Staff of Healing"), str(s["sub"]))
	assert_eq(ids, ["item:%s:cure_wounds" % STAFF, "item:%s:lesser_restoration" % STAFF, "item:%s:mass_cure_wounds" % STAFF] as Array[String])
	var mass := _slot(cat, liriel, ActionCatalog.SPELLS, "item:%s:mass_cure_wounds" % STAFF)
	assert_eq(int(mass["slot"]), 5, "under its own level, as the hero's spells are")
	assert_eq(str(mass["sub"]), "%d/10 · Staff of Healing" % ch.charges_left(STAFF))
	assert_true(_labels(cat, liriel, ActionCatalog.ITEMS).filter(func(l: String) -> bool: return l.begins_with("Staff of Healing")).is_empty(),
		"the Items tab has none of them")
	# Her own spells are still there.
	assert_true(cat.slots(liriel, ActionCatalog.SPELLS).any(func(s: Dictionary) -> bool: return str(s["kind"]) == "spell"), "her own too")


func test_an_item_spell_is_still_cast_from_the_spells_tab() -> void:
	var f := _fighter()
	var e := f[0] as Encounter
	var ilse := f[1] as Combatant
	var cat := f[2] as ActionCatalog
	var ch := ilse.creature as Character
	ch.add_item("wand_of_magic_missiles")
	var id := "item:wand_of_magic_missiles:magic_missile"
	assert_true(_slot(cat, ilse, ActionCatalog.SPELLS, id).is_empty(), "a wand in the pack gives nothing")
	ch.unequip_item("greatsword")   # a wand is held: a hand has to be free for it
	assert_true(ch.equip("wand_of_magic_missiles", "main_hand"))
	var slot := _slot(cat, ilse, ActionCatalog.SPELLS, id)
	assert_false(slot.is_empty(), "the wand's spell: %s" % [cat.tabs_for(ilse)])
	assert_eq(str(slot.get("sub", "")), "7/7 · Wand of Magic Missiles")
	var zombie := e.order.filter(func(c: Combatant) -> bool: return c.side == &"enemy")[0] as Combatant
	var res := cat.perform(ilse, slot, [zombie, zombie, zombie])
	assert_true(res.ok, "the wand casts")
	assert_eq(ch.charges_left("wand_of_magic_missiles"), 6, "a charge spent")
	assert_eq(str(_slot(cat, ilse, ActionCatalog.SPELLS, id)["sub"]), "6/7 · Wand of Magic Missiles", "and the slot shows it")


func test_a_spell_with_nothing_to_do_in_a_fight_stays_on_the_items_tab() -> void:
	var f := _fighter()
	var ilse := f[1] as Combatant
	var cat := f[2] as ActionCatalog
	(ilse.creature as Character).add_item("wand_of_magic_detection")
	assert_true(ActionCatalog.SPELLS not in cat.tabs_for(ilse), "Detect Magic is not a spell for a fight")
	assert_false(_slot(cat, ilse, ActionCatalog.ITEMS, "item:wand_of_magic_detection:detect_magic").is_empty(), "it stays with the items")
