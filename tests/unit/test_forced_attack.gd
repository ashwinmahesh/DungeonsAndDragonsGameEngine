extends TestCase
## A `forced_attack` rider (Frenzying Spores): the target spends its Reaction on a melee attack against one of the
## source's foes within its reach.


func test_a_hero_is_driven_to_strike_an_ally() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var ally := TestCombat.hero(e, "thistle", Vector2i(3, 3), 5)
	var keeper := TestCombat.punching_bag(e, Vector2i(9, 3), 200)
	TestCombat.start_with(e, hero)
	var hp := ally.creature.hp
	TestCombat.next_d20(e, 20)
	e.monster_actions._forced_attack(keeper, hero, "Test Spores")
	assert_false(hero.reaction_available, "its Reaction is spent")
	assert_true(ally.creature.hp < hp, "on the ally beside it")
	var again := ally.creature.hp
	e.monster_actions._forced_attack(keeper, hero, "Test Spores")
	assert_eq(ally.creature.hp, again, "no Reaction left: nothing more")
