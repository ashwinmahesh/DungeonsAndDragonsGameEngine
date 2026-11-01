extends TestCase
## The ground blend (Look.blend_ground) takes any floor surface, including one with no ORM map: a game's own surfaces
## (a village tile borrowed from the engine's marsh mud) have none, and the blend used to stop at a null "use_orm".

var _was := ""


func before_each() -> void:
	_was = Look.style()
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(_was, false)


func test_a_surface_with_no_orm_map_blends() -> void:
	var plain := ShaderMaterial.new()
	plain.set_meta("surface", "test/plain_tile")
	plain.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8)))
	assert_true(plain.get_shader_parameter("use_orm") == null, "nothing set use_orm, as with a surface with no ORM file")
	var control := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var slots: Array[ShaderMaterial] = [plain]
	var blend := Look.blend_ground(slots, control, Vector2(4, 4))
	assert_true(blend != null, "the blend is made")
	assert_false(bool(blend.get_shader_parameter("use_orm_a")), "it has no ORM layer, so the blend uses none")
	assert_true(blend.get_shader_parameter("albedo_a") != null, "and its albedo is set")
