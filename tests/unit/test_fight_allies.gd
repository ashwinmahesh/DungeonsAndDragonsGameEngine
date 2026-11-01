extends TestCase
## Allies in a fight (a location monster entry's `side: "ally"`): a stat block on the party's side that the AI plays,
## that fights the foes, counts for the party, and isn't one of the heroes.

const MILITIA := {"id": "test_militia", "name": "Test Militia", "speed": {"walk": 30},
	"actions": [{"id": "spear", "name": "Spear", "kind": "melee", "attack": {"bonus": 30, "reach": 5}, "damage": [{"dice": "1d6", "type": "piercing"}]}]}


func test_an_ally_fights_the_foes_on_its_own() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1), 5)
	var ally := e.add(TestChars.dummy(30, false, MILITIA.duplicate(true)), &"guest", Vector2i(5, 3))
	ally.controller = &"ai"   # as LocationFights adds an `ally`
	var foe := TestCombat.punching_bag(e, Vector2i(7, 3), 200)
	TestCombat.start_with(e, ally)
	assert_false(ally.is_player_controlled(), "the AI plays it")
	var hp := foe.creature.hp
	e.ai.play_turn(ally)
	assert_true(foe.creature.hp < hp, "it went for the foe")
	assert_false(hero.creature.hp < hero.creature.max_hp(), "and left the hero alone")
	assert_false(ally.hostile_to(hero))
