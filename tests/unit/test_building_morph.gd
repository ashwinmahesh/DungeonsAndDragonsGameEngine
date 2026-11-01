extends TestCase
## A place's houses can warp on screen (BuildingMorph, plan G8): the catalog's building_kit.bend.morph names the place, its houses'
## walls and roofs carry a second, tidier bend as a blend shape, and the weight moves between them. A place the catalog does not name
## is built as before, with no blend shapes at all.

const ROWS := ["................", "................", "................", "...####.........", "...####.........", "...####.........",
	"................", "................", "................", "................"]
const ELEV := ["1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111",
	"1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111"]
const PLACE := "morph_test_place"

var _was := ""


func before_each() -> void:
	_was = Look.style()
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(_was, false)
	_morph_config().erase(PLACE)


func _morph_config() -> Dictionary:
	var bend := ((SetDressing.catalog()["building_kit"] as Dictionary)["bend"]) as Dictionary
	if not bend.has("morph"):
		bend["morph"] = {}
	return bend["morph"] as Dictionary


func _board() -> ArenaBoard:
	var b := ArenaBoard.build(CombatGrid.from_rows(ROWS, ELEV), "village", PLACE)
	add_child(b)
	return b


func test_a_place_the_catalog_does_not_name_builds_no_blend_shapes() -> void:
	var b := _board()
	assert_false(BuildingMorph.has_morph(b), "no morph without the catalog's say")
	BuildingMorph.follow(b, 1.0)
	assert_eq(BuildingMorph.weight(b), 0.0, "and asking for one changes nothing")
	b.free()


func test_a_named_place_carries_a_tidy_shape_its_walls_and_roofs_can_go_to() -> void:
	_morph_config()[PLACE] = {"tidy": 0.05}
	var b := _board()
	assert_true(BuildingMorph.has_morph(b), "the houses carry the blend shape")
	var checked := 0
	for mi in BuildingMorph.meshes(b):
		var mesh := mi.mesh as ArrayMesh
		assert_eq(mesh.get_blend_shape_count(), 1, "one shape: the tidy one")
		var base := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var tidy := (mesh.surface_get_blend_shape_arrays(0)[0] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		assert_eq(base.size(), tidy.size(), "point for point")
		var far := 0.0
		for i in base.size():
			far = maxf(far, base[i].distance_to(tidy[i]))
		assert_true(far > 0.02, "the tidy shape is not the built one (%.3f)" % far)
		checked += 1
	assert_true(checked >= 2, "walls and roof both morph (%d)" % checked)
	b.free()


func test_the_weight_follows_the_campaign_at_once_first_and_as_a_warp_after() -> void:
	_morph_config()[PLACE] = {"tidy": 0.05}
	var b := _board()
	BuildingMorph.follow(b, 1.0)
	assert_eq(BuildingMorph.weight(b), 1.0, "a place built before its change starts settled")
	for mi in BuildingMorph.meshes(b):
		assert_eq(mi.get_blend_shape_value(0), 1.0, "on every mesh")
	BuildingMorph.follow(b, 0.0)
	assert_eq(float(b.get_meta(BuildingMorph.META_TARGET)), 0.0, "a new target is noted")
	b.free()
