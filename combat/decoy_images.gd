class_name DecoyImages
extends RefCounted
## Illusory decoy bodies (a trait's `decoy_image`; owned by the Encounter as `images`): a creature that is really
## somewhere else shows the fight an image of itself, which the party takes for it.
## - The image is put down beside its owner as initiative is rolled: a figure with the owner's look and its `name`
##   (the owner's when unset) and `size`, with no turn, no Hit Points that matter, no actions and no reactions. It isn't
##   a creature: nothing harms it, no condition takes, and it doesn't count for the fight's end.
## - At the start of its owner's turn the owner (the AI) sends it up to `move_ft` (60) toward the foe it wants.
## - Anything aimed at it (an attack, a spell, an area it is caught in) does nothing to it. While `while_flag` holds (or
##   always, when unset) the one who aimed it makes the `save` (Int DC 15 by default): failing, they talk themselves into
##   it, and the log tells it as a miss, a spell shrugged off or a blow that went home; succeeding, they see an image.
##   Outside that time, or once they've seen through it, it simply passes through.
## - The Study action within 30 ft and the `study` check ({skill, dc}: Investigation DC 15) unmask it for everyone, as
##   does `gone_flag` being set (a boss phase's `flag`): it fades.

const STUDY_RANGE := 30
const SEEN := "image_seen_by"   ## meta on the image: the ids of creatures that have seen through it

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


static func is_image(c: Combatant) -> bool:
	return c != null and c.has_meta("image_of")


static func spec_of(c: Combatant) -> Dictionary:
	if c == null or not c.creature is Monster:
		return {}
	for tr: Variant in (c.creature as Monster).data.get("traits", []):
		if (tr as Dictionary).has("decoy_image"):
			return (tr as Dictionary)["decoy_image"] as Dictionary
	return {}


func owner_of(img: Combatant) -> Combatant:
	return enc().get_c(str(img.get_meta("image_of", ""))) if is_image(img) else null


func spec(img: Combatant) -> Dictionary:
	return spec_of(owner_of(img))


func image_of(owner: Combatant) -> Combatant:
	for c in enc().combatants:
		if is_image(c) and str(c.get_meta("image_of")) == owner.id and c.is_alive() and not c.has_meta("left_fight"):
			return c
	return null


## Initiative rolled: each creature with a `decoy_image` puts its image down beside it.
func initiative_rolled() -> void:
	for c in enc().combatants.duplicate():
		if not spec_of(c).is_empty() and c.is_alive() and image_of(c) == null:
			_make(c)


func _make(owner: Combatant) -> Combatant:
	var e := enc()
	var sp := spec_of(owner)
	var m := owner.creature as Monster
	var data := {"id": str(m.data.get("id", "")) + "_image", "name": str(sp.get("name", owner.name())),
		"size": str(sp.get("size", "small")), "type": str(m.creature_type), "ac": 10, "hp": {"average": 1, "dice": "1"},
		"speed": {"walk": int(sp.get("move_ft", 60))}, "abilities": {"str": 1, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10},
		"condition_immunities": EchoKnight.ALL_CONDITIONS.duplicate(), "cr": 0, "xp": 0, "initiative": 0, "summon": true,
		"art": str(m.data.get("art", "")),
		"traits": [{"id": "decoy_image_body", "name": "Image", "action": "passive",
			"modifiers": [{"stat": "flag", "value": "no_opportunity_attacks"}, {"stat": "flag", "value": "no_reactions"}],
			"summary": "An illusion: it moves when its maker sends it and nothing aimed at it touches it."}],
		"actions": [], "ai_profile": "brute", "summary": "An image.", "text": "An illusion."}
	var img_m := Monster.from_data(data)
	img_m.name = str(data["name"])
	var cell := _open_beside(owner)
	if cell == Vector2i(-1, -1):
		return null
	var img := e.add(img_m, owner.side, cell)
	img.controller = owner.controller
	img.set_meta("image_of", owner.id)
	img.set_meta(SEEN, [])
	img.reaction_available = false
	e.events.append({"type": "summon_creature", "id": img.id, "cell": cell, "caster": owner.id})
	return img


func _open_beside(owner: Combatant) -> Vector2i:
	var e := enc()
	var best := Vector2i(-1, -1)
	for r in range(1, 6):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cell := owner.cell + Vector2i(dx, dz)
				if maxi(absi(dx), absi(dz)) != r or not e.grid.in_bounds(cell) or e.grid.is_solid(cell) or e.objects.blocking_at(cell) != null or e.occupant_at(cell) != null:
					continue
				return cell
	return best


## The start of `owner`'s turn (the AI's): the image goes up to its `move_ft` toward the foe the owner wants; and an
## image whose `gone_flag` is set fades.
func owner_turn(owner: Combatant) -> CombatResult:
	var e := enc()
	var img := image_of(owner)
	if img == null:
		return null
	if _gone(img):
		return null
	var t := e.ai.boss._best_target(owner)
	if t == null or e.distance(img, t) <= 5:
		return null
	var ft := int(spec(img).get("move_ft", 60))
	var cell := e.ai.boss._cell_beside(img, t, ft)
	if cell == img.cell:
		return null
	return e.legendary._move(img, cell, ft)


