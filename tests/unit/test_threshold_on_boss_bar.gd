extends TestCase
## A boss's Damage Threshold that counts the living shows on its bar (BossBar._words), named by its label.


func test_the_bar_shows_the_threshold_as_it_stands() -> void:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var boss := e.add(TestChars.dummy(150, false, {"name": "Test Effigy", "damage_threshold": "10 * alive:test_chosen",
		"damage_threshold_label": "Ardor"}), &"enemy", Vector2i(8, 3))
	var a := e.add(TestChars.dummy(20, false, {"id": "test_chosen", "name": "Chosen"}), &"enemy", Vector2i(8, 5))
	e.add(TestChars.dummy(20, false, {"id": "test_chosen", "name": "Chosen"}), &"enemy", Vector2i(8, 6))
	TestCombat.start_with(e, hero)
	var bar := BossBar.new()
	bar.e = e
	assert_true(bar._words(boss).contains("Ardor 20"), bar._words(boss))
	e.deal_damage(null, a, [{"amount": 50, "type": "force"}], false, "Test", [])
	assert_true(bar._words(boss).contains("Ardor 10"), "one Chosen down")
	bar.free()
