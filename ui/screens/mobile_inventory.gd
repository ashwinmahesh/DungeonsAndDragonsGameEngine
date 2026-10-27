class_name MobileInventory
extends RefCounted
## Mobile composition only. InventoryScreen continues to own item identity, filters, legality and mutations.

var screen: InventoryScreen
var page: MobilePage
var section := "Bag"
var detail := false
var filters_open := false
var party_open := false
var positions: Dictionary = {}
var compact := true
const LIST_PAGE_SIZE := 40
var list_page := 0
var list_key := ""
var _redrawing := false
var _bag_scroll: ScrollContainer


func _init(owner_: InventoryScreen) -> void:
	screen = owner_


func _key() -> String:
	return "%d:%s" % [screen.index, section]


func remember() -> void:
	if not detail and not filters_open and not party_open:
		positions[_key()] = _bag_scroll.scroll_vertical if is_instance_valid(_bag_scroll) else page.scroll.scroll_vertical


func back() -> void:
	if detail or filters_open or party_open:
		detail = false
		filters_open = false
		party_open = false
		draw()
	else:
		screen.root.call("close_screen")


func resized() -> void:
	if compact != MobileDevice.compact():
		remember()
		draw.call_deferred()


func pick() -> void:
	remember()
	detail = compact
	if compact:
		draw()
	else:
		screen.refresh_mobile_card()


func draw() -> void:
	if _redrawing or not is_instance_valid(page) or screen.is_queued_for_deletion():
		return
	_redrawing = true
	compact = MobileDevice.compact()
	if not compact:
		# Wide iPad inspection lives beside the bag, including after a portrait detail page.
		detail = false
	MobileUi.clear(page.toolbar)
	screen.reset_mobile_surface()
	_bag_scroll = null
	page.scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page.body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.mark_mobile_member_viewed()
	page.heading.text = "Inventory · %s" % screen.mobile_character().name.get_slice(" ", 0)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	page.toolbar.add_child(navigation)
	navigation.set_meta(&"pad_tabs", func(step: int) -> void:
		remember()
		var sections: Array[String] = ["Bag", "Equipment", "Stash"]
		section = sections[posmod(sections.find(section) + step, sections.size())]
		detail = false
		filters_open = false
		party_open = false
		draw())
	navigation.add_child(MobileUi.button("Party", func() -> void:
		remember()
		party_open = true
		filters_open = false
		detail = false
		draw()))
	for name_: String in ["Bag", "Equipment", "Stash"]:
		var tab := MobileUi.button(name_, func() -> void:
			remember()
			section = name_
			detail = false
			filters_open = false
			party_open = false
			draw())
		tab.name = "Mobile" + name_
		if section == name_:
			UiParts.light_up(tab)
		navigation.add_child(tab)
	if party_open:
		_party()
	elif filters_open:
		_filters()
	elif detail:
		_details(screen.mobile_body())
	else:
		var body: Container = screen.mobile_body()
		if not compact and section == "Bag":
			page.scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			var columns := HBoxContainer.new()
			columns.add_theme_constant_override("separation", 20)
			columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
			screen.mobile_body().add_child(columns)
			var list := VBoxContainer.new()
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_bag_scroll = UiParts.fill_scroll(list)
			columns.add_child(_bag_scroll)
			body = list
			var card := VBoxContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			columns.add_child(UiParts.fill_scroll(card))
			_details(card)
		match section:
			"Bag": _bag(body)
			"Equipment": _equipment(body)
			"Stash": _stash(body)
		var feedback := screen.mobile_feedback()
		if str(feedback["text"]) != "":
			body.add_child(MobileUi.text(str(feedback["text"]), str(feedback["colour"])))
		page.scroll.set_deferred("scroll_vertical", int(positions.get(_key(), 0)))
		if _bag_scroll != null:
			_bag_scroll.set_deferred("scroll_vertical", int(positions.get(_key(), 0)))
	if detail or filters_open or party_open:
		page.scroll.set_deferred("scroll_vertical", 0)
	page.reflow.call_deferred()
	_redrawing = false


