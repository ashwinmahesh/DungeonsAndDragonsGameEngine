extends TestCase
## Which picture a portrait chip shows (PortraitArt): what a game that hasn't turned `photoreal` on gets is what it always
## did, and with it on a monster is looked up by its stat block id, a missing portrait shows a silhouette and a tall
## portrait goes into a chip as a square cut from its top.

var _on := {"photoreal": true, "monster_dir": "art/portraits/monsters", "character_dir": "art/portraits/characters"}


func after_each() -> void:
	PortraitArt.reset()


func _combatant(id: String, side: StringName) -> Combatant:
	var e := TestCombat.open_field()
	return e.add(TestCombat.monster(id), side, Vector2i(4, 4))


func _names(node: Node) -> Array[String]:
	var out: Array[String] = []
	for n in node.get_children():
		out.append(str(n.name))
	return out


func test_without_the_key_a_portrait_is_the_plain_png_as_before() -> void:
	PortraitArt.use({"photoreal": false})
	assert_eq(PortraitArt.rel_paths("wolf", "wolf"), ["art/portraits/wolf.png"] as Array[String])
	assert_eq(PortraitArt.rel_paths("", "wolf").size(), 0)
	var chip := UiParts.framed_portrait("no_such_creature", 40.0, false, false, "no_such_creature")
	assert_false(chip.find_child("Placeholder", true, false) != null, "an empty frame, as before")
	chip.free()
	var tall := ImageTexture.create_from_image(Image.create(70, 90, false, Image.FORMAT_RGBA8))
	assert_true(PortraitArt.square(tall) == tall, "pictures go in as they are")
	assert_false(PortraitArt.large())


func test_a_monster_is_found_by_its_stat_block_id_then_as_a_character() -> void:
	PortraitArt.use(_on)
	assert_eq(PortraitArt.rel_paths("wolf_art", "dire_wolf"), [
		"art/portraits/monsters/dire_wolf.webp", "art/portraits/monsters/dire_wolf.png",
		"art/portraits/characters/wolf_art.webp", "art/portraits/characters/wolf_art.png",
		"art/portraits/wolf_art.webp", "art/portraits/wolf_art.png"] as Array[String])
	assert_eq(PortraitArt.rel_paths("ilse_varga"), [
		"art/portraits/characters/ilse_varga.webp", "art/portraits/characters/ilse_varga.png",
		"art/portraits/ilse_varga.webp", "art/portraits/ilse_varga.png"] as Array[String])


func test_a_game_can_name_its_own_folders() -> void:
	PortraitArt.use({"photoreal": true, "monster_dir": "art/x/beasts/", "character_dir": "art/x/people"})
	var paths := PortraitArt.rel_paths("a", "b")
	assert_eq(paths[0], "art/x/beasts/b.webp")
	assert_eq(paths[2], "art/x/people/a.webp")


func test_only_a_foe_looks_its_portrait_up_by_stat_block() -> void:
	assert_eq(PortraitArt.monster_id_of(_combatant("wolf", &"enemy")), "wolf")
	assert_eq(PortraitArt.monster_id_of(_combatant("wolf", &"neutral")), "wolf", "a neutral creature has its own")
	assert_eq(PortraitArt.monster_id_of(_combatant("wolf", &"party")), "", "a party member is a character")
	assert_eq(PortraitArt.monster_id_of(_combatant("wolf", &"guest")), "", "a guest wears their own face")


func test_a_creature_with_no_portrait_shows_a_silhouette_in_its_frame() -> void:
	PortraitArt.use(_on)
	var chip := UiParts.framed_portrait("no_such_creature", 34.0, false, false, "no_such_creature")
	assert_true(chip.find_child("Placeholder", true, false) != null, "a head and shoulders, not an empty hole")
	assert_eq(chip.custom_minimum_size, Vector2(34, 34))
	chip.free()


func test_a_chip_for_a_fighter_takes_its_frame_whatever_art_it_has() -> void:
	PortraitArt.use(_on)
	var chip := UiParts.framed_portrait_of(_combatant("wolf", &"enemy"), 44.0)
	assert_eq(chip.custom_minimum_size, Vector2(44, 44))
	chip.free()


func test_a_tall_portrait_is_cropped_to_a_square_from_the_top() -> void:
	PortraitArt.use(_on)
	var tall := ImageTexture.create_from_image(Image.create(70, 90, false, Image.FORMAT_RGBA8))
	var sq := PortraitArt.square(tall) as AtlasTexture
	assert_true(sq != null, "an AtlasTexture of the picture")
	assert_eq(sq.region, Rect2(0, 6, 70, 70), "30% of the 20 spare pixels cut from the top")
	var wide := ImageTexture.create_from_image(Image.create(100, 60, false, Image.FORMAT_RGBA8))
	assert_eq((PortraitArt.square(wide) as AtlasTexture).region, Rect2(20, 0, 60, 60), "the middle of a wide one")
	var sq_tex := ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))
	assert_true(PortraitArt.square(sq_tex) == sq_tex, "a square is left alone")


func test_a_large_portrait_follows_the_pictures_shape_within_limits() -> void:
	PortraitArt.use(_on)
	var square := ImageTexture.create_from_image(Image.create(100, 100, false, Image.FORMAT_RGBA8))
	var tall := ImageTexture.create_from_image(Image.create(100, 400, false, Image.FORMAT_RGBA8))
	var wide := ImageTexture.create_from_image(Image.create(400, 100, false, Image.FORMAT_RGBA8))
	assert_eq(PortraitArt.large_size(square, 240.0), Vector2(240, 240))
	assert_eq(PortraitArt.large_size(tall, 240.0), Vector2(240, 312), "no taller than 1.3 wide")
	assert_eq(PortraitArt.large_size(wide, 240.0), Vector2(240, 204), "no shorter than 0.85 wide")
	assert_eq(PortraitArt.large_size(null, 240.0), Vector2(240, 240), "the silhouette's frame is square")
	var big := UiParts.large_portrait("no_such_creature", "no_such_creature", 240.0)
	assert_true(big.find_child("Placeholder", true, false) != null)
	big.free()


func test_a_stat_block_with_no_look_of_ignores_a_blank_look() -> void:
	# A character built with no id once left a "" look behind, and every stat block without `look_of` matched it.
	CombatToken._looks[""] = "someone"
	assert_eq(CombatToken.monster_art({"id": "wolf"}), "wolf")
	CombatToken._looks.erase("")
