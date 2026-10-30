extends TestCase
## A creek whose bed drops 10 ft or more between neighbouring squares pours over the step as a waterfall (Shores.falls),
## its levels either side kept apart, white water at the foot; a 5 ft step only slopes the stream.

const ROWS := ["....ww....", "....ww....", "....ww....", "....ww....", "....ww....", "....ww...."]
const ELEV := ["4444444444", "4444444444", "4444444444", "1111111111", "1111111111", "0000000000"]


func test_a_big_step_is_a_waterfall() -> void:
	Look.set_style("modern", false)
	var b := ArenaBoard.build(CombatGrid.from_rows(ROWS, ELEV), "forest", "falls_test")
	add_child(b)
	var view_relief := GroundRelief.build(b, {"map": {"rows": ROWS, "elevation": ELEV, "outdoors": true}}, null)
	var shore := view_relief.shore
	assert_true(shore != null and shore.sloped(), "a raised creek")
	if shore == null:
		b.free()
		return
	var falls := shore.falls()
	assert_eq(falls.size(), 2, "the 15 ft step falls over both of its squares")
	for f: Dictionary in falls:
		assert_eq(f["facing"], Vector2i(0, 1), "pouring south, downhill")
		assert_between(float(f["drop"]), 2.99, 3.01, "15 ft")
	assert_true(shore.water_y(Vector2(4.5, 2.5)) - shore.water_y(Vector2(4.5, 3.5)) > 2.0, "the levels either side stay apart")
	assert_true(float(shore.flow_at(Vector2(4.5, 3.4))[2]) > 0.5, "white water at the foot")
	b.free()
