extends TestCase
## An object's own effects as it breaks or is eaten (ObjectView.sound_for): art/audio.json "objects" names them by what
## eats the object (its fuel) and else by its kind; with no entry nothing plays, so a game without the key sounds as it did.

var _saved: Variant = null


func before_each() -> void:
	super.before_each()
	_saved = Audio._data.get("objects", null)


func after_each() -> void:
	if _saved == null:
		Audio._data.erase("objects")
	else:
		Audio._data["objects"] = _saved


func _object(kind: String, fuel: String) -> BattleObject:
	var o := BattleObject.new()
	o.kind = kind
	o.fuel = fuel
	return o


func test_fuel_names_the_sound_before_the_kind() -> void:
	Audio._data["objects"] = {"lamp_oil": {"broken": "jar_smash", "eaten": "oil_gulp"}, "crate": {"broken": "wood_break"}}
	assert_eq(ObjectView.sound_for(_object("crate", "lamp_oil"), "broken"), "jar_smash", "the fuel's entry wins")
	assert_eq(ObjectView.sound_for(_object("crate", "lamp_oil"), "eaten"), "oil_gulp")
	assert_eq(ObjectView.sound_for(_object("crate", ""), "broken"), "wood_break", "else the kind's")
	assert_eq(ObjectView.sound_for(_object("crate", ""), "eaten"), "", "a moment it has no sound for is silent")


func test_no_entry_is_silent() -> void:
	Audio._data.erase("objects")
	assert_eq(ObjectView.sound_for(_object("crate", "lamp_oil"), "broken"), "", "a game with no objects table plays nothing")
