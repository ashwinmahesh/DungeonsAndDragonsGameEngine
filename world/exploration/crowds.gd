class_name Crowds
extends Node
## Crowds (a location area's `crowd`: {count, sprites, push_to, push_every, when}): bystander figures that aren't NPCs
## (no talk, no turn, no square of their own: they never block) milling about inside the area, a square at a time.
## While the party's leader stands in the area and the party isn't busy, every `push_every` seconds (4) the crowd
## jostles it one square toward `push_to` (dancers sweeping the heroes to the middle of the square). `sprites` are the
## figures' art (stand-ins until a place has its own); `when` a story condition. One per LocationView.

const STEP_TIME := 1.2
const PUSH_EVERY := 4.0

var view: LocationView
## [{area, spec, cells: Array[Vector2i], figures: [{token, cell}], clock, push_clock}]
var crowds: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


static func create(v: LocationView) -> Crowds:
	var c := Crowds.new()
	c.name = "Crowds"
	c.view = v
	c._rng.seed = hash(v.loc_id)
	c._build()
	return c


## The open squares of a rectangle area (corners inclusive) on `grid`.
static func area_cells(grid: CombatGrid, corners: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c0 := Vector2i(int((corners[0] as Array)[0]), int((corners[0] as Array)[1]))
	var c1 := Vector2i(int((corners[1] as Array)[0]), int((corners[1] as Array)[1]))
	for z in range(mini(c0.y, c1.y), maxi(c0.y, c1.y) + 1):
		for x in range(mini(c0.x, c1.x), maxi(c0.x, c1.x) + 1):
			var cell := Vector2i(x, z)
			if grid.in_bounds(cell) and not grid.is_solid(cell):
				out.append(cell)
	return out


## The square one step from `from` toward `to` that `grid` lets a walker into, or `from` when there's none.
static func push_step(grid: CombatGrid, from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return from
	var d := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	for step: Vector2i in [d, Vector2i(d.x, 0), Vector2i(0, d.y)]:
		if step == Vector2i.ZERO:
			continue
		var cell := from + step
		if grid.in_bounds(cell) and not grid.is_solid(cell):
			return cell
	return from


func _build() -> void:
	for a: Variant in view.loc.get("areas", []):
		var ad := a as Dictionary
		var spec := ad.get("crowd", {}) as Dictionary
		if spec.is_empty() or not StoryConditions.check(str(spec.get("when", "")), view.st):
			continue
		var cells := area_cells(view.grid, ad["cells"] as Array)
		if cells.is_empty():
			continue
		var figures: Array[Dictionary] = []
		var sprites := spec.get("sprites", ["villager"]) as Array
		for i in int(spec.get("count", 6)):
			var cell := cells[_rng.randi_range(0, cells.size() - 1)]
			var m := Monster.from_data({"id": "crowd_%s_%d" % [ad["id"], i], "name": str(spec.get("name", "Reveller")), "size": "medium",
				"type": "humanoid", "hp": {"average": 1, "dice": "1"}, "ac": 10, "speed": {"walk": 30}, "actions": []})
			var cb := Combatant.new(m, &"neutral", cell)
			var tok := CombatToken.create(cb, str(sprites[i % sprites.size()]))
			tok.position = view.board.cell_center(cell) if view.board != null else Vector3.ZERO
			view.add_child.call_deferred(tok)
			figures.append({"token": tok, "cell": cell})
		crowds.append({"area": str(ad["id"]), "spec": spec, "cells": cells, "figures": figures, "clock": 0.0, "push_clock": 0.0})


func _process(delta: float) -> void:
	if view == null or view.in_combat or view.members.is_empty():
		return
	for cr in crowds:
		cr["clock"] = float(cr["clock"]) + delta
		if float(cr["clock"]) >= STEP_TIME:
			cr["clock"] = 0.0
			_mill(cr)
		_jostle(cr, delta)


## Each figure takes a step to a neighbouring square of the area, or stands.
func _mill(cr: Dictionary) -> void:
	var cells := cr["cells"] as Array[Vector2i]
	for f: Dictionary in cr["figures"]:
		var at := f["cell"] as Vector2i
		var to := at + Vector2i(_rng.randi_range(-1, 1), _rng.randi_range(-1, 1))
		if to == at or not to in cells:
			continue
		f["cell"] = to
		var tok := f["token"] as CombatToken
		if is_instance_valid(tok) and view.board != null:
			tok.face(Vector2(to - at), false)
			tok.position = view.board.cell_center(to)


## The leader in the area: every `push_every` seconds the party is walked a square toward `push_to`.
func _jostle(cr: Dictionary, delta: float) -> void:
	var spec := cr["spec"] as Dictionary
	if not spec.has("push_to") or view.busy:
		return
	var leader := view.leader()
	if leader == null or not leader.cell in (cr["cells"] as Array[Vector2i]):
		cr["push_clock"] = 0.0
		return
	cr["push_clock"] = float(cr["push_clock"]) + delta
	if float(cr["push_clock"]) < float(spec.get("push_every", PUSH_EVERY)):
		return
	cr["push_clock"] = 0.0
	var to := LocationView._cell(spec["push_to"])
	var step := push_step(view.grid, leader.cell, to)
	if step != leader.cell:
		view.toast.emit("The crowd jostles you along")
		view.walk_to(step)
