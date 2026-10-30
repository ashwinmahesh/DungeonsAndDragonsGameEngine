class_name GameFeatures
extends RefCounted
## A game's own options in a fight: the species, subclasses, feats, spells and gifts of a book the engine doesn't ship,
## whose rules need code. The game names a script under "features" in data/campaign.json that extends this class;
## the encounter makes one per fight (`Encounter.game`) and calls the hooks below next to RavenloftFeatures' and
## FaerunFeatures'. This base does nothing, so a game without its own module fights exactly as before.
##
## Its hotbar entries are "feat:gm:<id>" (FeatureActions hands them to `perform`), its queued Reactions have kinds
## starting "gm_" (EncounterReactions asks `queued_ok`, `fire_queued` and `queued_text` about them), and a sustained
## spell action of its own is `"do": "game"` (SpellSustained asks `sustained_why` and `sustained`). Riders it arms
## (`rider_options`) sit in `Combatant.armed` like the engine's, for `after_hit` to read.
## A benefit with `"policy"` in its data acts on its own unless its owner turns it Off in the class tab: `allowed`.

## The module a test put in place of the configured one (use()); null reads data/campaign.json.
static var _override: GDScript = null

var _enc: WeakRef
## A multi-target action hands its picks in `targets_in`; the hotbar's single pick comes as `t`.
var targets_in: Array = []
## The right-click choice an action was performed with, or "".
var choice_in := ""


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


## The game's module for `encounter`: the script named under "features" in data/campaign.json, or this base.
static func make(encounter: Encounter) -> GameFeatures:
	var script := _override
	if script == null and _configured_path() != "":
		script = load(_configured_path()) as GDScript
	if script != null:
		var m: Variant = script.new(encounter)
		if m is GameFeatures:
			return m as GameFeatures
		push_error("GameFeatures: %s doesn't extend GameFeatures" % script.resource_path)
	return GameFeatures.new(encounter)


## Puts `script` (a GameFeatures subclass) in place of the configured module for fights made from now on; null goes
## back to the configured one.
static func use(script: GDScript) -> void:
	_override = script


static func _configured_path() -> String:
	return str(Campaign.config().get("features", ""))


# --- Helpers a module shares --------------------------------------------------------------------------------------

func enc() -> Encounter:
	return _enc.get_ref() as Encounter


static func _ch(c: Combatant) -> Character:
	return c.creature as Character if c != null and c.creature is Character else null


## Whether `c` has the feature, trait or feat `id` (CombatFeatures.has_feature reads every source).
static func has(c: Combatant, id: String) -> bool:
	return c != null and CombatFeatures.has_feature(c, id)


func feat(c: Combatant, feat_id: String) -> bool:
	return c != null and enc().features.has_feat(c, feat_id)


## A hotbar entry of this module: {id "feat:gm:<id>", label, sub, cost, why, targeting, help, range}.
func _entry(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String, rng: int = 0) -> Dictionary:
	return {"id": "feat:gm:" + id, "label": label, "sub": sub, "cost": cost, "why": why, "targeting": targeting, "help": help, "range": rng}


static func _first(a: String, b: String) -> String:
	return a if a != "" else b


func _res_why(c: Combatant, res: String) -> String:
	var ch := _ch(c)
	return "" if ch != null and ch.resource_left(res) > 0 else "None left"


## A benefit marked `"policy"`: on unless its owner turned it Off.
static func allowed(c: Combatant, id: String) -> bool:
	return str(c.reaction_rules.get(id, "auto")) != "never"


func _turn_key() -> String:
	return "%d:%d" % [enc().round_no, enc().turn_index]


## Once per turn (anyone's turn): true the first time, false after.
func _once_per_turn(c: Combatant, key: String) -> bool:
	if str(c.get_meta(key, "")) == _turn_key():
		return false
	c.set_meta(key, _turn_key())
	return true


