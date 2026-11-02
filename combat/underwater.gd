class_name Underwater
extends RefCounted
## Fighting under water (a map's `underwater: true`, Encounter.underwater; 2024 PHB "Underwater Combat"): a melee weapon
## attack has Disadvantage unless the attacker has a Swim Speed or the weapon is a dagger, javelin, shortsword, spear or
## trident; a ranged weapon attack misses beyond its normal range and has Disadvantage within it unless the weapon is a
## crossbow, a net, or a javelin, spear, trident or dart; and everything wholly under water has Resistance to Fire
## damage. Holding breath and drowning are the story's (HoldBreath covers a fight's held breath).

const MELEE_OK: Array[String] = ["dagger", "javelin", "shortsword", "spear", "trident"]
const RANGED_OK: Array[String] = ["net", "javelin", "spear", "trident", "dart"]
const STACK := "underwater"


static func _kind_of(p: WeaponProfile) -> String:
	return p.item_id.get_slice("@", 0)


## Why an attack with weapon `p` has Disadvantage under water, or "".
static func attack_disadvantage(e: Encounter, c: Combatant, p: WeaponProfile, melee: bool, kind: String) -> String:
	if not e.underwater or kind == "spell":
		return ""
	var item := _kind_of(p)
	if melee:
		if c.creature.speed("swim").total() > 0 or item in MELEE_OK or kind == "natural" or p.item_id == "":
			return ""
		return "under water"
	if item.contains("crossbow") or item in RANGED_OK:
		return ""
	return "under water"


## Everything in an underwater fight has Resistance to Fire damage (an effect that goes with the fight).
static func apply(e: Encounter, c: Combatant) -> void:
	if not e.underwater or c.creature.effects.any(func(fx: Effect) -> bool: return fx.stack_key == STACK):
		return
	var fx := Effect.new("Under water", &"feature", "underwater").with_modifier("resistance", {"value": "fire"})
	fx.stack_key = STACK
	fx.ends = Effect.Ends.NEVER
	c.creature.add_effect(fx)
