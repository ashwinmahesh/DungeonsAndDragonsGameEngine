class_name MobilePage
extends PanelContainer
## A safe-area page with a permanent Back control and a scrolling body. Existing wide details remain scrollable
## while individual screens reflow their primary columns; the title and Back never scroll out of reach.

## Opt-in bounded combat sheet. Other mobile pages retain their full safe-area layout.
var side_sheet := false
## Optional left/right art gutters, used by mobile conversations only.
var side_gutters := Vector2.ZERO
## Optional bottom conversation panel; zero keeps the normal page.
var bottom_height := 0.0
var centered_width := 0.0
var centered_height := 0.0
var body: VBoxContainer
var scroll: ScrollContainer
var heading: Label
var toolbar: VBoxContainer
var back_action: Callable
var keyboard_done: Button
var _keyboard_height := 0.0
var controller_hint: Label
## Only opaque full pages may stop 3D drawing. Partial sheets retain their view of the world.
const WORLD_HOLDS := &"mobile_page_world_holds"
var _covers_world := false
var _backdrop: ColorRect
var _held_viewport: Viewport


static func build(layer: CanvasLayer, title: String, close: Callable = cancel, covers_world: bool = false) -> VBoxContainer:
	layer.set_meta(&"pad_scope", true)
	var dim := ColorRect.new()
	dim.color = Color(Look.color("void"), 1.0 if covers_world else 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var page := MobilePage.new()
	page._covers_world = covers_world
	page._backdrop = dim
	page.back_action = close
	page.set_meta(&"pad_scope", true)
	page.add_theme_stylebox_override("panel", UiKit.style())
	layer.add_child(page)
	var column := VBoxContainer.new()
	page.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var back := UiKit.button("Back", func() -> void: page.back_action.call())
	back.name = "MobileBack"
	bar.add_child(back)
	page.heading = UiKit.title(title)
	page.heading.add_theme_font_size_override("font_size", UiScale.text(24))
	page.heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.heading.clip_text = true
	page.heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(page.heading)
	page.keyboard_done = MobileUi.button("Done", func() -> void:
		var focus := page.get_viewport().gui_get_focus_owner()
		if focus != null:
			focus.release_focus()
		DisplayServer.virtual_keyboard_hide())
	page.keyboard_done.size_flags_horizontal = Control.SIZE_SHRINK_END
	page.keyboard_done.autowrap_mode = TextServer.AUTOWRAP_OFF
	page.keyboard_done.hide()
	bar.add_child(page.keyboard_done)
	page.toolbar = VBoxContainer.new()
	column.add_child(page.toolbar)
	page.scroll = ScrollContainer.new()
	page.scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(page.scroll)
	page.body = VBoxContainer.new()
	page.body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.body.add_theme_constant_override("separation", 6)
	page.scroll.add_child(page.body)
	page.controller_hint = UiKit.label("", 14, "parchment")
	page.controller_hint.clip_text = true
	page.controller_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	page.controller_hint.hide()
	column.add_child(page.controller_hint)
	page.reflow()
	return page.body


static func cancel() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		event.set_meta(&"touch_synthetic", true)
		tree.root.push_input(event)


func _ready() -> void:
	visibility_changed.connect(_sync_world_rendering)
	if _covers_world:
		(get_parent() as CanvasLayer).visibility_changed.connect(_sync_world_rendering)
		_backdrop.visibility_changed.connect(_sync_world_rendering)
		_sync_world_rendering()
	get_viewport().size_changed.connect(reflow)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	if MobileDevice.current != null:
		MobileDevice.current.geometry_changed.connect(_geometry_changed)
	if UiFeel.touch != null:
		UiFeel.touch.cancel()


## A screen can install a real navigation callback; the compatibility fallback remains for older pages.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and back_action != cancel and is_visible_in_tree():
		back_action.call()
		get_viewport().set_input_as_handled()


func reflow() -> void:
	var rect := MobileDevice.safe_rect().grow(-4)
	_keyboard_height = MobileDevice.keyboard_height()
	if _keyboard_height > 0:
		rect.size.y = maxf(96.0, minf(rect.end.y, MobileDevice.logical_size().y - _keyboard_height) - rect.position.y)
	if keyboard_done != null:
		keyboard_done.visible = _keyboard_height > 0
	if side_gutters != Vector2.ZERO:
		rect.position.x += side_gutters.x
		rect.size.x -= side_gutters.x + side_gutters.y
	if side_sheet and rect.size.x >= 700 and UiScale.text(18) <= 22:
		var width := minf(520.0, rect.size.x * 0.60)
		rect.position.x = rect.end.x - width
		rect.size.x = width
	if centered_width > 0:
		var width := minf(centered_width, rect.size.x)
		rect.position.x += (rect.size.x - width) / 2.0
		rect.size.x = width
	if centered_height > 0:
		var height := minf(centered_height, rect.size.y)
		rect.position.y += (rect.size.y - height) / 2.0
		rect.size.y = height
	if bottom_height > 0:
		var height := minf(bottom_height, rect.size.y)
		rect.position.y = rect.end.y - height
		rect.size.y = height
	position = rect.position
	size = rect.size
	custom_minimum_size = Vector2.ZERO
	if scroll != null:
		scroll.custom_minimum_size = Vector2.ZERO


func _process(_delta: float) -> void:
	_sync_world_rendering()
	if not is_visible_in_tree():
		return
	if controller_hint != null:
		var nav := PadNav.current
		var scope := nav.scope_now() if PadNav.active() else null
		controller_hint.visible = scope != null and (PadNav.inside(self, scope) or PadNav.inside(scope, self))
		if controller_hint.visible:
			var hints: Array[String] = []
			for prompt: Array in PadPrompts.prompts_for(scope, nav.focus_in(scope)):
				var buttons: Array[String] = []
				for place in str(prompt[0]).split("+"):
					buttons.append(PadGlyphs.names("{%s}" % place))
				hints.append("%s: %s" % ["/".join(buttons), str(prompt[1])])
			if PadNav.scroller(scope) != null:
				hints.append("Right stick: Scroll")
			controller_hint.text = " · ".join(hints)


func _geometry_changed() -> void:
	reflow()
	_keep_input_visible.call_deferred()


func _focus_changed(control: Control) -> void:
	if control is LineEdit and body != null and body.is_ancestor_of(control):
		var input := control as LineEdit
		if not input.text_changed.is_connected(_text_changed):
			input.text_changed.connect(_text_changed)
		_keep_input_visible.call_deferred()


func _text_changed(_value: String) -> void:
	_keep_input_visible.call_deferred()


## Filtering often rebuilds rows and resets scrolling. Keep the active field visible after that layout settles.
func _keep_input_visible() -> void:
	if _keyboard_height <= 0 or body == null:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not body.is_ancestor_of(focus):
		return
	var ancestor := focus.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(focus)
		ancestor = ancestor.get_parent()


## Ownership is per viewport, so nested pages and sheets close in either order without revealing a
## black world. Restore the previous setting, including a viewport already intentionally disabled.
func _sync_world_rendering() -> void:
	if not _covers_world:
		return
	var layer := get_parent() as CanvasLayer
	var covered := MobileDevice.enabled() and is_inside_tree() and not is_queued_for_deletion() and is_visible_in_tree() \
		and layer != null and layer.visible and is_instance_valid(_backdrop) and _backdrop.is_visible_in_tree() \
		and _backdrop.color.a >= 1.0
	if not covered:
		_release_world_rendering()
		return
	var vp := get_viewport()
	if _held_viewport == vp:
		return
	_release_world_rendering()
	var held := vp.get_meta(WORLD_HOLDS, {}) as Dictionary
	if held.is_empty():
		held = {"previous": vp.disable_3d, "owners": {}}
	(held["owners"] as Dictionary)[get_instance_id()] = true
	vp.set_meta(WORLD_HOLDS, held)
	vp.disable_3d = true
	_held_viewport = vp


func _release_world_rendering() -> void:
	if not is_instance_valid(_held_viewport):
		_held_viewport = null
		return
	var held := _held_viewport.get_meta(WORLD_HOLDS, {}) as Dictionary
	if not held.is_empty():
		(held["owners"] as Dictionary).erase(get_instance_id())
		if (held["owners"] as Dictionary).is_empty():
			_held_viewport.disable_3d = bool(held["previous"])
			_held_viewport.remove_meta(WORLD_HOLDS)
	_held_viewport = null


func _exit_tree() -> void:
	_release_world_rendering()
