extends TestCase
## A game's own features module (GameFeatures, the script data/campaign.json names under "features"): a fight without
## one has the base, which does nothing; one put in place is made with every encounter, its hotbar actions are listed
## and performed as "feat:gm:<id>", and the encounter calls its hooks for heroes and monsters alike. Also the
## background fields a book's origins need: any ability, a skill pick, languages and any origin feat.


## Writes down which hooks the encounter called, and offers one hotbar action that adds a die to the next hit.
class Recorder extends GameFeatures:
	var calls: Array[String] = []

	func list(c: Combatant, out: Array[Dictionary], _aw: String, _bw: String) -> void:
		if c.side == &"party":
			out.append(_entry("ping", "Ping", "a test action", "free", "", "none", "Writes down that it ran."))

	func perform(c: Combatant, id: String, _t: Combatant, _cell: Vector2i, _point: Vector2) -> CombatResult:
		calls.append("perform:%s:%s" % [id, c.id])
		return CombatResult.new()

	func fight_started() -> void:
		calls.append("fight_started")

	func turn_start(c: Combatant) -> CombatResult:
		calls.append("turn_start:" + c.side)
		return CombatResult.new()

	func turn_end(c: Combatant) -> void:
		calls.append("turn_end:" + c.side)

	func attack_situation(_c: Combatant, _target: Combatant, _option: Dictionary, _adv: Array[String], dis: Array[String]) -> void:
		calls.append("attack_situation")
		dis.append("Test jinx")

	func hit_dice(_c: Combatant, _target: Combatant, _option: Dictionary, _st: Dictionary) -> Array[Dictionary]:
		calls.append("hit_dice")
		return []

	func after_hit(_c: Combatant, _target: Combatant, _option: Dictionary, _st: Dictionary, _r: CombatResult) -> void:
		calls.append("after_hit")

	func after_damage(_source: Combatant, target: Combatant, amount: int, _parts: Array = [], dr: DamageResult = null) -> void:
		calls.append("after_damage:%s:%d:%s" % [target.side, amount, "dr" if dr != null else "no dr"])

	func monster_turn(c: Combatant) -> Variant:
		calls.append("monster_turn")
		enc().log.add("info", "%s waits (test module)" % c.name(), c.id)
		return CombatResult.new()


func before_each() -> void:
	GameFeatures.use(null)


func _fight() -> Dictionary:
	var e := TestCombat.open_field(3)
	var c := e.add(TestChars.custom("fighter", "human", 3), &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	return {"e": e, "c": c, "foe": foe}


func test_a_game_without_a_module_gets_the_base() -> void:
	var e := TestCombat.open_field()
	assert_true(e.game != null, "every encounter has one")
	assert_eq((e.game.get_script() as GDScript).resource_path, (GameFeatures as GDScript).resource_path, "the base, which does nothing")
	assert_true(e.game.perform(null, "anything", null, Vector2i.ZERO, Vector2.ZERO).ok == false)


func test_the_module_in_place_is_made_with_each_encounter_and_its_actions_reach_the_hotbar() -> void:
	GameFeatures.use(Recorder)
	var sc := _fight()
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	assert_true(e.game is Recorder)
	TestCombat.start_with(e, c)
	var ids: Array[String] = []
	for x in e.feature_actions.list(c):
		ids.append(str(x["id"]))
	assert_true("feat:gm:ping" in ids, "its action is on the hotbar: %s" % str(ids))
	var r := e.feature_actions.perform(c, "gm:ping", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_true("perform:ping:%s" % c.id in (e.game as Recorder).calls)
	GameFeatures.use(null)


func test_the_encounter_calls_its_hooks_for_heroes_and_monsters() -> void:
	GameFeatures.use(Recorder)
	var sc := _fight()
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	TestCombat.start_with(e, c)
	var rec := e.game as Recorder
	assert_true("fight_started" in rec.calls)
	assert_true("turn_start:party" in rec.calls, str(rec.calls))
	var sit := e.attack_situation(c, foe, e.attack_options(c)[0])
	assert_true("Test jinx" in (sit["disadvantage"] as Array), "its Disadvantage source counts")
	var hit := false
	for i in 6:
		TestCombat.next_d20(e, 20)
		c.attacks_left = 1
		c.action_available = true
		if e.attack(c, foe, str(e.attack_options(c)[0]["id"])).hit:
			hit = true
			break
	assert_true(hit)
	assert_true("hit_dice" in rec.calls and "after_hit" in rec.calls, str(rec.calls))
	assert_true(rec.calls.any(func(s: String) -> bool: return s.begins_with("after_damage:enemy:") and s.ends_with(":dr")), str(rec.calls))
	e.end_turn()
	assert_true("turn_end:party" in rec.calls)
	assert_true("turn_start:enemy" in rec.calls, "monsters' turns too")
	e.ai.begin_turn(foe)
	assert_true("monster_turn" in rec.calls, "the AI asks the game first")
	GameFeatures.use(null)


func test_a_background_may_raise_any_ability_and_give_picks_languages_and_any_origin_feat() -> void:
	var bgs := Compendium.shared().table("backgrounds")
	bgs["test_wanderer"] = {"id": "test_wanderer", "name": "Test Wanderer", "source": {"book": "test"}, "summary": "A test.",
		"ability_scores": ["str", "dex", "con", "int", "wis", "cha"], "feat": "alert", "feat_choice": {"filter": {"category": "origin"}},
		"skills": ["survival"], "languages": ["sylvan"], "tool": {"id": "herbalism_kit"},
		"equipment": [{"id": "a", "gp": 1}, {"id": "b", "gp": 50}],
		"features": [{"id": "lore", "name": "Lore", "summary": "A skill.", "text": "A skill.",
			"choice": {"kind": "skill", "count": 1, "from": ["arcana", "history"]}}]}
	var b := CharacterBuilder.new()
	b.set_class("fighter")
	b.set_background("test_wanderer")
	b.set_species("human")
	b.set_name("Test")
	assert_eq(b.choose("background.abilities", ["cha", "cha", "int"]), [] as Array[String], "any two abilities, +2/+1")
	assert_true(b.get_choice("background.lore") != null, "the background's own skill pick")
	assert_eq(b.choose("background.lore", ["arcana"]), [] as Array[String])
	var feats: Array[String] = []
	for o in b.get_choice("background.feat_choice").options:
		feats.append(o.id)
	assert_true("tough" in feats and "alert" in feats, "any origin feat")
	assert_false("great_weapon_master" in feats, "general feats aren't")
	var ch := b.preview()
	assert_true((ch.proficiencies["skills"] as Dictionary).has("arcana"), "the pick")
	assert_true((ch.proficiencies["skills"] as Dictionary).has("survival"), "the fixed skill")
	assert_true((ch.proficiencies["languages"] as Dictionary).has("sylvan"), "the language")
	assert_eq(ch.ability_score(&"cha"), int((ch.build["base_scores"] as Dictionary)["cha"]) + 2, "+2 Charisma")
	bgs.erase("test_wanderer")
