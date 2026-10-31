class_name FigureTalk
extends RefCounted
## People gesture as they talk, where they are 3D figures with talk and greet clips (ModelFigure.gesture): a game calls
## opened() as a conversation opens (the one spoken to turns to the party's leader and greets them, and the leader turns
## to them) and spoke() as each line shows (its speaker gestures; DialogueUI.spoke). A sprite has no gestures and keeps
## the way it faces, so a game with only sprites sees nothing change.


## A conversation with `npc_id` opened in `view`.
static func opened(view: LocationView, npc_id: String) -> void:
	if view == null or view.in_combat:
		return
	var them := token_of(view, npc_id)
	var lead := view.tokens.get(view.leader().id, null) as CombatToken if view.leader() != null else null
	if them == null:
		return
	if lead != null and is_instance_valid(lead):
		var to_lead := Vector2(lead.global_position.x - them.global_position.x, lead.global_position.z - them.global_position.z)
		if them.sprite is ModelFigure:
			them.face(to_lead, false)
		if lead.sprite is ModelFigure:
			lead.face(-to_lead, false)
	them.gesture("greet")


## A line said by `speaker_id` (an NPC's id or a party member's) is showing.
static func spoke(view: LocationView, speaker_id: String) -> void:
	if view == null or view.in_combat:
		return
	var tok := token_of(view, speaker_id)
	if tok != null:
		tok.gesture("talk")


## The figure of `id` in `view`: a person of the place, one a scene brought on, or a member of the party.
static func token_of(view: LocationView, id: String) -> CombatToken:
	if id == "":
		return null
	var tok: Variant = view.npc_tokens.get(id, view._staged.get(id))
	if is_instance_valid(tok):
		return tok as CombatToken
	for t: Variant in view.tokens.values():
		var ct := t as CombatToken
		if is_instance_valid(ct) and ct.combatant != null and (ct.combatant.creature.id == id or ct.combatant.id == id):
			return ct
	return null
