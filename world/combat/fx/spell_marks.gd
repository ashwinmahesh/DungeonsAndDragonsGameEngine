class_name SpellMarks
extends RefCounted
## The marks spells and falls leave on the ground (Visual Polish Plan E41), through GroundMarks, which owns the decals,
## how many stay, their fade and whether a game has them at all (Look.PAINTED `marks`): a fire or lightning spell
## scorches, a cold one leaves frost, acid and poison a green stain, necrotic a black rot; a creature that falls bleeds,
## a monstrous one leaves ichor.

## An effect's flavour (art/vfx/effects.json) to the mark it leaves; a flavour not named leaves none.
const KINDS := {"fire": "scorch", "greenfire": "scorch", "lightning": "scorch", "thunder": "scorch", "cold": "frost",
	"acid": "stain", "poison": "stain", "necrotic": "rot", "blood": "blood"}
## Creature types that leave ichor where they fall rather than blood.
const ICHOR: Array[StringName] = [&"aberration", &"construct", &"elemental", &"fiend", &"ooze", &"plant", &"undead",
	&"monstrosity"]


static func kind_for(cue: Dictionary) -> String:
	return str(KINDS.get(str(cue.get("flavour", "")), ""))


## A missile or blow of `cue` landed on whoever stands at `ground` (their feet).
static func spot(parent: Node3D, cue: Dictionary, ground: Vector3, size: float = 1.0) -> void:
	var k := kind_for(cue)
	if k != "":
		GroundMarks.leave(parent, ground, k, 0.45 * size)


## An area spell of `cue` went off over `cells`: a mark every few squares, spread across them.
static func area(parent: Node3D, cue: Dictionary, cells: Array, board: ArenaBoard) -> void:
	var k := kind_for(cue)
	if k == "" or cells.is_empty() or board == null:
		return
	for at in FxAreas.spots(cells, board, clampi(cells.size() / 3, 1, 8)):
		GroundMarks.leave(parent, at, k, 0.9)


## `c` fell where it stands (`ground`): blood, or ichor for the monstrous.
static func fall(parent: Node3D, c: Combatant, ground: Vector3) -> void:
	if c == null or c.creature == null:
		return
	GroundMarks.leave(parent, ground, "ichor" if c.creature.creature_type in ICHOR else "blood", 0.7)
