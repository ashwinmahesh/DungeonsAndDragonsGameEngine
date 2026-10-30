extends TestCase
## A place sketched as land and laid into the grid (PlaceSketch, plan E29): the layout's colours become the legend's
## squares by what covers most of each, the height painting the elevation rows in 5 ft steps, water its bed's lowest,
## and the report names what would give the grid away.


## A 10 x 6 place painted at 20 pixels a square: a round pond, a wood, a hill rising east, a lone bramble.
func _sketch() -> Array[Image]:
	var layout := Image.create(200, 120, false, Image.FORMAT_RGBA8)
	layout.fill(Color.WHITE)
	var height := Image.create(200, 120, false, Image.FORMAT_RGBA8)
	for y in 120:
		for x in 200:
			height.set_pixel(x, y, Color.WHITE * (float(x) / 199.0) if x > 100 else Color.BLACK)
			if Vector2(x, y).distance_to(Vector2(50, 60)) < 32.0:
				layout.set_pixel(x, y, Color("#0000ff"))
			if x >= 160 and y < 40:
				layout.set_pixel(x, y, Color("#006400"))
	layout.fill_rect(Rect2i(120, 80, 20, 20), Color("#8b4513"))
	return [height, layout]


func test_the_layout_and_height_become_rows() -> void:
	var pics := _sketch()
	var laid := PlaceSketch.lay(pics[0], pics[1], Vector2i(10, 6), {"top_ft": 30})
	var rows := laid["rows"] as Array[String]
	var elev := laid["elevation"] as Array[String]
	assert_eq(rows.size(), 6, "six rows")
	assert_eq(rows[0].length(), 10, "ten squares across")
	assert_eq(rows[3][2], "w", "the pond's middle is water")
	assert_eq(rows[0][0], ".", "open ground")
	assert_eq(rows[0][9], "#", "the wood")
	assert_eq(rows[4][6], "~", "the bramble")
	assert_eq(elev[3][0], "0", "low ground at the west")
	assert_eq(elev[3][9], "6", "30 ft up at the east edge (white), in 5 ft steps")
	assert_true(int(elev[3][7]) < int(elev[3][9]), "the hill rises east")


func test_the_report_names_what_gives_the_grid_away() -> void:
	var pics := _sketch()
	var laid := PlaceSketch.lay(pics[0], pics[1], Vector2i(10, 6))
	var rep := laid["report"] as Dictionary
	assert_eq(rep["lone"], [[6, 4, "~"]], "the lone bramble square")
	assert_false(bool(rep["flat"]), "the place has height")
	var flat := PlaceSketch.report(["....", "ww..", "ww.."] as Array[String], ["0000", "0000", "0000"] as Array[String])
	assert_true(bool(flat["flat"]), "a flat outdoor place is named")
	assert_eq(flat["square_water"], [[0, 1, 1, 2]], "a square pond is named")
	var cliff := PlaceSketch.report(["...", "..."] as Array[String], ["000", "300"] as Array[String])
	assert_eq((cliff["cliffs"] as Array).size(), 2, "a 15 ft step up to the raised square, from above and beside it")


func test_a_redrawn_map_may_not_close_walked_squares() -> void:
	var loc := {"map": {"rows": ["....", "...."]}, "spawns": {"default": [3, 1]}, "exits": [{"id": "e", "cell": [0, 0]}]}
	assert_eq(load("res://addons/dnd_core/world/authoring/sketch_tool.gd").closes(loc, ["....", "...."] as Array[String]),
		[] as Array[Vector2i], "the same squares: nothing closed")
	var closed: Array[Vector2i] = load("res://addons/dnd_core/world/authoring/sketch_tool.gd").closes(loc, ["w...", "...#"] as Array[String])
	assert_eq(closed, [Vector2i(0, 0), Vector2i(3, 1)] as Array[Vector2i], "the exit's and the spawn's squares")


func test_preview_draws_a_square_per_cell() -> void:
	var img := PlaceSketch.preview([".w", "#~"] as Array[String], ["01", "23"] as Array[String], 8)
	assert_eq(img.get_size(), Vector2i(16, 16), "8 pixels a square")
