extends TestCase
## Illusory decoy bodies (a trait's `decoy_image`; DecoyImages): an image put down beside its maker as the fight starts,
## that nothing harms, that fools whoever aims at it while a flag holds (an Int save), that a Study unmasks, and that the
## maker sends about the field.

const BLOCK := {"id": "test_trickster", "name": "Test Trickster", "speed": {"walk": 30},
	"traits": [{"id": "test_image", "name": "Test Image", "decoy_image": {"name": "Test Jester", "move_ft": 60,
		"save": {"ability": "int", "dc": 40}, "while_flag": "test_fooling", "study": {"skill": "investigation", "dc": 5},
		"gone_flag": "test_unmasked", "through": ["zap"]}}],
	"actions": [{"id": "claw", "name": "Claw", "kind": "melee", "attack": {"bonus": 5, "reach": 5}, "damage": [{"dice": "1d4", "type": "slashing"}]},
		{"id": "zap", "name": "Zap", "kind": "melee", "attack": {"bonus": 30, "reach": 5}, "damage": [{"dice": "1d4", "type": "lightning"}]}]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var owner := e.add(TestChars.dummy(100, false, BLOCK.duplicate(true)), &"enemy", Vector2i(12, 7))
	TestCombat.start_with(e, hero)
	var img := e.images.image_of(owner)
	return [e, hero, owner, img]


func test_an_image_beside_its_maker_that_doesnt_count() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var owner := got[2] as Combatant
	var img := got[3] as Combatant
	assert_true(img != null, "put down as the fight starts")
	assert_eq(img.name(), "Test Jester")
	assert_true(e.distance(img, owner) <= 5)
	assert_false(img in e.order, "no turn of its own")
	e.deal_damage(got[1] as Combatant, img, [{"amount": 50, "type": "fire"}], false, "test")
	assert_true(img.is_alive(), "nothing harms it")
	owner.creature.hp = 0
	owner.creature.dead = true
	e.turns._check_over()
	assert_eq(e.state, Encounter.State.OVER, "the image doesn't keep the fight going")


func test_while_the_flag_holds_a_failed_save_fools_the_attacker() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var img := got[3] as Combatant
	e.legendary.story_flags["test_fooling"] = true
	img.cell = Vector2i(3, 3)
	var opt := str((e.weapons.attack_options(hero)[0] as Dictionary)["id"])
	assert_true(e.attack(hero, img, opt).ok)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Test Jester") and (t.contains("misses") or t.contains("or did it"))),
		"told as a miss or a doubtful hit")
	assert_false(hero.id in (img.get_meta(DecoyImages.SEEN) as Array))


func test_a_success_sees_through_it_and_after_that_it_just_passes_through() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var img := got[3] as Combatant
	e.legendary.story_flags["test_fooling"] = true
	var sp := DecoyImages.spec_of(e.get_c(str(img.get_meta("image_of"))))
	(sp["save"] as Dictionary)["dc"] = 1
	e.images.struck(hero, img, "A test blow", "attack")
	assert_true(hero.id in (img.get_meta(DecoyImages.SEEN) as Array), "sees it is an image")
	e.images.struck(hero, img, "Another blow", "attack")
	assert_true(e.log.texts().has("Another blow passes straight through Test Jester"))


func test_spells_at_it_do_nothing() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var img := got[3] as Combatant
	var hp := img.creature.hp
	e.images.struck(got[1] as Combatant, img, "Fire Bolt", "spell")
	assert_eq(img.creature.hp, hp)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Fire Bolt passes straight through")), "outside its time")


func test_a_study_unmasks_it() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var img := got[3] as Combatant
	img.cell = Vector2i(5, 3)
	var cat := ActionCatalog.new(e)
	assert_true(bool(cat.find(hero, "study_image:" + img.id).get("legal", false)))
	TestCombat.next_d20(e, 20)
	assert_true(e.images.study(hero, img).ok)
	assert_true(img.has_meta("left_fight"), "it fades")


func test_its_maker_sends_it_and_the_flag_ends_it() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var owner := got[2] as Combatant
	var img := got[3] as Combatant
	e.images.owner_turn(owner)
	assert_true(e.distance(img, hero) <= 5, "60 ft toward the hero")
	e.legendary.story_flags["test_unmasked"] = true
	e.images.check_flags()
	assert_true(img.has_meta("left_fight"))


func test_its_maker_strikes_through_it() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var owner := got[2] as Combatant
	var img := got[3] as Combatant
	img.cell = Vector2i(3, 3)
	e.turn_index = e.order.find(owner)
	var zap := e.option_by_id(owner, "monster:zap")
	var claw := e.option_by_id(owner, "monster:claw")
	assert_true(e.images.attack_origin(owner, hero, zap) == img, "the zap from the image's square")
	assert_true(e.images.attack_origin(owner, hero, claw) == null, "the claw only from its own")
	var hp := hero.creature.hp
	assert_true(e.attack(owner, hero, "monster:zap").ok)
	assert_true(hero.creature.hp < hp, "a hit")
	assert_eq(owner.cell, Vector2i(12, 7), "back in its own square")
	assert_false(e.attack(owner, hero, "monster:claw").ok, "out of reach")


func test_a_grab_at_it_closes_on_nothing() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var img := got[3] as Combatant
	img.cell = Vector2i(3, 3)
	assert_true(e.grappling.unarmed_special(hero, img, "grapple").ok)
	assert_false(e.grapples.has(img.id))
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("grab passes straight through")))
