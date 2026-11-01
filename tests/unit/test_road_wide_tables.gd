extends TestCase
## Random encounter tables that hold only `when` a condition does, and `every_road` tables rolled on whatever road the
## party takes (a hunted villain's minions), `per_night` once a night at most (Travel.roll).

const ROAD := {"id": "test_road", "name": "Test Road", "table": "test_road_table"}

var _saved: Dictionary = {}


## Dice that always roll 1: every chance comes up (a road table's is capped at 95%).
class LowDice:
	extends DiceRoller

	func roll_one(_sides: int, _reason: String = "") -> int:
		return 1


func before_each() -> void:
	var tables := Compendium.shared().table("random_encounters")
	_saved = tables.duplicate()
	Compendium.shared().tables["random_encounters"] = tables   # a campaign without tables has none to add to
	tables["test_road_table"] = {"id": "test_road_table", "map": "test_map", "chance_day": 1.0, "chance_night": 1.0,
		"when": "flag.road_open", "entries": [{"weight": 1, "id": "road_fight", "monsters": [{"monster": "wolf", "cell": [1, 1]}]}]}
	tables["test_hunt"] = {"id": "test_hunt", "map": "test_map", "chance_day": 0.0, "chance_night": 1.0,
		"every_road": true, "per_night": true, "when": "flag.hunt_on",
		"entries": [{"weight": 1, "id": "minions", "monsters": [{"monster": "wolf", "cell": [1, 1]}]}]}


func after_each() -> void:
	Compendium.shared().tables["random_encounters"] = _saved


func _night(st: StoryState, day: int, hour: int) -> void:
	st.day = day
	st.minute_of_day = hour * 60


func _id(ev: Dictionary) -> String:
	return "" if ev.is_empty() else str((ev["entry"] as Dictionary).get("id", ""))


func test_a_table_rolls_only_while_its_condition_holds() -> void:
	var st := StoryState.new()
	_night(st, 1, 23)
	var dice := LowDice.new()
	assert_eq(_id(Travel.roll(ROAD, st, dice)), "", "neither table's condition holds")
	st.flags["road_open"] = true
	assert_eq(_id(Travel.roll(ROAD, st, dice)), "road_fight")


func test_an_every_road_table_rolls_on_a_quiet_road_once_a_night() -> void:
	var st := StoryState.new()
	st.flags["hunt_on"] = true
	var dice := LowDice.new()
	_night(st, 1, 22)
	assert_eq(_id(Travel.roll({"id": "other", "name": "Other"}, st, dice)), "minions", "a road with no table of its own")
	_night(st, 2, 2)
	assert_eq(_id(Travel.roll(ROAD, st, dice)), "", "the small hours are the same night")
	if not Calendar.eternal_night():
		_night(st, 2, 12)
		assert_eq(_id(Travel.roll(ROAD, st, dice)), "", "never by day")
	_night(st, 2, 21)
	assert_eq(_id(Travel.roll(ROAD, st, dice)), "minions", "the next night")
	st.flags["road_open"] = true
	_night(st, 3, 21)
	assert_eq(_id(Travel.roll(ROAD, st, dice)), "road_fight", "the road's own table goes first")
	assert_eq(_id(Travel.roll(ROAD, st, dice)), "road_fight")
	st.flags.erase("road_open")
	assert_eq(_id(Travel.roll(ROAD, st, dice)), "minions", "the hunt wasn't rolled while the road's own table struck")
	assert_eq(_id(Travel.roll(ROAD, st, dice)), "")


func test_find_the_path_quiets_every_table() -> void:
	var st := StoryState.new()
	st.flags["hunt_on"] = true
	st.flags["road_open"] = true
	_night(st, 1, 22)
	st.active_spells["find_the_path"] = {"until": st.total_minutes() + 600}
	assert_eq(_id(Travel.roll(ROAD, st, LowDice.new())), "")