func _party() -> void:
	for i in screen.st.party.size():
		var member := screen.st.party[i]
		screen.mobile_body().add_child(MobileUi.button("%s · %d / %d HP" % [member.name, member.hp, member.max_hp()], func() -> void:
			screen.select_mobile_member(i)
			party_open = false
			draw()))


func _equipment(body: Container) -> void:
	if MobileDevice.safe_rect().size.x >= 450:
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_right", 24)
		margin.add_child(screen.mobile_equipment())
		body.add_child(margin)
	else:
		# A narrow window or large interface still exposes every occupied slot without shrinking hit areas.
		for entry in screen.mobile_character().inventory:
			if str(entry.get("slot", "")) != "":
				var data := Compendium.shared().item_data(str(entry["id"]))
				body.add_child(MobileUi.button("%s · %s" % [InventoryScreen.slot_name(str(entry["slot"])),
					MagicItems.display_name(data, entry)], func() -> void: screen.select_mobile_entry(entry)))
		body.add_child(MobileUi.button("Swap weapon sets", func() -> void:
			screen.mobile_character().swap_weapon_sets()
			draw()))
		for id in screen.mobile_character().quick_slots:
			body.add_child(MobileUi.button("Quick slot · %s" % Compendium.shared().display_name("items", id),
				func() -> void: screen.select_mobile_entry(screen.mobile_character().entry_of(id))))
	body.add_child(MobileUi.text("Tap an equipped item to inspect it and change equipment. Choose an item in Bag to equip it."))


func _filters() -> void:
	screen.mobile_body().add_child(MobileUi.text("Show items"))
	var types := HFlowContainer.new()
	screen.mobile_body().add_child(types)
	for value: String in InventoryScreen.FILTERS:
		var choice := MobileUi.button(value, func() -> void:
			screen.filter = value
			filters_open = false
			draw())
		if value == screen.filter:
			UiParts.light_up(choice)
		choice.autowrap_mode = TextServer.AUTOWRAP_OFF
		types.add_child(choice)
	screen.mobile_body().add_child(MobileUi.text("Sort by"))
	for value: String in InventoryScreen.SORTS:
		screen.mobile_body().add_child(MobileUi.button(value.capitalize(), func() -> void:
			screen.sort_by = value
			filters_open = false
			draw()))
	for value: String in ["new", "junk", InventoryScreen.MARK_ATTUNED, ""]:
		screen.mobile_body().add_child(MobileUi.button("All marks" if value == "" else value.capitalize(), func() -> void:
			screen.marks = value
			filters_open = false
			draw()))
	screen.mobile_body().add_child(MobileUi.text("Rarity"))
	for rarity: String in InventoryScreen.RARITIES:
		var choice := CheckButton.new()
		choice.text = InventoryScreen.rarity_name(rarity)
		choice.custom_minimum_size.y = 48
		choice.add_theme_font_size_override("font_size", UiScale.text(18))
		choice.button_pressed = rarity in screen.rarities
		choice.toggled.connect(func(on: bool) -> void:
			if on and rarity not in screen.rarities:
				screen.rarities.append(rarity)
			elif not on:
				screen.rarities.erase(rarity))
		screen.mobile_body().add_child(choice)
	screen.mobile_body().add_child(MobileUi.button("Show filtered items", func() -> void:
		filters_open = false
		draw()))
	screen.mobile_body().add_child(MobileUi.button("Clear search and filters", func() -> void:
		screen.filter = "All"
		screen.marks = ""
		screen.search = ""
		screen.rarities.clear()
		filters_open = false
		draw()))


