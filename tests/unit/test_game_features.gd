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
	GameFeatures.use(GameFeatures)   # whatever module this game names, a game without one has the base
	var e := TestCombat.open_field()
	assert_true(e.game != null, "every encounter has one")
	assert_eq((e.game.get_script() as GDScript).resource_path, (GameFeatures as GDScript).resource_path, "the base, which does nothing")
	assert_true(e.game.perform(null, "anything", null, Vector2i.ZERO, Vector2.ZERO).ok == false)
	GameFeatures.use(null)


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


func test_a_dark_gift_may_carry_features_and_be_taken_in_part() -> void:
	var gifts := Compendium.shared().table("dark_gifts")
	gifts["test_bargain"] = {"id": "test_bargain", "name": "Test Bargain", "vestige": "a voice", "summary": "A test.",
		"benefit": {"text": "Power.", "features": [
			{"id": "test_boon_a", "name": "Boon A", "summary": "A.", "text": "A.", "resource": {"id": "test_boon_a", "name": "Boon A", "max": 1, "recharge": "long"}},
			{"id": "test_boon_b", "name": "Boon B", "summary": "B.", "text": "B.", "modifiers": [{"stat": "resistance", "value": "necrotic"}]}]},
		"cost": {"text": "A price.", "features": [
			{"id": "test_price", "name": "Price", "summary": "P.", "text": "P.", "modifiers": [{"stat": "vulnerability", "value": "psychic"}]}]}}
	var whole := TestChars.custom("fighter", "human", 1)
	whole.accept_dark_gift("test_bargain")
	assert_eq(whole.resource_max("test_boon_a"), 1, "a benefit feature's resource")
	assert_true(whole.resistance_source(&"necrotic") != "", "a benefit feature's modifier")
	assert_true(whole.modifiers_for(&"vulnerability").size() > 0, "and the price")
	assert_true(CombatFeatures.has_feature(TestCombat.open_field().add(whole, &"party", Vector2i(1, 1)), "test_price"), "code can read its features")
	var part := TestChars.custom("fighter", "human", 1)
	var only: Array[String] = ["test_boon_b"]
	part.accept_dark_gift("test_bargain", only)
	assert_true(part.resistance_source(&"necrotic") != "", "the part taken")
	assert_eq(part.resource_max("test_boon_a"), 0, "not the part left")
	assert_true(part.modifiers_for(&"vulnerability").is_empty(), "and no price")
	gifts.erase("test_bargain")


func test_an_ability_increase_with_a_minimum_level_comes_only_with_a_feat_taken_that_late() -> void:
	var feats := Compendium.shared().table("feats")
	feats["test_late_bloomer"] = {"id": "test_late_bloomer", "name": "Late Bloomer", "source": {"book": "test"}, "category": "origin",
		"summary": "A test.", "ability_increase": {"points": 1, "max": 20, "min_level": 4},
		"benefits": [{"id": "test_late_bloom", "name": "Bloom", "summary": "B.", "text": "B.", "modifiers": [{"stat": "initiative", "value": 1}]}]}
	var late := TestChars.custom("fighter", "human", 4, {".4.ability_score_improvement": ["test_late_bloomer"]})
	assert_true(late.choice_defs.any(func(c: Choice) -> bool: return c.key.ends_with("test_late_bloomer.abilities")), "taken at level 4: +1 to an ability")
	var early := TestChars.custom("fighter", "human", 1, {"species.versatile": ["test_late_bloomer"]})
	assert_true(early.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "test_late_bloomer"), "the feat itself at level 1")
	assert_false(early.choice_defs.any(func(c: Choice) -> bool: return c.key.ends_with("test_late_bloomer.abilities")), "but no increase")
	feats.erase("test_late_bloomer")


func test_a_conversation_can_ask_for_a_subclass_a_feature_or_a_feat() -> void:
	var ch := TestChars.custom("fighter", "human", 3, {"species.versatile": ["alert"]})
	var sub := str(ch.subclasses.get("fighter", ""))
	assert_true(sub != "")
	assert_true(StoryState.member_matches(ch, "subclass:" + sub))
	assert_false(StoryState.member_matches(ch, "subclass:circle_of_the_moon"))
	assert_true(StoryState.member_matches(ch, "feature:second_wind"), "a class feature by id")
	assert_true(StoryState.member_matches(ch, "feat:alert"))
	assert_false(StoryState.member_matches(ch, "feat:tough"))


## Answers the hooks a book's options lean on: a spell that reaches anyone, an action wasted, a death cheated, a
## minute-long casting allowed in a fight.
class Hooks extends GameFeatures:
	var wasted := false

	func spell_reach(_c: Combatant, _s: Dictionary, _t: Combatant) -> bool:
		return true

	func wastes_action(_c: Combatant, kind: String) -> bool:
		return wasted and kind == "attack"

	func cheats_death(t: Combatant) -> bool:
		t.creature.hp = 1
		return true


func test_the_hooks_a_book_leans_on() -> void:
	GameFeatures.use(Hooks)
	var e := TestCombat.open_field(5)
	var c := TestCombat.caster_with(e, ["cure_wounds"], Vector2i(0, 0), 3, "silvain_aster")
	var far := e.add(TestChars.custom("fighter", "human", 3), &"party", Vector2i(11, 7))
	var foe := TestCombat.punching_bag(e, Vector2i(1, 0))
	TestCombat.start_with(e, c)
	var check := e.spells.targeting._check_targets(c, Compendium.shared().spell_data("cure_wounds"), 1, [far], Vector2.INF, {})
	assert_eq(str(check.get("why", "")), "", "a touch spell reaches a far ally when the game says so")
	(e.game as Hooks).wasted = true
	c.attacks_left = 0
	c.action_available = true
	var r := e.attack(c, foe, str(e.attack_options(c)[0]["id"]))
	assert_false(r.hit, "the Attack action is wasted")
	assert_false(c.action_available, "and spent")
	far.creature.hp = 1
	e.deal_damage(foe, far, [{"amount": 500, "type": "force"}], false, "Test")
	assert_false(far.creature.dead, "an outright death the game cheats")
	assert_eq(far.creature.hp, 1)
	GameFeatures.use(null)


func test_a_hero_of_an_undead_or_construct_species_can_be_revived_and_put_to_sleep() -> void:
	var e := TestCombat.open_field()
	var ch := TestChars.custom("fighter", "human", 3)
	ch.creature_type = &"undead"
	var hero := e.add(ch, &"party", Vector2i(1, 1))
	hero.creature.dead = true
	assert_eq(SpellHandlers.revivify_why(e, hero), "", "a soul in a made body comes back")
	var zombie := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	zombie.creature.dead = true
	assert_true(SpellHandlers.revivify_why(e, zombie) != "", "an Undead monster doesn't")
