extends TestCase
## A campaign's content settings in the pause menu (CampaignModule.comfort_options) and its content note on the
## loading card (content_note); the base module has neither.


class Careful extends CampaignModule:
	func comfort_options() -> Array[Dictionary]:
		return [{"key": "test_spiders", "label": "Show spiders", "tip": "Off: spiders are shown as shadows.", "default": true}]

	func content_note(region: String, _st: StoryState) -> String:
		return "Spiders here." if region == "test_caves" else ""


func after_each() -> void:
	Campaign.use(null)


func test_the_base_module_has_none() -> void:
	var m := CampaignModule.new()
	assert_eq(m.comfort_options(), [] as Array[Dictionary])
	assert_eq(m.content_note("anywhere", StoryState.new()), "")


func test_the_pause_menu_shows_and_keeps_a_campaign_setting() -> void:
	Campaign.use(Careful.new())
	var st := StoryState.new()
	var menu := PauseMenu.new()
	add_child(menu)
	menu.call("open", self, st, 0)
	menu.call("_show_settings", "Game")
	var boxes := menu.find_children("Comfort_test_spiders", "CheckBox", true, false)
	assert_eq(boxes.size(), 1, "its row is there")
	var box := boxes[0] as CheckBox
	assert_true(box.button_pressed, "on by default")
	box.button_pressed = false
	assert_false(bool(st.options["test_spiders"]), "kept in the playthrough")
	menu.queue_free()
