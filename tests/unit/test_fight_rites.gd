extends TestCase
## A rite as a fight objective (vault "Design - Final Rites as a fight objective"): the fight is won only with the
## meter full and the foes down, themes roll the hero's best skill with Advantage from what the party remembers, a
## brilliant success moves a second meter, a failure bursts on everyone with a choice, and the story keeps the count.

const RITE := {"id": "test_rite", "label": "Rite", "max": 3, "pips": true, "menu": "Honour the Fallen", "store": "test_rite_brilliance_never",
	"actions": [
		{"id": "feats", "label": "Honour his feats", "check": {"skills": ["acrobatics", "athletics"], "dc": 15},
			"advantage_when": "flag.test_memory", "brilliant": {"by": 5, "meter": "test_brilliance"},
			"failure_event": {"affects": "party", "save": {"ability": "wis", "dc": 30}, "damage": {"dice": "1d6", "type": "psychic"},
				"condition": "stunned", "instead": {"damage": {"dice": "6d6", "type": "psychic"}}}},
		{"id": "other", "label": "Some other way", "check": {"any_skill": true, "dc": 18}}]}
const BRILLIANCE := {"id": "test_brilliance", "label": "Brilliance", "store": "test_brilliance"}


func _fight(st: StoryState, guardian_hp: int = 300) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "ask"
	e.ends_when = {"meters_needed": [{"meter": "test_rite", "value": 3}]}
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var guardian := TestCombat.punching_bag(e, Vector2i(9, 3), guardian_hp)
	e.meters.setup(FightMeters.for_story([RITE, BRILLIANCE], st))
	TestCombat.start_with(e, hero)
	return [e, hero, guardian]


func test_the_best_skill_advantage_from_memory_and_brilliance() -> void:
	var st := StoryState.new()
	st.flags["test_memory"] = true
	var got := _fight(st)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var cat := ActionCatalog.new(e)
	var act := cat.find(hero, "meter:test_rite:feats")
	var best := "Athletics" if hero.creature.skill_bonus(&"athletics").total() >= hero.creature.skill_bonus(&"acrobatics").total() else "Acrobatics"
	assert_eq(str(act["sub"]), "DC 15 %s (Advantage)" % best)
	TestCombat.next_d20(e, 20)
	assert_true(cat.perform(hero, act).ok)
	assert_eq(e.meters.value("test_rite"), 1)
	assert_eq(e.meters.value("test_brilliance"), 1, "beat the DC by 5: brilliant")
	assert_eq(e.meters.lines()[0], "Rite ●○○", "pips")


func test_beating_the_foes_waits_for_the_rite_and_the_rite_for_the_foes() -> void:
	var got := _fight(StoryState.new(), 5)
	var e := got[0] as Encounter
	var guardian := got[2] as Combatant
	e.deal_damage(null, guardian, [{"amount": 50, "type": "force"}], false, "Test", [])
	e._check_over()
	assert_eq(e.state, Encounter.State.ACTIVE, "the guardian is down but the rite isn't done")
	e.meters.change("test_rite", 3)
	assert_eq(e.state, Encounter.State.OVER, "both now")
	assert_eq(e.outcome, "victory")
	assert_eq(int(e.legendary.story_flags.get("test_brilliance", -1)), 0, "the count goes to the story")
	var got2 := _fight(StoryState.new())
	var e2 := got2[0] as Encounter
	e2.meters.change("test_rite", 3)
	assert_eq(e2.state, Encounter.State.ACTIVE, "the rite is done but the guardian stands")


func test_a_failure_bursts_and_a_hero_may_take_damage_instead_of_the_stun() -> void:
	var got := _fight(StoryState.new())
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var cat := ActionCatalog.new(e)
	TestCombat.next_d20(e, 1)
	var hp := hero.creature.hp
	cat.perform(hero, cat.find(hero, "meter:test_rite:feats"))
	assert_true(e.pending != null and e.pending.kind == "rite_burst", "asked")
	e.answer_reaction(false)
	assert_true(hero.creature.has_condition(&"stunned"), "kept the stun")
	assert_true(hero.creature.hp < hp, "the burst's own damage")
	var got2 := _fight(StoryState.new())
	var e2 := got2[0] as Encounter
	var hero2 := got2[1] as Combatant
	TestCombat.next_d20(e2, 1)
	ActionCatalog.new(e2).perform(hero2, ActionCatalog.new(e2).find(hero2, "meter:test_rite:feats"))
	var before := hero2.creature.hp
	e2.answer_reaction(true)
	assert_false(hero2.creature.has_condition(&"stunned"), "took the damage instead")
	assert_true(hero2.creature.hp < before)


func test_any_skill_uses_the_heros_best() -> void:
	var got := _fight(StoryState.new())
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var best := &"athletics"
	for s: StringName in Abilities.SKILLS.keys():
		if hero.creature.skill_bonus(s).total() > hero.creature.skill_bonus(best).total():
			best = s
	assert_eq(e.meters.skill_for(hero, {"any_skill": true, "dc": 18}), best)


func test_the_themes_fold_under_one_hotbar_entry() -> void:
	var got := _fight(StoryState.new())
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var bar := ActionCatalog.new(e).slots(hero, ActionCatalog.COMMON)
	var group: Dictionary = {}
	for a: Dictionary in bar:
		if bool(a.get("group", false)) and str(a.get("label", "")) == "Honour the Fallen":
			group = a
	assert_false(group.is_empty(), "one entry for the rite")
	assert_eq((group.get("items", []) as Array).size(), 2, "its two ways in it")
	var feats := (group["items"] as Array)[0] as Dictionary
	assert_true(str(feats.get("menu_sub", "")).ends_with("DC 15 (Adv)") or str(feats.get("menu_sub", "")).contains("DC 15"),
		"the menu says what it rolls")
