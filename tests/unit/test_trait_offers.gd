extends TestCase
## A monster's trait that offers everyone else an action against it (a trait's `offers` block; TraitOffers,
## docs/reference/contracts/monsters.md): a Bonus Action within range, an ability check, and on a success damage and
## riders on the monster, with an ability event under the block's key either way.

const OFFER := {"key": "test_waltz_step", "label": "Test Waltz", "cost": "bonus", "range": 30,
	"check": {"skill": "performance", "dc": 10}, "damage": [{"amount": 20, "type": "force"}],
	"on_success": [{"do": "condition", "condition": "", "until": "source_turn_start", "modifiers": [
		{"stat": "disadvantage", "on": "attack"}, {"stat": "disadvantage", "on": "save:all"}, {"stat": "disadvantage", "on": "check:all"}]}]}


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var m := TestChars.dummy(100, false, {"name": "Test Dancer", "traits": [{"id": "test_waltz", "name": "Test Waltz",
		"action": "bonus_action", "summary": "Anyone can dance for it.", "offers": OFFER.duplicate(true)}]})
	var holder := e.add(m, &"enemy", Vector2i(6, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, holder]


func test_the_hotbar_offers_it_near_the_holder_as_a_bonus_action() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var holder := got[2] as Combatant
	var cat := ActionCatalog.new(e)
	var act := cat.find(hero, "offer:%s:test_waltz" % holder.id)
	assert_false(act.is_empty(), "the hotbar offers the trait's action")
	assert_eq(str(act["cost"]), "bonus")
	assert_true(bool(act["legal"]), "20 ft away is within its 30 ft")
	hero.cell = Vector2i(0, 0)
	holder.cell = Vector2i(11, 7)
	act = cat.find(hero, "offer:%s:test_waltz" % holder.id)
	assert_false(bool(act["legal"]), "not from across the field")
	assert_true(str(act["reason"]).begins_with("Get within 30 ft"))
	assert_true(cat.find(holder, "offer:%s:test_waltz" % holder.id).is_empty(), "the holder can't take its own offer")


func test_a_success_hurts_and_hinders_the_holder_until_the_users_next_turn() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var holder := got[2] as Combatant
	var cat := ActionCatalog.new(e)
	var mark := e.events.size()
	var hp := holder.creature.hp
	TestCombat.next_d20(e, 20)
	assert_true(cat.perform(hero, cat.find(hero, "offer:%s:test_waltz" % holder.id)).ok)
	assert_eq(holder.creature.hp, hp - 20, "20 Force damage")
	assert_false(hero.bonus_available, "it took the Bonus Action")
	assert_true(hero.action_available, "and not the action")
	var told := e.events.slice(mark).filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "ability")
	assert_eq(told.size(), 1, "one ability event")
	assert_eq(str((told[0] as Dictionary)["key"]), "test_waltz_step", "under the block's key")
	assert_eq((told[0] as Dictionary)["targets"], [holder.id])
	var fx: Effect = null
	for x in holder.creature.effects:
		if x.name == "Test Waltz":
			fx = x
	assert_true(fx != null, "the rider lands on the holder")
	assert_eq(fx.ends, Effect.Ends.START_OF_TURN)
	assert_eq(fx.turn_owner_id, hero.id, "it lasts until the start of the dancer's next turn")
	assert_eq(fx.modifiers.filter(func(md: Modifier) -> bool: return md.stat == &"disadvantage").size(), 3,
		"Disadvantage on attacks, saves and checks")
	assert_false(bool(cat.find(hero, "offer:%s:test_waltz" % holder.id)["legal"]), "once a turn: the Bonus Action is spent")


