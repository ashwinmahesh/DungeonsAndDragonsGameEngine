extends TestCase
## `auto_succeed` (docs/contracts/modifiers.md): a save against one named power passes without a roll; others roll.


func test_a_ward_against_one_power_passes_its_save_and_only_that_one() -> void:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var fx := Effect.new("A moth's wing", &"item", "test_wing").with_modifier("auto_succeed", {"on": ["save_vs:test_wings"]})
	hero.creature.add_effect(fx)
	var keys: Array[String] = ["save_vs:test_wings"]
	var t := hero.creature.roll_save(e.dice, &"wis", 40, [], [], "vs the wings", keys)
	assert_true(t.success and t.auto_succeeded, "the wings can't take a hero who holds the wing")
	assert_true(t.describe().contains("automatic success"))
	var other: Array[String] = ["save_vs:test_bite"]
	assert_false(hero.creature.roll_save(e.dice, &"wis", 40, [], [], "vs the bite", other).success, "any other power rolls")