## Fades an image whose `gone_flag` is set (true when it did).
func _gone(img: Combatant) -> bool:
	var flag := str(spec(img).get("gone_flag", ""))
	if flag == "" or not bool(enc().legendary.story_flags.get(flag, false)):
		return false
	unmask(img, "")
	return true


## Every round: images whose time is over fade.
func check_flags() -> void:
	for c in enc().combatants.duplicate():
		if is_image(c) and c.is_alive() and not c.has_meta("left_fight"):
			_gone(c)


## The image fades for good: unmasked by a Study (`by`) or its owner's time.
func unmask(img: Combatant, by: String) -> void:
	var e := enc()
	var owner := owner_of(img)
	e.log.add("info", "%s is only an image: it fades%s" % [img.name(), (" (%s saw through it)" % by) if by != "" else ""], img.id)
	e.movement.leave_grid(img, "unmasked")
	if owner != null:
		e.events.append({"type": "image_unmasked", "id": img.id, "owner": owner.id})


## `by` aimed `what` (an attack, a spell's name) at image `img`: nothing happens to it, and what `by` makes of it.
func struck(by: Combatant, img: Combatant, what: String, kind: String) -> void:
	var e := enc()
	var sp := spec(img)
	var seen := (img.get_meta(SEEN, []) as Array).duplicate()
	var flag := str(sp.get("while_flag", ""))
	var fooling := flag == "" or bool(e.legendary.story_flags.get(flag, false))
	if by == null or by.id in seen or not fooling or by.side == img.side:
		e.log.add("info", "%s passes straight through %s" % [what, img.name()], by.id if by != null else "")
		return
	var sv := sp.get("save", {"ability": "int", "dc": 15}) as Dictionary
	var t := by.creature.roll_save(e.dice, StringName(str(sv.get("ability", "int"))), int(sv.get("dc", 15)), [], [],
		"%s save vs %s (%s)" % [str(sv.get("ability", "int")).to_upper(), img.name(), by.name()])
	if t.success:
		seen.append(by.id)
		img.set_meta(SEEN, seen)
		e.log.add("info", "%s passes through %s: %s sees it is only an image" % [what, img.name(), by.name()], by.id, [t.describe()])
		e.events.append({"type": "image_seen", "id": img.id, "by": by.id})
		return
	# Talked into it: the log tells what they believe happened.
	var lines: Array[String] = ["%s misses %s" % [what, img.name()]]
	if kind == "spell":
		lines = ["%s shrugs off %s" % [img.name(), what]]
	lines.append("%s strikes %s... it passes through, or did it?" % [what, img.name()])
	var pick := lines[e.dice.roll_one(lines.size(), "What they believe") - 1]
	e.log.add("info", pick, by.id, [t.describe()])


# --- Study ---------------------------------------------------------------------------------------------------------

func study_why(c: Combatant, img: Combatant) -> String:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return why
	if not is_image(img) or not img.is_alive() or img.has_meta("left_fight") or not c.hostile_to(img):
		return "Nothing to study there"
	if spec(img).get("study", {}).is_empty():
		return "Nothing to learn"
	if e.distance(c, img) > STUDY_RANGE:
		return "Too far to study: within 30 ft"
	return ""


## The Study action on what looks like a creature: the `study` check unmasks an image.
func study(c: Combatant, img: Combatant) -> CombatResult:
	var e := enc()
	var why := study_why(c, img)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	var st := spec(img)["study"] as Dictionary
	var t := c.creature.roll_check(e.dice, StringName(str(st.get("skill", "investigation"))), int(st.get("dc", 15)), [], [],
		"Study %s (%s)" % [img.name(), c.name()], ["study"])
	if not t.success:
		e.log.add("info", "%s studies %s and sees nothing amiss" % [c.name(), img.name()], c.id, [t.describe()])
		return CombatResult.new()
	e.log.add("info", "%s studies %s: no shadow, no breath" % [c.name(), img.name()], c.id, [t.describe()])
	unmask(img, c.name())
	return CombatResult.new()


## The Study line on the Common tab for each image within 30 ft.
func entries(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := enc()
	if not c.creature is Character:
		return out
	for img in e.combatants:
		if not is_image(img) or not img.is_alive() or img.has_meta("left_fight") or spec(img).get("study", {}).is_empty():
			continue
		if e.distance(c, img) > STUDY_RANGE:
			continue
		var st := spec(img)["study"] as Dictionary
		out.append({"id": "study_image:" + img.id, "tab": ActionCatalog.COMMON, "label": "Study %s" % img.name(),
			"sub": "%s DC %d" % [str(st.get("skill", "investigation")).capitalize(), int(st.get("dc", 15))], "cost": "action",
			"legal": study_why(c, img) == "", "reason": study_why(c, img), "targeting": "none", "count": 1, "repeat": false,
			"range": STUDY_RANGE, "spell_id": "", "slot": 0, "option_id": "", "kind": "object",
			"help": "The Study action: look hard at it for what doesn't fit."})
	return out
