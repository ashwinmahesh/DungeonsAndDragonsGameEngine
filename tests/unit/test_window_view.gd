extends TestCase
## A moving place's windows (WindowView): with a map's `window_view` every hung window's glass gets the outside streaming
## past, over the glass and at its size, in the place's colours, moving the same way through the world whichever wall
## the window is on; without the key, or on a piece with no glass, nothing is added.

const SPEC := {"colours": ["night_deep", "mist_blue", "moonlight"], "streams": [-1, 0], "speed": 2.0, "strength": 0.8}
const ROWS := ["#####", "#...#", "#...#", "#####"]
const ELEV := ["11111", "11111", "11111", "11111"]


## A window as a model hangs it: a holder facing `yaw`, the model, and its glass decal (a region of a picture).
func _window(yaw: float) -> Node3D:
	var holder := Node3D.new()
	holder.rotation.y = yaw
	var model := Node3D.new()
	holder.add_child(model)
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.8, 0.9, 1.0))
	var glass := Sprite3D.new()
	glass.name = "Decal_glass"
	glass.texture = ImageTexture.create_from_image(img)
	glass.region_enabled = true
	glass.region_rect = Rect2(0, 0, 8, 16)
	glass.pixel_size = 0.05
	glass.position = Vector3(0, 0.6, 0.012)
	model.add_child(glass)
	return holder


func _view(holder: Node3D) -> MeshInstance3D:
	var found := holder.find_children(WindowView.NODE_NAME, "MeshInstance3D", true, false)
	return found[0] as MeshInstance3D if found.size() == 1 else null


func test_a_window_gets_the_view_over_its_glass() -> void:
	var w := _window(0.0)
	assert_eq(WindowView.dress_with(w, SPEC), 1, "one pane")
	var v := _view(w)
	assert_true(v != null, "the view is there")
	assert_eq((v.mesh as QuadMesh).size, Vector2(0.4, 0.8), "the glass's size")
	assert_true(v.position.z > 0.0, "just in front of the glass")
	var mat := v.material_override as ShaderMaterial
	assert_eq(mat.get_shader_parameter("deep"), Look.color("night_deep"), "the place's deepest colour")
	assert_eq(mat.get_shader_parameter("light"), Look.color("moonlight"), "and its lightest")
	assert_true(bool(mat.get_shader_parameter("use_mask")), "the frame and bars show through")
	assert_eq(mat.get_shader_parameter("mask_region"), Vector4(0, 0, 0.5, 0.5), "masked by the decal's own region")
	assert_eq(float(mat.get_shader_parameter("strength")), 0.8, "as strong as asked")
	w.free()


func test_the_outside_streams_one_way_through_the_world() -> void:
	# A pane facing south (+z) has its right towards +x: the outside moving west runs to its left. The pane across the
	# carriage faces north and has its right towards -x: the same outside runs to its right.
	assert_between(WindowView.scroll_along(SPEC, 0.0), -2.001, -1.999, "south-facing pane: to its left")
	assert_between(WindowView.scroll_along(SPEC, PI), 1.999, 2.001, "north-facing pane: to its right")
	assert_between(WindowView.scroll_along(SPEC, PI / 2.0), -0.001, 0.001, "a pane facing along the way sees no sideways drift")
	var north := _window(PI)
	WindowView.dress_with(north, SPEC)
	assert_between(float((_view(north).material_override as ShaderMaterial).get_shader_parameter("scroll")), 1.999, 2.001,
		"the dressed pane carries it")
	north.free()


func test_nothing_without_the_key_or_the_glass() -> void:
	var b := ArenaBoard.build(CombatGrid.from_rows(ROWS, ELEV), "manor", "")
	add_child(b)
	var w := _window(0.0)
	assert_eq(WindowView.dress(b, w), 0, "a place without a window view")
	assert_true(_view(w) == null, "adds nothing")
	b.set_meta("window_view", SPEC)
	assert_eq(WindowView.dress(b, w), 1, "with one, the pane gets it")
	var plain := Node3D.new()
	plain.add_child(Sprite3D.new())
	assert_eq(WindowView.dress(b, plain, "painting"), 0, "a piece with no glass gets nothing")
	w.free()
	plain.free()
	b.free()


func test_a_flat_window_picture_gets_it_too() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var sp := Sprite3D.new()
	sp.texture = ImageTexture.create_from_image(img)
	sp.pixel_size = 0.1
	assert_eq(WindowView.dress_with(sp, SPEC, "window_tall"), 1, "a picture named as a window")
	assert_eq((_view(sp).mesh as QuadMesh).size, Vector2(0.8, 0.8), "over the whole picture")
	var other := Sprite3D.new()
	other.texture = sp.texture
	assert_eq(WindowView.dress_with(other, SPEC, "portrait"), 0, "a portrait is no window")
	sp.free()
	other.free()
