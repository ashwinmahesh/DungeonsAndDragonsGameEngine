class_name CheckAidPrompt
extends CanvasLayer
## What can still be spent on a skill check that failed outside a fight and outside a conversation (CheckAids): "Ilse rolled 9
## on Arcana against DC 40", a line for each aid she could spend (Heroic Inspiration's new d20, Tactical Mind, Dark One's Own
## Luck), or a way to let it stand. The check's failure (its line, what it costs, the fight it sets off) waits for the answer,
## so an aid that turns the roll round doesn't run on top of it. The mouse, the keys (1-9 pick; Esc lets it stand) and the pad
## (A picks, B lets it stand) all answer it. It sits over the place, shown once the big d20 has gone, until it's answered.

## The aid picked (CheckAids' `id`), or "" for letting the failure stand.
signal answered(aid: String)

## Level with the Guidance and follow prompts: over a conversation (20), under the loading card (40).
const LAYER := 34
const WIDTH := 660.0

## {who: Character, skill: String ("Arcana"), dc: int, test: D20Test (the failed roll), options: Array[Dictionary] (CheckAids.options)}.
var offer: Dictionary = {}
## The aids' buttons, in the offer's order.
var choices: Array[Button] = []
var stand_button: Button
var _done := false


## Shows the prompt for `o` over `host`; `then(aid)` runs once it's answered.
static func ask(host: Node, o: Dictionary, then: Callable) -> CheckAidPrompt:
	var p := CheckAidPrompt.new()
	p.offer = o
	p.answered.connect(then, CONNECT_ONE_SHOT)
	host.add_child(p)
	return p


func _init() -> void:
	name = "CheckAidPrompt"
	layer = LAYER


func _ready() -> void:
	var options := offer["options"] as Array
	var who := offer["who"] as Character
	var box := UiKit.screen_frame(self, "Spend something on it?", Vector2(WIDTH, 210.0 + 66.0 * options.size()))
	_rename_escape()
	box.add_child(UiKit.label("%s rolled %d on %s against DC %d, and missed." % [who.name.get_slice(" ", 0), (offer["test"] as D20Test).total,
		str(offer["skill"]), int(offer["dc"])], 19, "vellum", WIDTH - 72.0))
	box.add_child(UiKit.label("Nothing has happened yet. Spend one and the roll is made again; let it stand and the failure follows.",
		15, "parchment", WIDTH - 72.0))
	for i in options.size():
		var o := options[i] as Dictionary
		var id := str(o["id"])
		var b := UiKit.button("%d. %s" % [i + 1, str(o["label"])], func() -> void: _answer(id), 17)
		b.name = "Aid_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i == 0:
			b.set_meta(&"pad_first", true)
		box.add_child(b)
		choices.append(b)
	stand_button = UiKit.button("%d. Let it stand" % (options.size() + 1), func() -> void: _answer(""), 17)
	stand_button.name = "LetItStand"
	stand_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(stand_button)
	# The big d20 for the roll is still on its way down; the question comes after it.
	if DiceRoll.showing() != null:
		visible = false
		set_process(true)
	else:
		set_process(false)
		_focus_first.call_deferred()


func _process(_delta: float) -> void:
	if DiceRoll.showing() == null:
		set_process(false)
		visible = true
		_focus_first()


func _focus_first() -> void:
	if _done:
		return
	if not choices.is_empty():
		choices[0].grab_focus()
	else:
		stand_button.grab_focus()


## The frame's note under its border says what Escape does here.
func _rename_escape() -> void:
	for l: Node in find_children("*", "Label", true, false):
		if (l as Label).text in ["Esc: close", PadGlyphs.words("Esc: close", "{b}: close")]:
			PadGlyphs.hint(l, "Esc: let it stand", "{b}: let it stand")


## Answers once, then the prompt goes.
func _answer(aid: String) -> void:
	if _done:
		return
	_done = true
	answered.emit(aid)
	UiMotion.dismiss(self)


## Whether it's still waiting for an answer.
func open() -> bool:
	return not _done


func _unhandled_input(event: InputEvent) -> void:
	if _done or not visible:
		return
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		_answer("")
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
		var at := int(k.physical_keycode - KEY_1)
		if at <= choices.size():
			get_viewport().set_input_as_handled()
			_answer(str((offer["options"] as Array)[at]["id"]) if at < choices.size() else "")
			return
	# Nothing behind it moves while it's up.
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
