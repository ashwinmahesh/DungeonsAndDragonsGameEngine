class_name TraitOffers
extends RefCounted
## Actions a monster's trait offers everyone else in the fight (docs/reference/contracts/monsters.md "Offered
## actions"): a trait's `offers` block puts an action on the hotbar of every other creature near the holder, such as a
## step of a dance the monster can't bear to watch. The user makes an ability check; on a success the holder takes the
## block's damage and its riders (MonsterActions riders, with the user as their source). The view hears an `ability`
## event with the block's key whether the check succeeds or not.
##
## `offers`: {key (the event's key; the trait's id when missing), label (the trait's name), cost (action or bonus;
## action), range (feet from the holder; 60), check: {skill, dc}, damage: [{amount or dice, type}], on_success: [riders]}
## A contest instead of a set DC (`contest: {save}`): the check's total is the DC of the holder's save, and the damage and
## riders land when the holder fails it. `needs` (a tool kind, such as musical_instrument): the user must carry one, and
## has Advantage when proficient with the one they play. `influence: true` files it under the Influence action.

const DEFAULT_RANGE := 60

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## The offers on `holder`'s stat block: [{trait, offer}] for each trait with an `offers` block.
static func offers_of(holder: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in MonsterActions.data_of(holder).get("traits", []):
		var tr := raw as Dictionary
		if tr.get("offers", null) is Dictionary:
			out.append({"trait": tr, "offer": tr["offers"] as Dictionary})
	return out


## The key of the `ability` event an offer sends: its own, else its trait's id.
static func key_of(tr: Dictionary, offer: Dictionary) -> String:
	return str(offer.get("key", tr.get("id", "")))


static func label_of(tr: Dictionary, offer: Dictionary) -> String:
	return str(offer.get("label", tr.get("name", tr.get("id", ""))))


static func cost_of(offer: Dictionary) -> String:
	return "bonus" if str(offer.get("cost", "action")) == "bonus" else "action"


## The hotbar's entries for `c`: one per offer of each other living creature on the board, with id
## "offer:<holder id>:<trait id>", label, sub, cost, why (blank when it can be taken now) and help.
func entries(c: Combatant) -> Array[Dictionary]:
	var e := enc()
	var out: Array[Dictionary] = []
	for holder in e.combatants:
		if holder == c or not holder.is_alive() or holder.has_meta("left_fight"):
			continue
		for o in offers_of(holder):
			var tr := o["trait"] as Dictionary
			var offer := o["offer"] as Dictionary
			var check := offer.get("check", {}) as Dictionary
			var skill := str(check.get("skill", "performance")).capitalize()
			var contest := offer.get("contest", null) is Dictionary
			out.append({"id": "offer:%s:%s" % [holder.id, str(tr.get("id", ""))],
				"label": "%s%s (%s)" % ["Influence: " if bool(offer.get("influence", false)) else "", label_of(tr, offer), holder.name()],
				"sub": ("%s vs its %s save" % [skill, str((offer["contest"] as Dictionary).get("save", "cha")).capitalize()]) if contest
					else "DC %d %s" % [int(check.get("dc", 10)), skill],
				"cost": cost_of(offer), "why": why_not(c, holder, offer), "help": str(tr.get("summary", ""))})
	return out


## "" if `c` can take `holder`'s offer now, else why not.
func why_not(c: Combatant, holder: Combatant, offer: Dictionary) -> String:
	var e := enc()
	var why := e._bonus_check(c) if cost_of(offer) == "bonus" else e._action_check(c)
	if why != "":
		return why
	var reach := int(offer.get("range", DEFAULT_RANGE))
	if e.distance(c, holder) > reach:
		return "Get within %d ft of %s first" % [reach, holder.name()]
	if offer.has("needs") and tool_for(c, str(offer["needs"])) == "":
		return "Needs a %s" % str(offer["needs"]).capitalize()
	return ""


## The carried item of tool kind `kind` that `c` plays (one it is proficient with first), or "".
static func tool_for(c: Combatant, kind: String) -> String:
	if not c.creature is Character:
		return ""
	var ch := c.creature as Character
	var best := ""
	for entry: Dictionary in ch.inventory:
		if int(entry.get("qty", 0)) <= 0:
			continue
		var id := str(entry["id"])
		if str((Compendium.shared().item_data(id).get("tool", {}) as Dictionary).get("kind", "")) != kind:
			continue
		if (ch.proficiencies.get("tools", {}) as Dictionary).has(id):
			return id
		if best == "":
			best = id
	return best


## Takes `holder`'s offer from its trait `trait_id`: spends the action or Bonus Action, sends the ability event, rolls
## the check, and on a success deals the damage and lands the riders on the holder.
func take(c: Combatant, holder: Combatant, trait_id: String) -> CombatResult:
	var e := enc()
	if holder == null or holder == c:
		return CombatResult.fail("Nobody to do that for")
	var found := {}
	for o in offers_of(holder):
		if str((o["trait"] as Dictionary).get("id", "")) == trait_id:
			found = o
	if found.is_empty():
		return CombatResult.fail("%s offers nothing like that" % holder.name())
	var tr := found["trait"] as Dictionary
	var offer := found["offer"] as Dictionary
	var why := why_not(c, holder, offer)
	if why != "":
		return CombatResult.fail(why)
	if cost_of(offer) == "bonus":
		c.bonus_available = false
	else:
		e.spend_action(c)
	var label := label_of(tr, offer)
	e.events.append({"type": "ability", "source": "feature", "by": c.id, "key": key_of(tr, offer), "targets": [holder.id], "cells": []})
	var check := offer.get("check", {}) as Dictionary
	var skill := StringName(str(check.get("skill", "performance")))
	var adv: Array[String] = []
	var played := tool_for(c, str(offer["needs"])) if offer.has("needs") else ""
	if played != "" and ((c.creature as Character).proficiencies.get("tools", {}) as Dictionary).has(played):
		adv.append("%s proficiency" % str(Compendium.shared().item_data(played).get("name", played)))
	if offer.get("contest", null) is Dictionary:
		return _contest(c, holder, offer, label, skill, adv)
	var test := c.creature.roll_check(e.dice, skill, int(check.get("dc", 10)), adv, [], "%s: %s check (%s)" % [label,
		str(skill).capitalize(), c.name()])
	if not test.success:
		e.log.add("info", "%s tries %s, but %s isn't moved" % [c.name(), label, holder.name()], c.id, [test.describe()])
		return CombatResult.new()
	e.log.add("info", "%s performs %s for %s" % [c.name(), label, holder.name()], c.id, [test.describe()])
	land(c, holder, offer, label)
	return CombatResult.new()


## A contest: `c`'s check sets the DC of `holder`'s save, and a failed save lets the offer land.
func _contest(c: Combatant, holder: Combatant, offer: Dictionary, label: String, skill: StringName, adv: Array[String]) -> CombatResult:
	var e := enc()
	var test := c.creature.roll_check(e.dice, skill, 0, adv, [], "%s: %s check (%s)" % [label, str(skill).capitalize(), c.name()])
	var ab := StringName(str((offer["contest"] as Dictionary).get("save", "cha")))
	var save := holder.creature.roll_save(e.dice, ab, test.total, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, holder.name()])
	if save.success:
		e.log.add("info", "%s matches %s's %s" % [holder.name(), c.name(), label], c.id, [test.describe(), save.describe()])
		return CombatResult.new()
	e.log.add("info", "%s wins %s against %s" % [c.name(), label, holder.name()], c.id, [test.describe(), save.describe()])
	land(c, holder, offer, label)
	return CombatResult.new()


## What a successful offer does to `holder`: its damage, then its riders, `c` their source.
func land(c: Combatant, holder: Combatant, offer: Dictionary, label: String) -> void:
	var e := enc()
	var parts: Array = []
	var details: Array = []
	for raw: Variant in offer.get("damage", []):
		var d := raw as Dictionary
		if d.has("dice"):
			var rolled := e.damage._roll_damage_dice(str(d["dice"]), false, 0, label)
			parts.append({"amount": int(rolled["total"]), "type": str(d.get("type", "force"))})
			details.append("%s %s: %s" % [label, str(d["dice"]), str(rolled["text"])])
		else:
			parts.append({"amount": int(d.get("amount", 0)), "type": str(d.get("type", "force"))})
	if not parts.is_empty():
		e.deal_damage(c, holder, parts, false, label, details)
	var riders := offer.get("on_success", []) as Array
	if not riders.is_empty() and holder.is_alive():
		e.monster_actions.apply_riders(c, holder, riders, {}, label)