func test_a_failed_check_still_dances_but_does_nothing() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var holder := got[2] as Combatant
	var mark := e.events.size()
	var hp := holder.creature.hp
	TestCombat.next_d20(e, 1)
	assert_true(e.trait_offers.take(hero, holder, "test_waltz").ok)
	assert_eq(holder.creature.hp, hp, "no damage")
	assert_true(holder.creature.effects.all(func(x: Effect) -> bool: return x.name != "Test Waltz"), "no rider")
	assert_false(hero.bonus_available, "the try spent the Bonus Action")
	assert_true(e.events.slice(mark).any(func(ev: Dictionary) -> bool: return str(ev["type"]) == "ability" and str(ev["key"]) == "test_waltz_step"),
		"the view still hears the dance")


func test_a_creature_without_the_trait_offers_nothing() -> void:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3))
	TestCombat.start_with(e, hero)
	assert_true(e.trait_offers.entries(hero).is_empty())
	assert_false(e.trait_offers.take(hero, foe, "test_waltz").ok)


# --- A contest: the user's check sets the holder's save DC ------------------------------------------

const CONTEST := {"key": "test_tune_duel", "label": "Tune Duel", "influence": true, "range": 60, "needs": "musical_instrument",
	"check": {"skill": "performance"}, "contest": {"save": "cha"}, "damage": [{"amount": 20, "type": "psychic"}],
	"on_success": [{"do": "condition", "condition": "stunned", "until": "source_turn_end"}]}


func _contest_fight(cha: int) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var m := TestChars.dummy(100, false, {"name": "Test Fiddler", "abilities": {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": cha},
		"traits": [{"id": "test_duel", "name": "Tune Duel", "action": "special", "summary": "It can't refuse a contest.", "offers": CONTEST.duplicate(true)}]})
	var holder := e.add(m, &"enemy", Vector2i(6, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, holder]


func test_a_contest_needs_an_instrument_and_files_under_influence() -> void:
	var got := _contest_fight(1)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var holder := got[2] as Combatant
	var cat := ActionCatalog.new(e)
	var act := cat.find(hero, "offer:%s:test_duel" % holder.id)
	assert_true(str(act["label"]).begins_with("Influence: Tune Duel"), "an Influence variant")
	assert_eq(str(act["cost"]), "action")
	assert_false(bool(act["legal"]), "no instrument, no contest")
	(hero.creature as Character).add_item("lyre", 1)
	assert_true(bool(cat.find(hero, "offer:%s:test_duel" % holder.id)["legal"]), "with a lyre it can")
	assert_eq(TraitOffers.tool_for(hero, "musical_instrument"), "lyre")


func test_a_lost_contest_hurts_and_stuns_the_holder_until_the_end_of_the_users_next_turn() -> void:
	var got := _contest_fight(1)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var holder := got[2] as Combatant
	(hero.creature as Character).add_item("lyre", 1)
	var mark := e.events.size()
	var hp := holder.creature.hp
	TestCombat.next_d20(e, 20)
	assert_true(e.trait_offers.take(hero, holder, "test_duel").ok)
	assert_eq(holder.creature.hp, hp - 20, "20 Psychic on the failed save")
	assert_true(holder.creature.has_condition(&"stunned"), "and Stunned")
	var fx: Effect = null
	for x in holder.creature.effects:
		if &"stunned" in x.conditions:
			fx = x
	assert_eq(fx.ends, Effect.Ends.END_OF_TURN)
	assert_eq(fx.turn_owner_id, hero.id)
	assert_eq(fx.skip_turn_ends, 1, "not this turn's end: the end of the user's next turn")
	assert_false(hero.action_available, "it took the action")
	assert_true(e.events.slice(mark).any(func(ev: Dictionary) -> bool: return str(ev["type"]) == "ability" and str(ev["key"]) == "test_tune_duel"))


func test_a_matched_contest_does_nothing() -> void:
	var got := _contest_fight(30)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var holder := got[2] as Combatant
	(hero.creature as Character).add_item("lyre", 1)
	var hp := holder.creature.hp
	TestCombat.next_d20(e, 1)
	assert_true(e.trait_offers.take(hero, holder, "test_duel").ok)
	assert_eq(holder.creature.hp, hp, "its save beat the check")
	assert_false(holder.creature.has_condition(&"stunned"))
