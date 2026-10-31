extends TestCase
## CombatToken keeps the art each character on the field wears, by id, so an echo (`look_of`) can wear its knight's.
## A character with no id used to leave its art under "" there, and every stat block without `look_of` then wore that
## hero's art from then on: whichever test built such a token first changed the portraits and sprites of every later
## one (test_portrait_art failed after test_figure_layers).


func test_a_character_without_an_id_leaves_no_look_behind() -> void:
	var ch := Character.new()
	ch.name = "Test Nobody"
	var c := Combatant.new(ch, &"party", Vector2i.ZERO)
	c.id = ""
	var tok := CombatToken.create(c, "test_hero_look")
	add_child(tok)
	tok.free()
	assert_false(CombatToken._looks.has(""), "nothing kept under an empty id")
	assert_eq(CombatToken.monster_art({"id": "test_beast"}), "test_beast", "a stat block wears its own art")


func test_a_look_of_still_finds_its_hero() -> void:
	var ch := Character.new()
	ch.id = "test_knight"
	ch.name = "Test Knight"
	var tok := CombatToken.create(Combatant.new(ch, &"party", Vector2i.ZERO), "test_knight_look")
	add_child(tok)
	tok.free()
	assert_eq(CombatToken.monster_art({"id": "test_echo", "look_of": "test_knight"}), "test_knight_look", "an echo wears its knight's art")
	CombatToken._looks.erase("test_knight")