func _log(kind: String, text: String, who: Combatant, details: Array = []) -> void:
	enc().log.add(kind, text, who.id if who != null else "", details)


## Heroic Inspiration for `t` from `giver`'s feature; false when it already has some (nothing to give).
func _inspire(giver: Combatant, t: Combatant, label: String) -> bool:
	var ch := _ch(t)
	if ch == null or ch.heroic_inspiration:
		return false
	ch.heroic_inspiration = true
	_log("info", "%s gains Heroic Inspiration (%s, from %s)" % [t.name(), label, giver.name()], t)
	return true


## Whether this module answers for the hotbar action, queued kind or sustained mode `id` (a game that splits its code
## into parts routes by it).
func owns(_id: String) -> bool:
	return false


# --- The hotbar ---------------------------------------------------------------------------------------------------

## Adds `c`'s actions to the hotbar (`aw` and `bw`: why the action or Bonus Action can't be taken now, or "").
func list(_c: Combatant, _out: Array[Dictionary], _aw: String, _bw: String) -> void:
	pass


## Performs the action "feat:gm:<id>" (`id` without the prefix).
func perform(_c: Combatant, _id: String, _t: Combatant, _cell: Vector2i, _point: Vector2) -> CombatResult:
	return CombatResult.fail("Not available")


## Riders `c` can arm for its next hit this turn: {id, label, sub, why}.
func rider_options(_c: Combatant) -> Array[Dictionary]:
	return []


# --- Attacks ------------------------------------------------------------------------------------------------------

## Adds Advantage and Disadvantage sources (their names) for `c`'s attack on `target`.
func attack_situation(_c: Combatant, _target: Combatant, _option: Dictionary, _adv: Array[String], _dis: Array[String]) -> void:
	pass


## Damage dice a hit adds: [{dice, type, label}] as ClassFeatures.hit_dice gives them.
func hit_dice(_c: Combatant, _target: Combatant, _option: Dictionary, _st: Dictionary) -> Array[Dictionary]:
	return []


## After a weapon or Unarmed Strike hit, its damage dealt.
func after_hit(_c: Combatant, _target: Combatant, _option: Dictionary, _st: Dictionary, _r: CombatResult) -> void:
	pass


## Offers before an attack roll is made (Warding Flare's shape: they may add to st["sit"]["disadvantage"]), as
## Reactions.before_roll builds them: a Reaction when a creature targets someone with an attack.
func before_roll(_st: Dictionary, _out: Array) -> void:
	pass


## Reactions that can turn a hit into a miss, as Reactions.after_hit_target builds them.
func after_hit_target(_st: Dictionary, _miss: Callable, _out: Array) -> void:
	pass


## Reactions that cut a hit's damage before it lands (`total` and `cut` as Reactions.against_damage passes them).
func against_damage(_st: Dictionary, _total: Callable, _cut: Callable, _out: Array) -> void:
	pass


# --- Damage, drops and deaths -------------------------------------------------------------------------------------

## Changes the damage parts [{amount, type}] about to reach `target`, before Resistances.
func adjust_incoming(_source: Combatant, _target: Combatant, _parts: Array) -> void:
	pass


## After `target` (any combatant) took `amount` damage (after Resistances; `parts` as dealt, `dr` the full result).
func after_damage(_source: Combatant, _target: Combatant, _amount: int, _parts: Array = [], _dr: DamageResult = null) -> void:
	pass


## Queues Reactions to `target` being damaged (EncounterReactions' queue, kinds starting "gm_").
func queue_damage_reactions(_source: Combatant, _target: Combatant) -> void:
	pass


func queued_ok(_q: Dictionary, _reactor: Combatant) -> bool:
	return false


func fire_queued(_q: Dictionary, _reactor: Combatant, _trigger: Combatant) -> CombatResult:
	return CombatResult.new()


## [title, text with %s for the trigger's then the reactor's name] for a queued kind.
func queued_text(_kind: String) -> Array:
	return ["Reaction?", "%s acts; %s can react."]


