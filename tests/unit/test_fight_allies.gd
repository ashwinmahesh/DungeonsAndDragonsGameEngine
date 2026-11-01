extends TestCase
## Allies in a fight (a location monster entry's `side: "ally"`, added as a guest): a stat block on the party's side that
## the player controls, like every party member and guest, and that counts for the party.

const MILITIA := {"id": "test_militia", "name": "Test Militia", "speed": {"walk": 30},
	"actions": [{"id": "spear", "name": "Spear", "kind": "melee", "attack": {"bonus": 30, "reach": 5}, "damage": [{"dice": "1d6", "type": "piercing"}]}]}


func test_an_ally_is_the_players_to_command() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1), 5)
	var ally := e.add(TestChars.dummy(30, false, MILITIA.duplicate(true)), &"guest", Vector2i(5, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, ally)
	assert_true(ally.is_player_controlled(), "the player commands it")
	assert_false(ally.hostile_to(hero))
	assert_true(ally.hostile_to(foe))
	var hp := foe.creature.hp
	assert_true(e.attack(ally, foe, "monster:spear").ok, "its own stat block's attack")
	assert_true(foe.creature.hp < hp)
	hero.creature.hp = 0
	hero.creature.dead = true
	e.turns._check_over()
	assert_eq(e.state, Encounter.State.ACTIVE, "with the ally still up, the party isn't beaten")
