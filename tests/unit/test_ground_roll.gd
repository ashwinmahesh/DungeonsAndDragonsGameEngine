extends TestCase
## Gently rolling open ground (plan N9): with the campaign's "ground_roll" natural ground swells a little between its
## rules heights, everything drawn on it stands on the swell, the rules' heights never move, and the roll eases off
## toward water, walls and the map's edge. Without it the ground is as it was.

const ROWS := ["..............", "..............", "..............", "..............", "..............",
	"..............", "..............", "..............", "..........ww..", "..........ww.."]
const ELEV := ["11111111111111", "11111111111111", "11111111111111", "11111111111111", "11111111111111",
	"11111111111111", "11111111111111", "11111111111111", "11111111111111", "11111111111111"]


func after_each() -> void:
	Campaign.use_config(null)


func _board() -> ArenaBoard:
	var b := ArenaBoard.build(CombatGrid.from_rows(ROWS, ELEV), "forest", "roll_test")
	add_child(b)
	return b


func test_no_roll_without_the_setting() -> void:
	Campaign.use_config({})
	var b := _board()
	assert_eq(b.ground_roll(), 0.0, "no roll")
	assert_between(b.ground_y(Vector2(6.3, 4.7)), 0.999, 1.001, "level ground at its rules height")
	b.free()


func test_the_ground_rolls_but_the_rules_do_not() -> void:
	Campaign.use_config({"ground_roll": 0.25})
	var b := _board()
	var lo := INF
	var hi := -INF
	for z in range(2, 7):
		for x in range(2, 9):
			var y := b.ground_y(Vector2(x + 0.5, z + 0.5))
			lo = minf(lo, y)
			hi = maxf(hi, y)
			assert_eq(b.grid.height(Vector2i(x, z)), 5, "the rules' height stays 5 ft")
			assert_between(b.cell_center(Vector2i(x, z)).y, y - 0.001, y + 0.001, "a token stands on the swell")
	assert_true(hi - lo > 0.05, "the meadow rolls (%.3f)" % (hi - lo))
	assert_true(hi - 1.0 <= 0.26 and 1.0 - lo <= 0.26, "within the roll either way")
	# Beside the water and at the map's edge the ground keeps its own height, so shores and the land beyond meet it.
	assert_between(b.corner_height(Vector2i(9, 8), Vector2i(1, 0)), 0.999, 1.001, "no roll at the water's edge")
	assert_between(b.corner_height(Vector2i(0, 0), Vector2i(0, 0)), 0.999, 1.001, "none at the map's edge")
	b.free()