## `by` dropped `target` to 0 Hit Points.
func on_drop(_by: Combatant, _target: Combatant) -> void:
	pass


## `target` would fall to 0 Hit Points from `damage`: true when something keeps it up (it's then at 1 or more).
func on_zero(_target: Combatant, _damage: int) -> bool:
	return false


func on_death(_source: Combatant, _dead: Combatant) -> void:
	pass


## `target` would die outright (Massive Damage, a slaying effect): true when something keeps it alive; the module
## sets its Hit Points and logs it, and the engine treats the creature as up.
func cheats_death(_target: Combatant) -> bool:
	return false


## A fight object dropped to 0 Hit Points or was smashed (`source` null when nothing in particular broke it).
func object_broken(_o: BattleObject, _source: Combatant) -> void:
	pass


## Whether something holds `target` where it stands against a push or pull.
func blocks_forced_move(_target: Combatant) -> bool:
	return false


# --- Turns, Initiative and D20 Tests ------------------------------------------------------------------------------

## Why `c` rolls Initiative with Advantage (names), or [].
func initiative_advantage(_c: Combatant) -> Array[String]:
	return []


func initiative_rolled() -> void:
	pass


## As `c`'s turn starts (every combatant, monsters too), after the monster's own turn-start traits; a save or a
## Reaction here may pause for the player's answer.
func turn_start(_c: Combatant) -> CombatResult:
	return CombatResult.new()


## As `c`'s turn ends (every combatant), after the monster's own turn-end traits.
func turn_end(_c: Combatant) -> void:
	pass


## The fight has begun (Initiative rolled, round 1 about to start).
func fight_started() -> void:
	pass


## A new round (2 onward) begins.
func round_started(_round_no: int) -> void:
	pass


## Before a D20 Test: {advantage: [names], disadvantage: [names]}.
func before_d20(_c: Combatant, _kind: D20Test.Kind, _keys: Array[String]) -> Dictionary:
	return {}


## Offers that could change `c`'s roll `t` after it, as D20Responses.offers_for collects them.
func d20_offers(_c: Combatant, _t: D20Test, _keys: Array[String], _out: Array) -> void:
	pass


func before_action(_c: Combatant) -> void:
	pass


## `c` is about to take the Attack action ("attack": its first attack) or the Magic action ("magic": a spell with a
## casting time of an action): true when something wastes it (the action is spent and nothing more happens).
func wastes_action(_c: Combatant, _kind: String) -> bool:
	return false


func after_action(_c: Combatant, _action: Dictionary, _targets: Array = []) -> void:
	pass


# --- Monsters and movement ---------------------------------------------------------------------------------------

## An AI-run creature's turn the game plays itself (after fear, commands and morale, before the engine's boss and
## ordinary brains): a CombatResult takes the rest of the turn, null lets the brain carry on.
func monster_turn(_c: Combatant) -> Variant:
	return null


## A monster's Bonus Action with a `do` the engine doesn't run (MonsterActions.game_action), as MonsterActions.bonus_action
## asks with the AI's `plan`: a CombatResult when it was taken, null when not.
func bonus_action(_c: Combatant, _act: Dictionary, _plan: String) -> Variant:
	return null


## A monster's action with a `do` the engine doesn't run: from the hotbar of a player-run creature (`t` and `cell` as
## picked), and offered to the AI each turn with `t` null (the game picks, or returns null to pass). A CombatResult
## when it was taken (the game spends the action and the uses), null when not.
func special_action(_c: Combatant, _act: Dictionary, _t: Combatant, _cell: Vector2i) -> Variant:
	return null


## A monster's on-hit rider (`rd`, from its action's riders) with a `do` the engine doesn't know: true when handled.
## `by_type` holds the hit's damage by type.
func rider(_src: Combatant, _t: Combatant, _rd: Dictionary, _by_type: Dictionary, _act_name: String) -> bool:
	return false


