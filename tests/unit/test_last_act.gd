extends TestCase
## A hero's willing death beside a set piece (LastAct): asked first, then gone for good, and the foe crippled.

const LAVA := {"id": "test_lava", "kind": "vessel", "cell": [3, 3], "name": "a lava well", "ac": 20, "hp": 999,
	"last_act": {"label": "Give yourself to the fire", "target": ["Test Behemoth"], "flag": "test_last_act",
		"say": "walks into the fire",
		"effect": {"name": "Unmade", "no_legendary_resistance": true,
			"modifiers": [{"stat": "disadvantage", "on": ["attack", "save:all", "check:all"]}, {"stat": "vulnerability", "value": "radiant"}]}}}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	TestCombat.hero(e, "thistle", Vector2i(2, 5), 5)
	var boss := e.add(TestChars.dummy(400, false, {"name": "Test Behemoth"}), &"enemy", Vector2i(9, 3))
	e.objects.put(LAVA.duplicate(true))
	TestCombat.start_with(e, hero)
	return [e, hero, boss]


func test_asked_first_then_gone_for_good_and_the_foe_crippled() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var boss := got[2] as Combatant
	var cat := ActionCatalog.new(e)
	var act := cat.find(hero, "lastact:test_lava")
	assert_false(act.is_empty())
	assert_true(cat.perform(hero, act).ok)
	assert_true(e.pending != null and e.pending.kind == LastAct.KIND, "asked once more")
	e.answer_reaction(true)
	assert_true(hero.creature.dead)
	assert_ne(str((hero.creature as Character).build.get("soul_gone", "")), "", "the soul is gone")
	assert_ne(SpellHandlers.revivify_why(e, hero), "", "no Revivify")
	assert_ne(FieldCasting.revive_why(StoryState.new(), "raise_dead", hero.creature as Character), "", "nor Raise Dead")
	assert_true(boss.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "last_act"), "the Behemoth unmade")
	assert_true(bool(e.legendary.story_flags.get("test_last_act", false)))


func test_declined_nothing_happens() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var cat := ActionCatalog.new(e)
	cat.perform(hero, cat.find(hero, "lastact:test_lava"))
	e.answer_reaction(false)
	assert_false(hero.creature.dead)
	assert_true(hero.action_available, "the action isn't spent")
