class_name BattleObject
extends RefCounted
## Something on the battlefield that can be attacked and broken (2024 rules glossary, Breaking Objects): a door, a
## crate, a pew, a gravestone, the chain a chandelier hangs from, the webbing holding a giant spider's prey. Its Armor
## Class comes from what it's made of and its Hit Points from its size and sturdiness (data/objects/kinds.json); like
## every object it takes no Poison or Psychic damage and fails every saving throw. At 0 Hit Points it breaks, leaving
## open floor, an open doorway or Difficult Terrain rubble. Not a FieldObject (a spell's zone or object): the
## Encounter's EncounterObjects owns these, and the scene draws them from `kind` and `cells` (world/combat/object_view.gd).

var id: String = ""
## Its kind in data/objects/kinds.json ("door_wood", "crate", "chandelier", "spider_web" ...).
var kind: String = ""
## What it's called: the kind's name ("crate"), or a location door's or prop's own label ("the den door").
var name: String = ""
var cells: Array[Vector2i] = []
var substance: String = ""
var size: String = "medium"
var resilient: bool = true
var ac: int = 15
var hp: int = 18
var hp_max: int = 18
## The grid flag it puts on its squares while it stands: CombatGrid.WALL (a door), CombatGrid.LOW (furniture, a
## crate), or 0 (it hangs overhead, or it's a web around a creature).
var blocks: int = 0
var flammable: bool = false
## The Burning condition (2024 rules glossary): 1d4 Fire damage each round until it breaks.
var burning: bool = false
## What its squares become when it breaks: "floor", "rubble" (Difficult Terrain) or "doorway".
var leaves: String = "floor"
var immune: Array[String] = []
var resist: Array[String] = []
var vulnerable: Array[String] = []
## The location door or prop it is (BattleScenery puts things right after the fight; the view hides their art).
var door_id: String = ""
var prop_id: String = ""
## The board art standing on its square (the view hides it when it breaks).
var art: String = ""
## A chandelier: it hangs over its squares and falls on whoever is below when its chain breaks ({save, dc, damage,
## type, prone}, plus a location prop's `trap` or `flag`).
var fall: Dictionary = {}
var hangs: bool = false
## A giant spider's web: the creature it holds, and the source of the effect restraining it.
var holds: String = ""
var hold_source: String = ""
## Covered in oil (2024 Oil): rounds before it dries; the next Fire damage it takes is 5 more.
var oil_rounds: int = 0
var destroyed: bool = false
## A door: it stands open (its squares no wall while it does), or it's locked (it can't be opened in a fight).
var open: bool = false
var locked: bool = false
## What a creature beside it can do to it (ObjectActions): "shove" (5 ft), "topple" (push it over) or "", and the
## Strength (Athletics) DC for it; how it falls when pushed over ({dc, damage, type, length, coals}).
var moves: String = ""
var move_dc: int = 10
var topple: Dictionary = {}
## Small enough to throw as an improvised weapon.
var throwable: bool = false
## Fire sets it off (a barrel of lamp oil): {radius, save, dc, damage, type, oil} (ObjectFire.burst).
var bursts: Dictionary = {}
## Where its wreckage lies when that isn't its own squares: the squares it fell across, the spot it was flung at.
var wreck: Array[Vector2i] = []
## The square it stood on when the fight began, when a shove has moved it since (BattleScenery puts it right after).
var home: Vector2i = Vector2i(-1, -1)
## Put down by the fight itself (an encounter's `objects`, BattleScenery.for_spec), not standing on the board before it:
## the props catalog model the scene draws it with (ObjectView), "" for none.
var model: String = ""
## What a creature with `devours` eats (ObjectFuel): a word the stat block and the encounter share ("" for nothing).
var fuel: String = ""
## The creature that comes out when it breaks or is eaten (ObjectFuel.release): {monster, name, art, hp ("half" or a
## number), side, minion_of}; {} for none.
var releases: Dictionary = {}
## Damage Threshold (2024 DMG): damage less than this from one source does nothing to it (a captive's chains).
var threshold: int = 0
## A check that takes it off or apart without breaking it by force (ObjectActions.undo): {skill, dc, label}, as the
## Utilize action by a creature within 5 ft; {} for none.
var undo: Dictionary = {}
## The story flag set when it is gone, broken or undone ("" for none).
var flag: String = ""
## A plain thing a hero can carry (ObjectCarry): {tag}; {} for none. Such a thing can't be attacked.
var carry: Dictionary = {}
## The creature carrying it ("" when it lies on the floor).
var carried_by: String = ""
## A thing a monster holds that heroes can strike (HeldObjects): its trait's `held_object` data.
var held_target: bool = false
var held: Dictionary = {}
## What it takes in (ObjectCarry.put): {tag, label, flag, say, damage, light}; {} for nothing.
var takes: Dictionary = {}
## Done with: something was put in it, and its hazard is over.
var cleansed: bool = false
## Its hazards (ObjectCarry.hazards): [{on, near_ft, save, exhaustion, damage, if_flag, unless_flag}].
var hazard: Array = []
## Creature id -> the turn ("round:index") a hazard of it last struck that creature (once a turn).
var hazard_hit: Dictionary = {}
## The warding light lit round it once cleansed: {radius, disadvantage, color}; {} for none.
var ward: Dictionary = {}
## The Study that tells what it is: {skills, dc, say, flag}; {} for none.
var study: Dictionary = {}
## A hero's willing death beside it (LastAct): {label, target, effect, flag, say}.
var last_act: Dictionary = {}
var studied: bool = false