## `c` stepped into `cell` (each square of a move, after the monster's own entered-space traits).
func entered_cell(_c: Combatant, _cell: Vector2i) -> void:
	pass


## Hotbar entries for `c` in a shape this module made (a ShapeChange label of its own): true when it listed the way out
## itself, so the engine's "Leave Wild Shape" isn't added.
func shaped_list(_c: Combatant, _out: Array[Dictionary], _bw: String) -> bool:
	return false


## Squares `c` can't move through (a set: cell -> true), read once per path search. Must be pure: path searches run on
## a worker thread.
func barrier_cells(_c: Combatant) -> Dictionary:
	return {}


## How much more (or less) the AI-run `c` wants to attack `t`: a multiplier on its score, 1.0 for no change. Must be
## pure: the AI scores on a worker thread.
func target_weight(_c: Combatant, _t: Combatant) -> float:
	return 1.0


# --- Spells -------------------------------------------------------------------------------------------------------

## The casting time `c` casts `s` with in a fight (`unit` as the spell has it: a minute or more can't be cast in a fight
## unless a feature says otherwise).
func casting_unit(_c: Combatant, _s: Dictionary, unit: String) -> String:
	return unit


## Whether `c`'s spell `s` reaches `t` whatever its range and line of effect say (a feature that carries touch spells
## to a marked ally).
func spell_reach(_c: Combatant, _s: Dictionary, _t: Combatant) -> bool:
	return false

## Before a spell's targets are resolved (`ctx` as SpellCasting builds it).
func before_resolve(_ctx: Dictionary) -> void:
	pass


## A casting that needs no Concentration (RavenloftFeatures.skips_concentration's shape): the duration it has instead, or {}.
func skips_concentration(_c: Combatant, _s: Dictionary, _free: bool) -> Dictionary:
	return {}


## Whether a feature pays `s`'s costly Material component instead of the carried item (with `spend`, it pays now).
func pays_component(_c: Combatant, _s: Dictionary, _spend: bool) -> bool:
	return false


## Resolves a spell that needs this module's code: true when it did (the engine then does nothing more with it).
func resolve_spell(_ctx: Dictionary, _tgt: Array[Combatant], _cells: Array[Vector2i], _r: CombatResult) -> bool:
	return false


## After a spell is cast (`slot` 0 for a cantrip, `free` without a slot).
func after_cast(_c: Combatant, _s: Dictionary, _slot: int, _free: bool = false, _ctx: Dictionary = {}) -> void:
	pass


## Damage added to one damage roll of a spell; add its parts to `bonus` so the log shows them.
func spell_damage_bonus(_ctx: Dictionary, _bonus: Breakdown) -> int:
	return 0


## Healing added to a spell's healing of `t`.
func spell_healing(_ctx: Dictionary, _t: Combatant) -> int:
	return 0


## Why a sustained action `"do": "game"` can't be taken now, or "".
func sustained_why(_c: Combatant, _a: Dictionary, _d: Dictionary, _t: Combatant, _point: Vector2) -> String:
	return "Not available"


## A sustained action `"do": "game"`.
func sustained(_c: Combatant, _a: Dictionary, _d: Dictionary, _ctx: Dictionary, _targets: Array, _point: Vector2, _dir: Vector2, _r: CombatResult) -> CombatResult:
	return CombatResult.fail("Not available")


## A creature failed the save of the zone `o` (a spell's lasting area).
func zone_failed_save(_o: FieldObject, _t: Combatant) -> void:
	pass


## A save ended the effect `fx` on `c`.
func after_save_ended(_c: Combatant, _fx: Effect) -> void:
	pass


## An effect was added to `cr` in this fight.
func effect_added(_cr: Creature, _fx: Effect) -> void:
	pass


## A spell summoned `m`.
func after_summon(_ctx: Dictionary, _m: Creature) -> void:
	pass
