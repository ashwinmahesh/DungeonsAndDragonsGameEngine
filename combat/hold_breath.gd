class_name HoldBreath
extends RefCounted
## Holding your breath in a fight (a Phantom Hearse that finds the living by their breath): a hero's free toggle, on the
## Common tab while a creature that senses breath (a trait's `senses_breath: true`) is in the fight. While a hero holds
## it, such creatures can't see them (EncounterSight.can_see). Damage breaks it unless they make a Constitution save
## (DC 10 or half the damage, as Concentration's), and they must breathe again by the end of their next turn after
## `turns` of their own (1 + Constitution modifier, at least 1). Kept on the combatant: a fight's own.

const META := "holding_breath"


## Whether `a` finds creatures by their breath.
static func senses_breath(e: Encounter, a: Combatant) -> bool:
	for tr: Variant in e.monster_actions.traits(a):
		if bool((tr as Dictionary).get("senses_breath", false)):
			return true
	return false


## Whether anyone in the fight would be fooled by it: the toggle shows only then.
static func matters(e: Encounter) -> bool:
	return e.combatants.any(func(x: Combatant) -> bool: return x.is_alive() and senses_breath(e, x))


static func holding(c: Combatant) -> bool:
	return c.has_meta(META)


## Starts or stops `c` holding their breath.
static func toggle(e: Encounter, c: Combatant) -> CombatResult:
	if holding(c):
		stop(e, c, "breathes again")
		return CombatResult.new()
	c.set_meta(META, maxi(1, 1 + c.creature.ability_mod(&"con")))
	e.log.add("info", "%s holds their breath" % c.name(), c.id)
	e.events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


static func stop(e: Encounter, c: Combatant, why: String) -> void:
	if not holding(c):
		return
	c.remove_meta(META)
	e.log.add("info", "%s %s" % [c.name(), why], c.id)
	e.events.append({"type": "condition", "id": c.id})


## Damage to a hero holding their breath: a Constitution save (DC 10 or half the damage) or they gasp.
static func hurt(e: Encounter, c: Combatant, amount: int) -> void:
	if not holding(c) or amount <= 0:
		return
	var t := c.creature.roll_save(e.dice, &"con", maxi(10, amount / 2), [], [], "Con save to hold breath (%s)" % c.name())
	if not t.success:
		stop(e, c, "gasps for air")


## As `c`'s turn ends: a breath held runs out.
static func turn_end(e: Encounter, c: Combatant) -> void:
	if not holding(c):
		return
	var left := int(c.get_meta(META)) - 1
	if left <= 0:
		stop(e, c, "has to breathe")
	else:
		c.set_meta(META, left)
