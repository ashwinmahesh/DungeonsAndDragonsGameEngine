extends TestCase
## An affliction that holds a hero at a place (`holds_at`, Afflictions.holding): the party can't leave while one of
## them has it, may go between the rooms it names, and is free once it's cleared.

const ID := "test_lure"
const DEF := {"id": ID, "name": "Test Lure", "modifiers": [],
	"holds_at": {"locations": ["test_hall", "test_deck"], "min_level": 2, "text": "{name} won't leave the tables."}}


func before_each() -> void:
	Compendium.shared().table("afflictions")[ID] = DEF.duplicate(true)


func after_each() -> void:
	Compendium.shared().table("afflictions").erase(ID)


func test_a_held_hero_keeps_the_party_in_its_rooms() -> void:
	var a := TestChars.pregen("hedda_ironvow", 3)
	var b := TestChars.pregen("thistle", 3)
	var party := [a, b]
	assert_eq(Afflictions.holding(party, "test_hall", "", "outside"), "")
	Afflictions.set_level(b, ID, 1)
	assert_eq(Afflictions.holding(party, "test_hall", "", "outside"), "", "below its level")
	Afflictions.set_level(b, ID, 2)
	assert_eq(Afflictions.holding(party, "test_hall", "", "outside"), "%s won't leave the tables." % b.name)
	assert_ne(Afflictions.holding(party, "test_hall", "", "travel"), "", "nor take the road")
	assert_eq(Afflictions.holding(party, "test_hall", "", "test_deck"), "", "another of its rooms is fine")
	assert_eq(Afflictions.holding(party, "elsewhere", "", "outside"), "", "it holds only at its places")
	Afflictions.clear(b, ID)
	assert_eq(Afflictions.holding(party, "test_hall", "", "outside"), "", "free once cleared")