## A new object of `kind_id` from the kinds table (data/objects/kinds.json).
static func make(kind_id: String, table: Dictionary) -> BattleObject:
	var o := BattleObject.new()
	var k := (table.get("kinds", {}) as Dictionary).get(kind_id, {}) as Dictionary
	o.kind = kind_id
	o.name = str(k.get("name", kind_id))
	o.substance = str(k.get("substance", ""))
	o.size = str(k.get("size", "medium"))
	o.resilient = str(k.get("resilience", "resilient")) == "resilient"
	o.ac = int(k.get("ac", (table.get("substances", {}) as Dictionary).get(o.substance, 15)))
	var hps := (table.get("hit_points", {}) as Dictionary).get(o.size, {}) as Dictionary
	o.hp_max = int(k.get("hp", hps.get("resilient" if o.resilient else "fragile", 10)))
	o.hp = o.hp_max
	o.blocks = {"wall": CombatGrid.WALL, "low": CombatGrid.LOW}.get(str(k.get("blocks", "none")), 0) as int
	o.flammable = bool(k.get("flammable", false))
	o.leaves = str(k.get("leaves", "floor"))
	o.hangs = bool(k.get("hangs", false))
	o.fall = (k.get("fall", {}) as Dictionary).duplicate()
	o.moves = str(k.get("moves", ""))
	o.move_dc = int(k.get("move_dc", 10))
	o.topple = (k.get("topple", {}) as Dictionary).duplicate()
	o.throwable = bool(k.get("throwable", false))
	o.bursts = (k.get("bursts", {}) as Dictionary).duplicate()
	o.immune.assign(["poison", "psychic"])
	for ty: Variant in k.get("immune", []):
		if not str(ty) in o.immune:
			o.immune.append(str(ty))
	o.resist.assign((k.get("resist", []) as Array).map(func(x: Variant) -> String: return str(x)))
	o.vulnerable.assign((k.get("vulnerable", []) as Array).map(func(x: Variant) -> String: return str(x)))
	return o


## "the crate", or a label that already says which ("the den door", "a carved crest").
func the() -> String:
	for lead: String in ["the ", "a ", "an "]:
		if name.to_lower().begins_with(lead):
			return name
	return "the " + name


## "The crate".
func title() -> String:
	var t := the()
	return t.substr(0, 1).to_upper() + t.substr(1)


func live() -> bool:
	return not destroyed


## A door (its kind leaves a doorway when it breaks).
func is_door() -> bool:
	return leaves == "doorway"


## "AC 15 · HP 4/4", then what's happening to it.
func describe() -> Array[String]:
	var out: Array[String] = ["AC %d · HP %d/%d" % [ac, hp, hp_max]]
	if is_door():
		out.append("Open" if open else ("Locked" if locked else "Shut"))
	if not bursts.is_empty():
		out.append("Bursts into flame if fire reaches it")
	if moves == "shove":
		out.append("Can be shoved (Athletics DC %d)" % move_dc)
	elif moves == "topple":
		out.append("Can be pushed over (Athletics DC %d)" % move_dc)
	if burning:
		out.append("Burning: 1d4 Fire each round")
	if oil_rounds > 0:
		out.append("Covered in oil")
	if hangs:
		out.append("Hangs overhead: only ranged attacks and spells reach its chain")
	if not vulnerable.is_empty():
		out.append("Vulnerable to %s" % ", ".join(vulnerable.map(func(x: String) -> String: return x.capitalize())))
	if not releases.is_empty():
		out.append("Breaking it lets out %s" % str(releases.get("name", "what it holds")))
	return out


