extends TestCase
## Things carried to other things (ObjectCarry; an encounter's `objects` with `carry`, `takes`, `hazard` and `study`):
## a plain thing no blow or spell can touch, taken up and put into a brazier that is cleansed by it, its hazard over, a
## named foe struck and a warding light lit; a hazard that tires those who come near; a Study that tells what it is.

const TAKES := {"tag": "test_kindling", "label": "Feed", "flag": "test_fed", "say": "The fire takes it.",
	"damage": {"who": ["Test Warden"], "amount": 10, "type": "psychic"},
	"light": {"radius": 20, "disadvantage": ["Test Warden"], "color": "#4080ff"}}
const HAZARD := [{"on": "enter", "near_ft": 5, "save": {"ability": "cha", "dc": 40}, "exhaustion": 1, "unless_flag": "test_phase_2"},
	{"on": "end", "near_ft": 5, "save": {"ability": "cha", "dc": 40}, "exhaustion": 1, "if_flag": "test_phase_2"}]


func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var warden := e.add(TestChars.dummy(200, false, {"id": "test_warden", "name": "Test Warden"}), &"enemy", Vector2i(10, 6))
	var thing := e.objects.put({"id": "test_thing", "kind": "crate", "cell": [3, 3], "name": "a bundle", "carry": {"tag": "test_kindling"},
		"study": {"skills": ["arcana", "investigation"], "dc": 5, "say": "They are kindling.", "flag": "test_known"}})
	var brazier := e.objects.put({"id": "test_brazier", "kind": "brazier", "cell": [8, 6], "name": "a brazier", "takes": TAKES,
		"hazard": HAZARD})
	TestCombat.start_with(e, hero)
	return [e, hero, warden, thing, brazier]


func test_a_plain_thing_cant_be_harmed() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var thing := got[3] as BattleObject
	assert_eq(thing.blocks, 0, "in nobody's way")
	var o := e.weapons.attack_options(hero)[0] as Dictionary
	assert_true(e.objects.attack_why(hero, thing, o).contains("can't be attacked"))


func test_take_it_carry_it_put_it_in() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var warden := got[2] as Combatant
	var thing := got[3] as BattleObject
	var brazier := got[4] as BattleObject
	var cat := ActionCatalog.new(e)
	assert_true(bool(cat.find(hero, "carry:" + thing.id).get("legal", false)), "the hotbar offers it within 5 ft")
	assert_true(e.objects.carry.take(hero, thing.id).ok)
	assert_false(hero.free_interaction_available, "its object interaction")
	assert_eq(e.objects.carry.held_by(hero), thing)
	assert_false(e.objects.carry.put(hero, brazier.id).ok, "too far yet")
	hero.cell = Vector2i(7, 6)
	var hp := warden.creature.hp
	assert_true(e.objects.carry.put(hero, brazier.id).ok)
	assert_true(thing.destroyed, "used up")
	assert_true(brazier.cleansed)
	assert_true(brazier.hazard.is_empty(), "its hazard is over")
	assert_true(bool(e.legendary.story_flags.get("test_fed", false)))
	assert_eq(warden.creature.hp, hp - 10, "the named foe is struck")
	assert_true(e.log.texts().has("The fire takes it."))


func test_the_ward_puts_named_creatures_at_disadvantage() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var warden := got[2] as Combatant
	var brazier := got[4] as BattleObject
	brazier.ward = (TAKES["light"] as Dictionary).duplicate(true)
	assert_eq(e.objects.carry.ward_disadvantage(warden), ["A brazier"] as Array[String])
	assert_true(e.objects.carry.ward_disadvantage(hero).is_empty(), "only those it names")
	var t := warden.creature.roll_save(e.dice, &"dex", 10)
	assert_true(t.disadvantage, "Disadvantage on its D20 Tests")
	warden.cell = Vector2i(14, 6)
	assert_true(e.objects.carry.ward_disadvantage(warden).is_empty(), "outside its 20 ft")


func test_coming_near_the_fire_tires_once_a_turn() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	e.move(hero, Vector2i(7, 5))
	assert_eq(hero.creature.exhaustion, 1, "stepping near it")
	e.move(hero, Vector2i(7, 3))
	e.move(hero, Vector2i(7, 5))
	assert_eq(hero.creature.exhaustion, 1, "once a turn")


func test_the_second_phase_hazard_strikes_at_the_end_of_a_turn() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	e.legendary.story_flags["test_phase_2"] = true
	e.move(hero, Vector2i(7, 5))
	assert_eq(hero.creature.exhaustion, 0, "the first phase's hazard is over")
	e.end_turn()
	assert_eq(hero.creature.exhaustion, 1, "ending a turn near it")


func test_dropping_leaves_it_on_the_floor() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var thing := got[3] as BattleObject
	e.objects.carry.take(hero, thing.id)
	hero.cell = Vector2i(5, 3)
	hero.creature.hp = 0
	e.objects.carry.tidy()
	assert_eq(thing.carried_by, "")
	assert_eq(thing.cells, [Vector2i(5, 3)] as Array[Vector2i])


func test_study_tells_what_it_is() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var thing := got[3] as BattleObject
	TestCombat.next_d20(e, 20)
	assert_true(e.objects.carry.study(hero, thing.id).ok)
	assert_true(thing.studied)
	assert_true(bool(e.legendary.story_flags.get("test_known", false)))
	assert_true(e.log.texts().has("They are kindling."))


func test_it_all_comes_back_from_a_save() -> void:
	var got := _fight()
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var thing := got[3] as BattleObject
	e.objects.carry.take(hero, thing.id)
	var back := BattleObject.from_dict(thing.to_dict())
	assert_eq(back.carried_by, hero.id)
	assert_eq(back.carry, thing.carry)
	var b2 := BattleObject.from_dict((got[4] as BattleObject).to_dict())
	assert_eq(b2.takes, TAKES)
	assert_eq(b2.hazard, HAZARD)