func _bag(body: Container) -> void:
	body.add_child(MobileUi.text("%s / %s lb · %s gp" % [InventoryScreen.display_number(screen.mobile_character().carried_weight()),
		InventoryScreen.display_number(screen.mobile_character().carrying_capacity().total()), InventoryScreen.display_number(screen.st.gold)], "gilt_light"))
	var row := HBoxContainer.new()
	body.add_child(row)
	var search := LineEdit.new()
	search.placeholder_text = "Search items"
	search.text = screen.search
	search.custom_minimum_size.y = 48
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_size_override("font_size", UiScale.text(18))
	search.clear_button_enabled = true
	search.text_changed.connect(func(value: String) -> void:
		screen.search = value
		positions[_key()] = 0
		page.scroll.scroll_vertical = 0
		if is_instance_valid(_bag_scroll):
			_bag_scroll.scroll_vertical = 0
		screen.refresh_mobile_bag())
	row.add_child(search)
	var filter_button := MobileUi.button("Filters", func() -> void:
		remember()
		filters_open = true
		draw())
	filter_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	filter_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(filter_button)
	var summary := "%s · %s" % [screen.filter, screen.sort_by.capitalize()]
	if screen.marks != "":
		summary += " · " + screen.marks.capitalize()
	for rarity: String in screen.rarities:
		summary += " · " + InventoryScreen.rarity_name(rarity)
	body.add_child(MobileUi.text(summary, "parchment"))
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	body.add_child(grid)
	var footer := VBoxContainer.new()
	body.add_child(footer)
	screen.mount_mobile_bag(grid, footer)
	screen.refresh_mobile_bag()


func _stash(body: Container) -> void:
	var allowed := screen.mobile_stash_available()
	body.add_child(MobileUi.text("Take items into %s's bag." % screen.mobile_character().name if allowed else "Items can be taken out at an inn or a home."))
	if screen.st.stash.is_empty():
		body.add_child(MobileUi.text("The stash is empty. Open an item in Bag and choose Send to the stash."))
	for entry in screen.st.stash:
		var data := Compendium.shared().item_data(str(entry["id"]))
		var take := MobileUi.button("Take %s ×%d" % [MagicItems.display_name(data, entry), int(entry.get("qty", 1))], func() -> void:
			screen.take_mobile_stash(entry)
			draw())
		UiParts.icon_on_button(take, "item", str(data.get("id", entry["id"])), 28)
		take.alignment = HORIZONTAL_ALIGNMENT_LEFT
		take.disabled = not allowed
		body.add_child(take)


func item_line(ch: Character, entry: Dictionary, data: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var shown := MagicItems.shown_data(data, entry)
	var rarity := InventoryScreen.rarity_of(shown)
	UiParts.add_framed_icon(row, "item", str(shown.get("id", entry["id"])), InventoryScreen.rarity_box(rarity), 36)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	column.add_child(MobileUi.text("%s%s" % [MagicItems.display_name(data, entry),
		" ×%d" % int(entry["qty"]) if int(entry.get("qty", 1)) > 1 else ""]))
	var marks: Array[String] = []
	for mark: String in ["new", "junk"]:
		if bool(entry.get(mark, false)):
			marks.append(mark.capitalize())
	if str(entry.get("slot", "")) != "":
		marks.append(InventoryScreen.slot_name(str(entry["slot"])))
	if str(entry["id"]) in ch.quick_slots:
		marks.append("Quick slot")
	if InventoryScreen.is_quest(data):
		marks.append("Quest")
	var tags := HFlowContainer.new()
	column.add_child(tags)
	if InventoryScreen.is_attuned(ch, entry):
		tags.add_child(UiParts.pill("Attuned", "lilac", UiScale.text(14)))
	elif ch.idle_for_attunement(entry):
		tags.add_child(UiParts.pill("Not attuned", "flame", UiScale.text(14)))
	if rarity != "":
		tags.add_child(UiParts.pill(InventoryScreen.rarity_name(rarity), ItemTile.rarity_colour(rarity, "vellum"), UiScale.text(14)))
	if MagicItems.has_charges(data):
		marks.append("%d/%d charges" % [int(entry.get("charges", 0)), MagicItems.max_charges(data, entry)])
	if not marks.is_empty():
		var note := MobileUi.text(" · ".join(marks), "parchment")
		note.add_theme_font_size_override("font_size", UiScale.text(15))
		column.add_child(note)
	var weight := UiKit.label("%s lb" % str(data.get("weight_lb", 0)), UiScale.text(15), "parchment")
	weight.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(weight)
	return row


func _details(body: Container) -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 12)
	body.add_child(card)
	screen.mount_mobile_card(card)
	screen.refresh_mobile_card()
	fit_details()


