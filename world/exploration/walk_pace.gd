class_name WalkPace
extends RefCounted
## The settings for how fast everyone walks on screen (owner 2026-10-18: characters and NPCs 25% faster; 2026-10-30:
## heroes 25% slower, enemies 15% faster). This is the pace of the walk cycle and the glide between squares, never the
## Speed stat: Creature.speed(), movement left and the AI's reach are untouched.
## Exploring, everyone's old value is scaled by FASTER: the party's and its followers' squares (LocationView.STEP_TIME,
## SNEAK_STEP_TIME), townsfolk on their rounds (NpcRoutes), a lead's walk (LocationLead), the gray-box room's party and
## villager. The party and a lead take HEROES on top, so the heroes are the slow ones of the village (townsfolk keep
## FASTER alone). Walk cycles and footsteps follow, as both are paced to the step time (DirectionalSprite.set_step_time).
## A fight's squares (CombatView.STEP_TIME) keep their base pace and the Settings combat speed, and each side scales it
## by combat_scale; time spent standing (a route's `pause`) is left alone.
const FASTER := 1.25
## The party's and its guests' walk, against the pace they had before (owner 2026-10-30: 25% slower).
const HEROES := 0.75
## An enemy's walk in a fight (owner 2026-10-30: 15% faster).
const FOES := 1.15


## How fast `c` walks in a fight against the base pace: heroes (the party and its guests) slow, enemies quick, anyone else
## (a neutral) as it was. A square takes CombatView.STEP_TIME divided by this.
static func combat_scale(c: Combatant) -> float:
	if c == null:
		return 1.0
	match c.side:
		&"party", &"guest":
			return HEROES
		&"enemy":
			return FOES
	return 1.0
