extends TestCase
## Symptoms that act in a fight (`on_initiative`, `on_hurt`; Afflictions.hooks, EncounterTurns, EncounterDamage) and
## Disadvantage on one ability's weapon attacks (`attack:<ability>`, docs/contracts/modifiers.md).

const ID := "test_rot"
const DEF := {"id": ID, "name": "Test Rot", "modifiers": [], "symptoms": {"table": [
	{"id": "addled", "name": "Addled", "on_initiative": {"save": {"ability": "wis", "dc": 40}, "flag": "confused"}},
	{"id": "bleeding", "name": "Bleeding", "on_hurt": {"dice": "1d10", "type": "necrotic"}},
	{"id": "fever", "name": "Fever", "modifiers": [{"stat": "disadvantage", "on": "attack:str"}]}]}}


func before_each() -> void:
	Compendium.shared().table("afflictions")[ID] = DEF.duplicate(true)


func after_each() -> void:
	Compendium.shared().table("afflictions").erase(ID)


func _with(ch: Creature, symptoms: Array) -> void:
	Afflictions.set_level(ch, ID, 1)
	(Afflictions.effect_of(ch, ID).data["symptoms"] as Array).assign(symptoms)
	Afflictions.set_level(ch, ID, 1)


func test_an_addled_mind_is_confused_as_initiative_is_rolled() -> void:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	TestCombat.punching_bag(e, Vector2i(9, 3))
	_with(hero.creature, ["addled"])
	e.start()
	assert_true(hero.creature.has_flag("confused"), "DC 40: it fails, and acts as Confusion makes it")


func test_bleeding_hurts_more_with_every_wound() -> void:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, hero)
	_with(hero.creature, ["bleeding"])
	var hp := hero.creature.hp
	e.deal_damage(foe, hero, [{"amount": 3, "type": "slashing"}], false, "test")
	assert_true(hero.creature.hp <= hp - 4, "3 and at least 1 more Necrotic (%d -> %d)" % [hp, hero.creature.hp])
	assert_false(hero.has_meta("symptom_hurt"), "no loop")


func test_a_fever_hinders_strength_attacks_only() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 3)
	_with(ch, ["fever"])
	var dis := ch.modifiers_for(&"disadvantage").filter(func(m: Modifier) -> bool: return m.text("on") == "attack:str")
	assert_eq(dis.size(), 1, "on attack:str, the key every Strength weapon attack carries")
	var e := TestCombat.open_field(3)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var opt: Dictionary = {}
	for o in e.attack_options(c):
		if (o["profile"] as WeaponProfile).ability == &"str":
			opt = o
	assert_true(EncounterAttacks.roll_keys(opt).has("attack:str"), "the roll is made under it")