func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "name": name, "cells": cells.map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"substance": substance, "size": size, "resilient": resilient, "ac": ac, "hp": hp, "hp_max": hp_max, "blocks": blocks,
		"flammable": flammable, "burning": burning, "leaves": leaves, "immune": immune.duplicate(), "resist": resist.duplicate(),
		"vulnerable": vulnerable.duplicate(), "door_id": door_id, "prop_id": prop_id, "art": art, "fall": fall.duplicate(true),
		"hangs": hangs, "holds": holds, "hold_source": hold_source, "oil_rounds": oil_rounds, "destroyed": destroyed,
		"open": open, "locked": locked, "moves": moves, "move_dc": move_dc, "topple": topple.duplicate(true), "throwable": throwable,
		"bursts": bursts.duplicate(true), "wreck": wreck.map(func(c: Vector2i) -> Array: return [c.x, c.y]), "home": [home.x, home.y],
		"model": model, "fuel": fuel, "releases": releases.duplicate(true),
		"threshold": threshold, "undo": undo.duplicate(true), "flag": flag,
		"carry": carry.duplicate(true), "carried_by": carried_by, "takes": takes.duplicate(true), "cleansed": cleansed,
		"hazard": hazard.duplicate(true), "hazard_hit": hazard_hit.duplicate(), "ward": ward.duplicate(true),
		"study": study.duplicate(true), "studied": studied, "held_target": held_target, "held": held.duplicate(true),
		"last_act": last_act.duplicate(true)}


static func from_dict(d: Dictionary) -> BattleObject:
	var o := BattleObject.new()
	o.id = str(d.get("id", ""))
	o.kind = str(d.get("kind", ""))
	o.name = str(d.get("name", ""))
	for c: Variant in d.get("cells", []):
		o.cells.append(Vector2i(int((c as Array)[0]), int((c as Array)[1])))
	o.substance = str(d.get("substance", ""))
	o.size = str(d.get("size", "medium"))
	o.resilient = bool(d.get("resilient", true))
	o.ac = int(d.get("ac", 15))
	o.hp = int(d.get("hp", 1))
	o.hp_max = int(d.get("hp_max", o.hp))
	o.blocks = int(d.get("blocks", 0))
	o.flammable = bool(d.get("flammable", false))
	o.burning = bool(d.get("burning", false))
	o.leaves = str(d.get("leaves", "floor"))
	o.immune.assign((d.get("immune", ["poison", "psychic"]) as Array).map(func(x: Variant) -> String: return str(x)))
	o.resist.assign((d.get("resist", []) as Array).map(func(x: Variant) -> String: return str(x)))
	o.vulnerable.assign((d.get("vulnerable", []) as Array).map(func(x: Variant) -> String: return str(x)))
	o.door_id = str(d.get("door_id", ""))
	o.prop_id = str(d.get("prop_id", ""))
	o.art = str(d.get("art", ""))
	o.fall = (d.get("fall", {}) as Dictionary).duplicate(true)
	o.hangs = bool(d.get("hangs", false))
	o.holds = str(d.get("holds", ""))
	o.hold_source = str(d.get("hold_source", ""))
	o.oil_rounds = int(d.get("oil_rounds", 0))
	o.destroyed = bool(d.get("destroyed", false))
	o.open = bool(d.get("open", false))
	o.locked = bool(d.get("locked", false))
	o.moves = str(d.get("moves", ""))
	o.move_dc = int(d.get("move_dc", 10))
	o.topple = (d.get("topple", {}) as Dictionary).duplicate(true)
	o.throwable = bool(d.get("throwable", false))
	o.bursts = (d.get("bursts", {}) as Dictionary).duplicate(true)
	o.threshold = int(d.get("threshold", 0))
	o.undo = (d.get("undo", {}) as Dictionary).duplicate(true)
	o.flag = str(d.get("flag", ""))
	o.carry = (d.get("carry", {}) as Dictionary).duplicate(true)
	o.carried_by = str(d.get("carried_by", ""))
	o.held_target = bool(d.get("held_target", false))
	o.held = (d.get("held", {}) as Dictionary).duplicate(true)
	o.takes = (d.get("takes", {}) as Dictionary).duplicate(true)
	o.cleansed = bool(d.get("cleansed", false))
	o.hazard = (d.get("hazard", []) as Array).duplicate(true)
	o.hazard_hit = (d.get("hazard_hit", {}) as Dictionary).duplicate()
	o.ward = (d.get("ward", {}) as Dictionary).duplicate(true)
	o.study = (d.get("study", {}) as Dictionary).duplicate(true)
	o.last_act = (d.get("last_act", {}) as Dictionary).duplicate(true)
	o.studied = bool(d.get("studied", false))
	for c2: Variant in d.get("wreck", []):
		o.wreck.append(Vector2i(int((c2 as Array)[0]), int((c2 as Array)[1])))
	var h := d.get("home", [-1, -1]) as Array
	o.home = Vector2i(int(h[0]), int(h[1]))
	o.model = str(d.get("model", ""))
	o.fuel = str(d.get("fuel", ""))
	o.releases = (d.get("releases", {}) as Dictionary).duplicate(true)
	return o