## Reuse the full item card, including field powers and spellbook actions, without its desktop widths.
func fit_details() -> void:
	if not is_instance_valid(screen) or not is_instance_valid(screen.mobile_card()):
		return
	for node in screen.mobile_card().find_children("*", "Control", true, false):
		if node.is_queued_for_deletion():
			continue
		if node is Label:
			var label := node as Label
			label.custom_minimum_size.x = 0
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if label.get_parent() is FlowContainer:
				label.autowrap_mode = TextServer.AUTOWRAP_OFF
				label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			var base := int(label.get_meta(&"mobile_base_font", clampi(label.get_theme_font_size("font_size"), 14, 24)))
			label.set_meta(&"mobile_base_font", base)
			label.add_theme_font_size_override("font_size", UiScale.text(base))
		elif node is Button:
			var control := node as Button
			control.custom_minimum_size.y = maxf(48, control.custom_minimum_size.y)
			var base := int(control.get_meta(&"mobile_base_font", maxi(17, control.get_theme_font_size("font_size"))))
			control.set_meta(&"mobile_base_font", base)
			control.add_theme_font_size_override("font_size", UiScale.text(base))
			control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if control.get_parent() is FlowContainer:
				# Wrapped text has no natural minimum width. Reserve a readable column so
				# action/recipient buttons do not collapse into tall empty strips.
				control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 180)
				control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			if control.disabled and control.tooltip_text != "" and not control.has_meta(&"mobile_reason"):
				control.set_meta(&"mobile_reason", true)
				control.text += "\n" + control.tooltip_text


## Search and sorting inspect the whole bag, while each mobile page builds at most forty interactive rows.
## Paging keeps the large inventory responsive and preserves the selected page when returning from details.
func visible_rows(rows: Array[Dictionary]) -> Array[Dictionary]:
	var key := "%s|%s|%s|%s|%s|%s" % [screen.mobile_character().id, screen.filter, screen.sort_by, screen.marks, screen.search, ",".join(screen.rarities)]
	if key != list_key:
		list_key = key
		list_page = 0
	list_page = clampi(list_page, 0, maxi(0, (rows.size() - 1) / LIST_PAGE_SIZE))
	return rows.slice(list_page * LIST_PAGE_SIZE, (list_page + 1) * LIST_PAGE_SIZE)


func paging(total: int) -> void:
	if total <= LIST_PAGE_SIZE:
		return
	screen.mobile_bag_footer().add_child(MobileUi.text("Items %d–%d of %d" % [list_page * LIST_PAGE_SIZE + 1, mini(total, (list_page + 1) * LIST_PAGE_SIZE), total]))
	var buttons := HBoxContainer.new()
	screen.mobile_bag_footer().add_child(buttons)
	var previous := MobileUi.button("Previous items", func() -> void: turn_page(-1))
	previous.disabled = list_page == 0
	buttons.add_child(previous)
	var next := MobileUi.button("Next items", func() -> void: turn_page(1))
	next.disabled = (list_page + 1) * LIST_PAGE_SIZE >= total
	buttons.add_child(next)


func turn_page(direction: int) -> void:
	list_page += direction
	screen.refresh_mobile_bag()
	page.scroll.scroll_vertical = 0
	if is_instance_valid(_bag_scroll):
		_bag_scroll.scroll_vertical = 0
	positions[_key()] = 0


## Recover from a filtered empty bag without changing items, marks or sort order.
func reset_filters() -> void:
	screen.search = ""
	screen.filter = "All"
	screen.marks = ""
	screen.rarities.clear()
	positions[_key()] = 0
	list_page = 0
	draw()
