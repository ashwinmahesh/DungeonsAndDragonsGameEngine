extends TestCase
## A body some damage ruins for good (a monster entry's `body`; Legendary._ruin, docs/contracts/locations.md): only a
## blow that drops it with damage of a named type ruins it, setting its flag and adding to its count, and its warning
## is there to read before anyone strikes.

const BODY := {"ruined_by": ["fire", "bludgeoning"], "flag": "test_body_ruined", "count": "test_bodies_ruined",
	"warn": "Someone is inside. Fire or crushing ends them for good."}


func _fight(n: int = 1) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var foes: Array[Combatant] = []
	for i in n:
		var foe := TestCombat.punching_bag(e, Vector2i(5 + i, 3), 10)
		foe.creature.set_meta(Legendary.BODY, BODY)
		foes.append(foe)
	TestCombat.start_with(e, hero)
	return [e, hero, foes]


func _hit(e: Encounter, by: Combatant, t: Combatant, parts: Array) -> void:
	e.deal_damage(by, t, parts, false, "test")


func test_a_sword_kill_ruins_nothing() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var foe := (got[2] as Array[Combatant])[0]
	_hit(e, got[1] as Combatant, foe, [{"amount": 20, "type": "slashing"}])
	assert_true(foe.is_down())
	assert_false(e.legendary.story_flags.has("test_body_ruined"))
	assert_false(e.legendary.story_flags.has("test_bodies_ruined"))


func test_fire_or_a_mixed_blow_that_drops_it_ruins_it() -> void:
	var got := _fight(2)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foes := got[2] as Array[Combatant]
	_hit(e, hero, foes[0], [{"amount": 20, "type": "fire"}])
	assert_true(bool(e.legendary.story_flags.get("test_body_ruined", false)), "fire drops it: ruined")
	assert_eq(e.legendary.story_flags["test_bodies_ruined"], {"add": 1})
	_hit(e, hero, foes[1], [{"amount": 3, "type": "slashing"}, {"amount": 20, "type": "bludgeoning"}])
	assert_eq(e.legendary.story_flags["test_bodies_ruined"], {"add": 2}, "a claw-and-crush blow counts too")
	assert_true(e.log.entries.any(func(en: Dictionary) -> bool: return str(en["text"]).ends_with("is ruined for good")))


func test_an_earlier_fire_hit_that_did_not_drop_it_does_not_count() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := (got[2] as Array[Combatant])[0]
	_hit(e, hero, foe, [{"amount": 3, "type": "fire"}])
	assert_false(foe.is_down())
	_hit(e, hero, foe, [{"amount": 20, "type": "piercing"}])
	assert_true(foe.is_down())
	assert_false(e.legendary.story_flags.has("test_body_ruined"), "the blow that dropped it was piercing")


func test_a_fall_is_bludgeoning() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var foe := (got[2] as Array[Combatant])[0]
	e.movement.fall(foe, 100)
	assert_true(foe.is_down())
	assert_true(bool(e.legendary.story_flags.get("test_body_ruined", false)), "a long fall crushes")


func test_a_burning_tick_that_drops_it_ruins_it() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var foe := (got[2] as Array[Combatant])[0]
	foe.creature.hp = 1
	e.monster_actions.set_burning(got[1] as Combatant, foe)
	e.spells._turn_start_effects(foe)
	assert_true(foe.is_down(), "the flames take its last Hit Point")
	assert_true(bool(e.legendary.story_flags.get("test_body_ruined", false)), "and burning is fire")


func test_the_warning_reads_until_it_drops() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var foe := (got[2] as Array[Combatant])[0]
	assert_eq(Legendary.body_warning(foe), "Someone is inside. Fire or crushing ends them for good.")
	assert_eq(Legendary.body_warning(got[1] as Combatant), "", "no rule, no warning")
	_hit(e, got[1] as Combatant, foe, [{"amount": 20, "type": "slashing"}])
	assert_eq(Legendary.body_warning(foe), "", "nothing to warn of once it's down")


func test_the_place_adds_the_count_to_the_story() -> void:
	var view := LocationView.new()
	view.st = StoryState.new()
	view.loc = {"id": "test_field", "region": ""}
	var made := LocationFights.monsters_for(view, {"id": "test_scarecrows", "monsters": [{"monster": "wolf", "cell": [1, 1], "body": BODY}]})
	assert_eq((made[0]["creature"] as Monster).get_meta(Legendary.BODY), BODY, "the entry's body rule")
	view.st.set_flag("test_bodies_ruined", 1)
	LocationFights.hand_back_flags(view.st, {"test_bodies_ruined": {"add": 2}, "test_plain": true})
	assert_true(bool(view.st.get_flag("test_plain", false)), "a plain flag is set as ever")
	assert_eq(int(view.st.get_flag("test_bodies_ruined", 0)), 3, "added to what the story had")
	view.free()
