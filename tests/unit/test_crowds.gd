extends TestCase
## Crowds (an area's `crowd`; Crowds): the squares they mill about in, and the square they jostle the party onto.


func _grid() -> CombatGrid:
	var rows: Array[String] = []
	for z in 6:
		rows.append("..........")
	rows[2] = "....#....."
	return CombatGrid.from_rows(rows)


func test_the_squares_they_fill() -> void:
	var cells := Crowds.area_cells(_grid(), [[3, 1], [5, 3]])
	assert_eq(cells.size(), 8, "nine squares, less the wall")
	assert_false(Vector2i(4, 2) in cells)


func test_jostled_toward_the_middle() -> void:
	var g := _grid()
	assert_eq(Crowds.push_step(g, Vector2i(0, 0), Vector2i(5, 5)), Vector2i(1, 1), "a diagonal step")
	assert_eq(Crowds.push_step(g, Vector2i(3, 1), Vector2i(5, 3)), Vector2i(4, 1), "round the wall")
	assert_eq(Crowds.push_step(g, Vector2i(5, 5), Vector2i(5, 5)), Vector2i(5, 5), "there already")
