class_name DialogueRunner
extends RefCounted
## Plays a conversation from a .dialogue file one beat at a time (plan §5.4, docs/contracts/dialogue.md). The UI
## calls next() and shows what comes back; on an options beat it calls choose(i). Skill checks roll in the open with
## the speaking character's bonus. Effects (flags, quests, items, money, attitudes, milestones) go straight into the
## StoryState; a `combat` line ends the conversation with the encounter to start.
##
## Beats: {kind: "line", speaker_id, name, portrait, mood, text, narrator, party}
##        {kind: "options", options: [{text, label, check: {skill, dc, bonus, chance, who}, enabled, ends: [quest names]}]}
##        {kind: "check", who, portrait, skill, dc, total, success, detail, said}
##        {kind: "guidance", offer}: before a check, someone could cast Guidance (GuidanceOffer); the screen asks and
##            calls answer_guidance(), which rolls the check and returns its beat
##        {kind: "notice", text}
##        {kind: "lead", npc, to}: the party follows `npc` to `to` (`lead <npc> to <where>`); the game walks them (or asks
##            first, when it is another place), sets `check.last` to whether they went, and calls resume() on the screen
##        {kind: "cutscene", id, image, focus}: a full-screen picture under what follows (id "" takes it away)
##        {kind: "end", combat: encounter id or "", end_game: the conversation ended the campaign (`end_game`),
##            move: {location, spawn} where `move` sends the party (only present then)}

## The Narrator's portrait (art/portraits/narrator.png), on their lines here and in the exploration box.
const NARRATOR_PORTRAIT := "narrator"
const ABILITIES := {"strength": &"str", "dexterity": &"dex", "constitution": &"con", "intelligence": &"int",
	"wisdom": &"wis", "charisma": &"cha"}

## The way back out of each party picker (its last option).
const BACK_OUT := {"sacrifice": "No one. Not this.", "respec": "Never mind. No one sits."}

## F4 (Side Quest Failure Plan): a menu whose every option closes the same quests is a story beat, not a choice, so it
## wears no seals and no "Ends" line (owner's call via the coordinator, 2026-10-19: Godrick's and Wren's camp talks, the
## Vallaki aftermath). The tags stay in the data and the lint still demands them. Set this true to mark those menus too.
const MARK_UNIFORM_MENUS := false

var st: StoryState
var dice: DiceRoller
## StoryState.flags: d20s kept for the party's next fight (`store_d20`; LocationFights hands them to it).
const STORED_D20S := "_stored_d20s"
var narrator: Narrator = null
var file: DialogueFile = null
var node: String = ""
var pc: int = 0
var finished: bool = false
var combat: String = ""
## Where `move` sends the party when the conversation ends, {location, spawn} (GameRoot._dialogue_ended); {} for nowhere.
var move_to: Dictionary = {}
## The conversation reached `end_game` (ADR 0014): the campaign's ending is recorded (Endings) and the game shows it.
var ended_game: bool = false
## The party member speaking for the party (the leader unless an option's tag picks someone).
var speaker: Character = null
var _options: Array[Dictionary] = []
var _pending_jump: String = ""
var _guard: int = 0
var _picking := false       ## waiting for the player to choose a party member (`sacrifice`, `respec`)
var _pick_purpose := "sacrifice"
var _gift := ""                ## the dark gift on offer (`dark_gift`)
var _last_option_key := ""     ## the spent-option key of the last social check (see choose)
var _last_check: Dictionary = {}        ## {who, test, skill, said} of the last check rolled
var _check_jumps: Array[String] = []    ## [ok, fail] targets of the last check
var _failed_save: Array[Character] = []    ## the heroes who failed the last `save ... party` (the `failed` receivers)
var _queued: Array[Dictionary] = []   ## beats a statement produced beyond its first (a Tarokka card, then the verse)
var _cards_read: Dictionary = {}      ## the reading's slots `reading read` has turned in this conversation
var _reading_told := false            ## the campaign has heard this conversation finished the reading
## The game's conversations offer Guidance before a check (a `guidance` beat); off for the bots and tools that play
## conversations without a screen.
var offer_guidance := false
## The game's conversations stop at a `lead` (the party follows someone on the map, or is asked to follow them to
## another place); off for the bots and tools that play conversations without a map: the lead counts as followed.
var offer_leads := false
## A check waiting on the Guidance prompt: {offer, who, skill, dc, said, then: Callable(check beat) -> beat to show}.
var _guidance_wait: Dictionary = {}
## The NPC being spoken to (shops open for them).
var npc_id: String = ""


func _init(state: StoryState, dice_: DiceRoller, narrator_: Narrator = null) -> void:
	st = state
	dice = dice_
	narrator = narrator_


## Starts at "file_key:node" (e.g. "death_house/rose_thorn:start"). False if it doesn't exist.
func start(ref: String) -> bool:
	speaker = st.leader_character()
	_queued.clear()
	_cards_read.clear()
	_reading_told = false
	_picking = false
	finished = false
	combat = ""
	move_to = {}
	ended_game = false
	return _goto(ref)


func _goto(ref: String) -> bool:
	if ref == "END" or ref == "":
		finished = true
		return true
	var file_key := file.key if file != null else ""
	var target := ref
	if ref.contains("/") and ref.contains(":"):
		file_key = ref.substr(0, ref.rfind(":"))
		target = ref.substr(ref.rfind(":") + 1)
	elif ref.contains(":") and file == null:
		file_key = ref.substr(0, ref.rfind(":"))
		target = ref.substr(ref.rfind(":") + 1)
	var f := DialogueFile.load_key(file_key) if file == null or file.key != file_key else file
	if f == null or not f.nodes.has(target):
		push_warning("Dialogue: no node '%s'" % ref)
		finished = true
		return false
	file = f
	node = target
	pc = 0
	return true


func _stmts() -> Array[Dictionary]:
	return file.nodes[node] as Array[Dictionary]


## The next beat. Options stay on screen until choose() is called.
func next() -> Dictionary:
	if not _options.is_empty():
		return _options_beat()
	if _picking:
		return _pick_beat()
	if not _queued.is_empty():
		return _queued.pop_front()
	if _pending_jump != "":
		var j := _pending_jump
		_pending_jump = ""
		_goto(j)
	_guard = 0
	while true:
		_guard += 1
		if _guard > 5000:
			push_warning("Dialogue: runaway loop in %s:%s" % [file.key, node])
			finished = true
		if finished:
			return _end_beat()
		var list := _stmts()
		if pc >= list.size():
			finished = true
			continue
		var s := list[pc]
		match str(s["t"]):
			"line":
				pc += 1
				var beat := _line_beat(str(s["speaker"]), str(s["mood"]), str(s["text"]))
				beat["away"] = str(s.get("away", ""))   # the `[away]` cue: who turns their back (DialogueBusts)
				return beat
			"interject":
				pc += 1
				var sel := str(s["selector"])
				if sel.begins_with("guest:"):
					# A story ally travelling with the party says it (Ireena on the road).
					if sel.substr(6) in st.guest_ids:
						return _line_beat(sel.substr(6), "", str(s["text"]))
					continue
				var who := st.find_member(sel)
				if who == null:
					continue
				return _party_line(who, str(s["text"]))
			"option":
				_collect_options()
				if _options.is_empty():
					continue
				return _options_beat()
			"jump":
				_goto(str(s["to"]))
			"if":
				if StoryConditions.check(str(s["cond"]), st):
					pc += 1
				else:
					_skip_branch()
			"elif", "else":
				_skip_to_endif()
			"endif":
				pc += 1
			"set":
				_apply_set(s)
				pc += 1
			"quest":
				pc += 1
				if st.set_quest_stage(str(s["id"]), str(s["stage"])):
					return {"kind": "notice", "text": st.quest_notice()}   # "Quest failed: X", "Quest complete: X", else "Journal updated: X"
			"give":
				pc += 1
				var taker := speaker
				if str(s.get("to", "")) != "" and st.find_member(str(s["to"])) != null:
					taker = st.find_member(str(s["to"]))
				st.gain_item(str(s["item"]), int(s["qty"]), taker)
				return {"kind": "notice", "text": "%s receives %s%s" % [_first(taker), Compendium.shared().display_name("items", str(s["item"])),
					" ×%d" % int(s["qty"]) if int(s["qty"]) > 1 else ""]}
			"take":
				pc += 1
				var n := st.take_item(str(s["item"]), int(s["qty"]))
				if n > 0:
					return {"kind": "notice", "text": "Gave away %s%s" % [Compendium.shared().display_name("items", str(s["item"])), " ×%d" % n if n > 1 else ""]}
			"gold":
				pc += 1
				var amount := float(s["amount"])
				# `gold +5 each`: that much for every hero who isn't dead (the party keeps one purse).
				var heroes := _living().size() if bool(s.get("each", false)) else 1
				st.gold = maxf(0.0, st.gold + amount * heroes)
				var said := ("Gained %d gp" if amount >= 0 else "Paid %d gp") % absi(roundi(amount * heroes))
				if bool(s.get("each", false)):
					said += " (%d each)" % absi(roundi(amount))
				return {"kind": "notice", "text": said}
			"standing":
				pc += 1
				var faction := str(s["faction"])
				var now := Factions.change(st, faction, int(s["delta"]))
				return {"kind": "notice", "text": "%s: standing %+d (now %d)" % [Factions.name_of(faction), int(s["delta"]), now]}
			"attitude":
				pc += 1
				st.attitudes[str(s["npc"])] = str(s["value"])
				return {"kind": "notice", "text": "%s is now %s" % [Compendium.shared().display_name("npcs", str(s["npc"])), s["value"]]}
			"xp":
				pc += 1
				var key := "_xp/%s:%s:%d" % [file.key, node, int(s["n"])]
				if not st.flags.has(key):
					st.flags[key] = true
					st.milestones += 1
					if Xp.active(st):
						return {"kind": "notice", "text": Xp.milestone(st)}   # the High award, the floor, the reserve paid
					return {"kind": "notice", "text": "Milestone: the party can advance to level %d" % st.target_level()}
			"xp_fight":
				pc += 1
				var avoided := Xp.talked_away(st, str(s["encounter"]))   # a fight talked or tricked away pays what winning would
				if avoided != "":
					return {"kind": "notice", "text": avoided}
			"check":
				pc += 1
				var who2 := _best_for(str(s["skill"]))
				var ok := str(s["ok"])
				var fail := str(s["fail"])
				var line_key := "%s:%s:%d" % [file.key, node, int(s["n"])]
				return _check(who2, str(s["skill"]), int(s["dc"]), "", func(beat: Dictionary) -> Dictionary:
					_check_jumps = [ok, fail]
					_pending_jump = ok if bool(beat["success"]) or fail == "" else fail
					_pay_check(beat, line_key)
					return beat, str(s.get("edge", "")))
			"combat":
				combat = str(s["encounter"])
				finished = true
			"move":
				# Ends the conversation like a fight does; the party goes as through an exit (GameRoot._dialogue_ended).
				move_to = {"location": str(s["location"]), "spawn": str(s["spawn"])}
				finished = true
			"jail":
				# Locked up (story/jail.gd): the party goes to the cell as `move` takes it, its gear kept by the jailers.
				Jail.lock_up(st, str(s["location"]), str(s["spawn"]), str(s["until"]), bool(s["keep_gear"]))
				move_to = {"location": str(s["location"]), "spawn": str(s["spawn"])}
				finished = true
			"jail_release":
				pc += 1
				var freed := Jail.release(st)
				if freed != "":
					return {"kind": "notice", "text": freed}
			"time":
				pc += 1
				st.advance_minutes(int(s["minutes"]))
			"time_until":
				pc += 1
				var target := int(s["hour"]) * 60
				var wait := target - st.minute_of_day
				if wait <= 0:
					wait += 24 * 60
				st.advance_minutes(wait)
			"reading_draw":
				pc += 1
				Campaign.module().ensure_drawn(st)
			"reading_read":
				pc += 1
				var reading := Campaign.module().reading(str(s["slot"]), st)
				_card_turned(str(s["slot"]))
				if reading.is_empty():
					continue
				var reader := str(s["speaker"]) if str(s["speaker"]) != "" else str(ReadingDeck.setting("reader"))
				_queued.append(_line_beat(reader, "", str(reading["verse"])))
				# The card's slot as the card face names it: the module's `slot_name`, else what its title says first.
				var slot_name := str(reading.get("slot_name", str(reading["title"]).get_slice(": ", 0) if str(reading["title"]).contains(": ") else ""))
				return {"kind": "notice", "text": str(reading["title"]), "card": reading["card"], "slot": reading["slot"],
					"slot_name": slot_name}
			"heal":
				pc += 1
				var healed := _heal(s)
				if healed != "":
					return {"kind": "notice", "text": healed}
			"exhaust":
				pc += 1
				var tired := _exhaust(s)
				if tired != "":
					return {"kind": "notice", "text": tired}
			"timed_condition":
				pc += 1
				var held := _timed_condition(s)
				if held != "":
					return {"kind": "notice", "text": held}
			"party_save":
				pc += 1
				var saved := _party_save(s)
				_pending_jump = str(s["ok"]) if st.last_check or str(s["fail"]) == "" else str(s["fail"])
				return {"kind": "notice", "text": saved}
			"damage":
				pc += 1
				var hurt := _damage(s)
				if hurt != "":
					return {"kind": "notice", "text": hurt}
			"edge":
				pc += 1
				CheckEdges.grant(st, str(s["kind"]), str(s["skill"]), int(s["minutes"]), str(s["why"]))
			"hit_dice":
				pc += 1
				var dice_said := _hit_dice(s)
				if dice_said != "":
					return {"kind": "notice", "text": dice_said}
			"temp_hp":
				pc += 1
				var shielded := _temp_hp(s)
				if shielded != "":
					return {"kind": "notice", "text": shielded}
			"bless":
				pc += 1
				var blessed := _bless(s)
				if blessed != "":
					return {"kind": "notice", "text": blessed}
			"store_d20":
				pc += 1
				var rolled := dice.roll(20, int(s["count"]), "Stored d20s")
				var kept := (st.flags.get(STORED_D20S, []) as Array).duplicate()
				kept.append_array(rolled)
				st.flags[STORED_D20S] = kept
				return {"kind": "notice", "text": "Kept for the next fight: %s" % ", ".join(rolled.map(func(v: int) -> String: return str(v)))}
			"twist":
				pc += 1
				var got: Array[String] = []
				for ch in _receivers(bool(s["party"])):
					ch.gain_twists(int(s["count"]))
					got.append(_first(ch))
				if not got.is_empty():
					return {"kind": "notice", "text": "%s %s a Twist of Fate" % [_names(got), "gains" if got.size() == 1 else "gain"]}
			"inspiration":
				pc += 1
				var inspired := _inspiration(bool(s["party"]))
				if inspired != "":
					return {"kind": "notice", "text": inspired}
			"reading_give":
				pc += 1
				# The treasures the reading hid here, handed to the party's leader (ADR 0011).
				var got := Campaign.module().take_from(str(s["place"]), st)
				if got.is_empty():
					continue
				var taker := st.leader_character()
				for item in got:
					st.gain_item(item, 1, taker)
				for item: Variant in got.slice(1):
					_queued.append({"kind": "notice", "text": "%s receives %s" % [_first(taker), Compendium.shared().display_name("items", str(item))]})
				var found := {"kind": "notice", "text": "%s receives %s" % [_first(taker), Compendium.shared().display_name("items", got[0])]}
				# The treasure's own picture first (story/cutscenes.gd `find:<item>`), the notices over it.
				for item in got:
					var cut := Cutscenes.for_trigger("find:" + item, st)
					if cut != "":
						Cutscenes.mark_played(cut, st)
						_queued.push_front(found)
						# The scenes after it (data `then`) once the notices are read: each picture with the Narrator's
						# line over it, then taken away so the talk goes on as it did.
						var later: Array[Dictionary] = Cutscenes.scenes(cut, "", st, narrator, st.leader_character()).slice(1)
						for sc: Dictionary in later:
							var sid := str(sc["id"])
							_queued.append({"kind": "cutscene", "id": sid, "image": Cutscenes.image(sid, st), "focus": Cutscenes.focus(sid)})
							_queued.append(_line_beat("Narrator", "", str((sc["lines"] as Array[String])[0])))
						if not later.is_empty():
							_queued.append({"kind": "cutscene", "id": "", "image": "", "focus": Cutscenes.focus("")})
						return {"kind": "cutscene", "id": cut, "image": Cutscenes.image(cut, st), "focus": Cutscenes.focus(cut)}
				return found
			"dark_gift":
				pc += 1
				if Compendium.shared().has("dark_gifts", str(s["gift"])) and not _living().is_empty():
					_picking = true
					_pick_purpose = "dark_gift"
					_gift = str(s["gift"])
					return _pick_beat()
			"shop", "services":
				pc += 1
				if npc_id != "":
					return {"kind": str(s["t"]), "npc": npc_id}
			"appear", "vanish":
				pc += 1
				return {"kind": "stage", "what": str(s["t"]), "npc": str(s["npc"]), "at": str(s.get("at", ""))}
			"lead":
				pc += 1
				st.last_check = true
				if offer_leads:
					return {"kind": "lead", "npc": str(s["npc"]), "to": str(s["to"])}
			"join":
				pc += 1
				if st.add_guest(str(s["npc"])):
					return {"kind": "notice", "text": "%s joins the party" % Compendium.shared().display_name("npcs", str(s["npc"]))}
			"leave":
				pc += 1
				if st.remove_guest(str(s["npc"])):
					return {"kind": "notice", "text": "%s leaves the party" % Compendium.shared().display_name("npcs", str(s["npc"]))}
			"sacrifice":
				pc += 1
				st.last_check = true   # skipped with one left alive: the scene goes on as before
				if _living().size() >= 2:
					_picking = true
					_pick_purpose = "sacrifice"
					return _pick_beat()
			"respec":
				pc += 1
				st.last_check = false   # skipped (respec switched off): nobody was rebuilt
				if bool(st.options.get("respec", true)) and not _living().is_empty():
					_picking = true
					_pick_purpose = "respec"
					return _pick_beat()
			"approve", "inspire":
				# Companion approval (story/approval.gd) and Heroic Inspiration for playing in character
				# (story/in_character.gd). Each statement counts once a playthrough, however often its node runs.
				pc += 1
				var once := "_%s/%s:%s:%d" % [str(s["t"]), file.key, node, int(s["n"])]
				if st.flags.has(once):
					continue
				st.flags[once] = true
				var said := Approval.react(st, s["changes"] as Array, str(s["why"])) if str(s["t"]) == "approve" \
					else InCharacter.award(st, str(s["selector"]), str(s["why"]))
				if said != "":
					return {"kind": "notice", "text": said, "approval": str(s["t"]) == "approve"}
			"cast":
				pc += 1
				var cast_said := _cast(str(s["spell"]))
				if cast_said != "":
					return {"kind": "notice", "text": cast_said}
			"reveal":
				pc += 1
				var shown := _reveal(str(s["prop"]))
				if shown != "":
					return {"kind": "notice", "text": "Found: %s" % shown}
			"narrate":
				pc += 1
				if narrator != null:
					var text := narrator.line(str(s["key"]), st, speaker)
					if text != "":
						return _line_beat("Narrator", "", text)
			"cutscene":
				# A full-screen picture behind the lines that follow (story/cutscenes.gd); `cutscene end` takes it away.
				pc += 1
				var cut := "" if str(s["id"]) == "end" else str(s["id"])
				# A `once` picture shows the first time only (the road west's castle: the first try at the posts).
				var once := cut != "" and bool(Cutscenes.get_cutscene(cut).get("once", false))
				if once and Cutscenes.played(cut, st):
					continue
				var img := Cutscenes.image(cut, st) if cut != "" else ""
				if cut == "" or img != "":
					if once:
						Cutscenes.mark_played(cut, st)
					return {"kind": "cutscene", "id": cut, "image": img, "focus": Cutscenes.focus(cut)}
			"end_game":
				# The campaign ends here (ADR 0014): the ending that holds now is recorded; the game plays it when the
				# conversation closes.
				Campaign.module().request_ending(st)
				ended_game = true
				finished = true
			_:
				pc += 1
	return _end_beat()


## `slot` of the reading has been read: once every slot the reading dealt has been, in this conversation, the campaign
## hears that the reading is finished (CampaignModule.reading_finished), once.
func _card_turned(slot: String) -> void:
	_cards_read[slot] = true
	if _reading_told or st.tarokka.is_empty():
		return
	for k: Variant in st.tarokka:
		if not _cards_read.has(str(k)):
			return
	_reading_told = true
	Campaign.module().reading_finished(st)


## `heal <dice> [party] [temp]`: one roll of `dice` heals the speaking hero, or with `party` every hero who isn't dead;
## with `temp` the part past a hero's Hit Point maximum becomes Temporary Hit Points. Returns the notice, or "".
func _heal(s: Dictionary) -> String:
	var who := _receivers(bool(s["party"]))
	if who.is_empty():
		return ""
	var amount := int(dice.roll_expr(str(s["dice"]), "Healing")["total"])
	var regained := 0
	var temp := 0
	for ch in who:
		var healed := ch.heal(amount, "Healing")
		regained = maxi(regained, healed)
		if bool(s["temp"]) and healed < amount and ch.add_temp_hp(amount - healed, "Healing"):
			temp += 1
	if regained == 0 and temp == 0:
		return ""
	var lead := ("Each hero regains %d Hit Points" % amount) if bool(s["party"]) else ("%s regains %d Hit Points" % [_first(who[0]), amount])
	return lead + (" (the rest as Temporary Hit Points)" if temp > 0 else "")


## Who a story's gift goes to: the hero in the conversation, or with `party` every hero who isn't dead.
func _receivers(party: bool, failed: bool = false) -> Array[Character]:
	if failed:
		return _failed_save.filter(func(ch: Character) -> bool: return not ch.dead)
	if party:
		return _living()
	var out: Array[Character] = []
	if speaker != null and not speaker.dead:
		out.append(speaker)
	return out


## `damage <dice> <type> [party]`: one roll of damage to the hero in the conversation or every living hero, through
## their Resistances and Immunities, taken from Temporary Hit Points first. It never drops a hero below 1 Hit Point: out
## of a fight nothing would make their Death Saving Throws, so a story's hurt wounds but never fells. Returns the
## notice, or "".
func _damage(s: Dictionary) -> String:
	var who := _receivers(bool(s["party"]), bool(s.get("failed", false)))
	if who.is_empty():
		return ""
	var rolled := int(dice.roll_expr(str(s["dice"]), "Damage")["total"])
	var kind := str(s["type"])
	var hurt: Array[String] = []
	for ch in who:
		var r := ch.preview_damage_parts([{"amount": rolled, "type": kind}])
		var dealt := mini(r.final, maxi(0, ch.hp + ch.temp_hp - 1))
		if dealt <= 0:
			continue
		var absorbed := mini(ch.temp_hp, dealt)
		ch.temp_hp -= absorbed
		ch.hp -= dealt - absorbed
		hurt.append(_first(ch))
	if hurt.is_empty():
		return ""
	var what := "%d %s damage" % [rolled, kind.capitalize()]
	return ("Each hero takes %s" % what) if bool(s["party"]) and hurt.size() == who.size() else "%s %s %s" % [_names(hurt), "takes" if hurt.size() == 1 else "take", what]


## `hit_dice restore <n|all> [party]` gives back spent Hit Point Dice (the biggest first, never past a hero's own);
## `hit_dice grant <n> [party]` gives Hit Point Dice of the hero's biggest kind beyond them, kept until their next
## Long Rest. Returns the notice, or "".
func _hit_dice(s: Dictionary) -> String:
	var n := int(s["count"])
	var got: Array[String] = []
	for ch in _receivers(bool(s["party"])):
		var pool := ch.hit_dice()
		var dies := pool.keys()
		dies.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) > int(b))
		if dies.is_empty():
			continue
		var moved := 0
		if str(s["how"]) == "grant":
			var top := str(dies[0])
			ch.hit_dice_spent[top] = int(ch.hit_dice_spent.get(top, 0)) - n
			moved = n
		else:
			for die: Variant in dies:
				var spent := int(ch.hit_dice_spent.get(str(die), 0))
				var back := spent if n < 0 else mini(spent, n - moved)
				if back <= 0:
					continue
				ch.hit_dice_spent[str(die)] = spent - back
				moved += back
		if moved > 0:
			got.append(_first(ch))
	if got.is_empty():
		return ""
	var count := "their spent Hit Point Dice" if n < 0 else ("%d Hit Point Di%s" % [n, "e" if n == 1 else "ce"])
	return "%s %s %s" % [_names(got), ("regains" if got.size() == 1 else "regain") if str(s["how"]) == "restore" else ("gains" if got.size() == 1 else "gain"), count]


## `temp_hp <dice> [party]`: one roll of Temporary Hit Points for the hero in the conversation or every living hero (a
## hero who already has more keeps theirs). Returns the notice, or "".
func _temp_hp(s: Dictionary) -> String:
	var who := _receivers(bool(s["party"]))
	if who.is_empty():
		return ""
	var amount := int(dice.roll_expr(str(s["dice"]), "Temporary Hit Points")["total"])
	var got: Array[String] = []
	for ch in who:
		if ch.add_temp_hp(amount, "Temporary Hit Points"):
			got.append(_first(ch))
	if got.is_empty():
		return ""
	return ("Each hero gains %d Temporary Hit Points" % amount) if got.size() == who.size() and bool(s["party"]) \
		else "%s %s %d Temporary Hit Points" % [_names(got), "gains" if got.size() == 1 else "gain", amount]


## `bless [party] [<n>m|<n>h]`: Bless's own bonus on the hero in the conversation or every living hero, for that long,
## with no Concentration to keep (StoryBoons.spell_boon). Returns the notice, or "".
func _bless(s: Dictionary) -> String:
	var got: Array[String] = []
	for ch in _receivers(bool(s["party"])):
		if StoryBoons.spell_boon(ch, "bless", int(s["minutes"])):
			got.append(_first(ch))
	if got.is_empty():
		return ""
	var minutes := int(s["minutes"])
	var span := ("%d hour%s" % [roundi(minutes / 60.0), "" if minutes == 60 else "s"]) if minutes % 60 == 0 \
		else "%d minute%s" % [minutes, "" if minutes == 1 else "s"]
	return "%s %s blessed for %s" % [_names(got), "is" if got.size() == 1 else "are", span]


## `inspiration [party]`: Heroic Inspiration for the hero in the conversation or every living hero who lacks it.
## Returns the notice, or "".
func _inspiration(party: bool) -> String:
	var got: Array[String] = []
	for ch in _receivers(party):
		if not ch.heroic_inspiration:
			ch.heroic_inspiration = true
			got.append(_first(ch))
	return "" if got.is_empty() else "%s %s Heroic Inspiration" % [_names(got), "gains" if got.size() == 1 else "gain"]


## "Ada", "Ada and Bo", "Ada, Bo and Cy".
static func _names(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, -1)), names[-1]]


func _end_beat() -> Dictionary:
	var beat := {"kind": "end", "combat": combat, "end_game": ended_game}
	if not move_to.is_empty():
		beat["move"] = move_to
	return beat


func _living() -> Array[Character]:
	var out: Array[Character] = []
	for ch in st.party:
		if not ch.dead:
			out.append(ch)
	return out


func _pick_beat() -> Dictionary:
	var names: Array[String] = []
	for ch in _living():
		names.append(ch.name)
	var text := "Choose who it will be. They will not come back." if _pick_purpose == "sacrifice" \
		else "Whose fate will the cards read anew? (They return to level 1 and are built again; they keep their belongings.)"
	# A pick that closes someone's quest wears F4's broken seal on that name: a dark gift on Liriel ends Carry the Dawn,
	# and whoever the altar takes leaves their own quest unfinished.
	var term := {"dark_gift": "gifted", "sacrifice": "fallen"}.get(_pick_purpose, "") as String
	var ends: Array = []
	for ch in _living():
		ends.append(QuestClosures.closed_by_pick(st, ch, term) if term != "" else [] as Array[String])
	if _pick_purpose == "dark_gift":
		var g := Compendium.shared().get_entry("dark_gifts", _gift)
		text = "Who accepts %s? %s It can never be given back." % [g.get("name", _gift), g.get("summary", "")]
		names.append("No one")
	else:
		names.append(BACK_OUT[_pick_purpose])   # every picker has a way back (owner, 2026-10-08)
	ends.append([] as Array[String])
	return {"kind": "pick_member", "text": text, "members": names, "purpose": _pick_purpose, "ends": ends}


## Answers a `pick_member` beat: the `i`th living party member is the one (sacrificed, rebuilt or given the gift).
## The option after them backs out: no one is picked, `check.last` is false and the conversation goes on, so the
## dialogue can return to its menu. Picking someone sets `check.last` true.
func pick_member(i: int) -> Dictionary:
	var living := _living()
	if _picking and _pick_purpose == "dark_gift" and i == living.size():
		_picking = false
		st.set_flag("refused_" + _gift, true)
		return {"kind": "notice", "text": "No one takes it."}
	if _picking and i == living.size():
		_picking = false
		st.last_check = false
		return next()
	if not _picking or i < 0 or i >= living.size():
		return next()
	_picking = false
	st.last_check = true
	var ch := living[i]
	if _pick_purpose == "dark_gift":
		ch.accept_dark_gift(_gift)
		return {"kind": "notice", "text": "%s accepts %s." % [ch.name, Compendium.shared().display_name("dark_gifts", _gift)]}
	if _pick_purpose == "respec":
		return {"kind": "respec", "index": st.party.find(ch), "name": ch.name}
	st.lose_member(ch, "gave their life on the altar beneath Death House")
	speaker = st.leader_character()
	return {"kind": "notice", "text": "%s is gone." % ch.name}


## Picks option `i` of the current menu. Returns the check beat for skill-check options, otherwise the next beat.
func choose(i: int) -> Dictionary:
	if i < 0 or i >= _options.size():
		return next()
	var opt := _options[i]
	if not bool(opt["enabled"]):
		return _options_beat()
	_options.clear()
	var who := opt["who"] as Character
	if who != null:
		speaker = who
	var check := opt["check"] as Dictionary
	if not check.is_empty():
		return _check(speaker, str(check["skill"]), int(check["dc"]), str(opt["text"]), func(beat: Dictionary) -> Dictionary:
			_check_jumps = [str(opt["ok"]), str(opt["fail"])]
			_pending_jump = str(opt["ok"]) if bool(beat["success"]) or str(opt["fail"]) == "" else str(opt["fail"])
			_pay_check(beat, str(opt["xp_key"]))
			# Owner rule (2026-10-06): a failed Persuasion, Intimidation, Deception, Performance or Insight attempt is
			# spent; the option doesn't come back (they won't fall for it twice, and a read face doesn't change).
			_last_option_key = _spent_key(str(opt["text"])) if _social(str(check["skill"])) else ""
			if _last_option_key != "" and not bool(beat["success"]):
				st.flags[_last_option_key] = true
			return beat, str(check.get("edge", "")))
	_pending_jump = str(opt["ok"])
	return next()


## Skills whose failed attempt can't be repeated (owner, 2026-10-06): talking someone round, and reading them.
const SOCIAL_SKILLS: Array[String] = ["persuasion", "intimidation", "deception", "performance", "insight"]


static func _social(skill: String) -> bool:
	return skill.to_lower().replace(" ", "_") in SOCIAL_SKILLS


## Where a failed social attempt is remembered: an internal flag per conversation node and option (saved).
func _spent_key(option_text: String) -> String:
	return "_failed/%s:%s:%s" % [file.key if file != null else "", node, option_text]


func _collect_options() -> void:
	_options.clear()
	var list := _stmts()
	while pc < list.size():
		var s := list[pc]
		var t := str(s["t"])
		if t == "option":
			pc += 1
			if not StoryConditions.check(str(s["cond"]), st):
				continue
			var spent_check := s["check"] as Dictionary
			if not spent_check.is_empty() and _social(str(spent_check["skill"])) and st.flags.has(_spent_key(str(s["text"]))):
				continue
			var who: Character = null
			if str(s["selector"]) != "":
				who = st.find_member(str(s["selector"]))
				if who == null:
					continue
			var check := s["check"] as Dictionary
			var info := _check_info(who if who != null else speaker, check)
			var tags := ""
			for tag: String in s["tags"]:
				tags += "[%s] " % tag
			var edge_word := {"adv": ", Advantage", "dis": ", Disadvantage"}.get(str(check.get("edge", "")), "") as String
			var label := "%s%s" % ["[%s DC %d%s] " % [str(check["skill"]).replace("_", " ").capitalize(), int(check["dc"]), edge_word] if not check.is_empty() else "", tags]
			# A purchase: an option whose node starts by paying is greyed out when the purse can't cover it.
			var price := _price_of(str(s["ok"]))
			var enabled := price <= 0.0 or st.gold >= price
			if not enabled:
				label = (label + " [%d gp]" % roundi(price)).strip_edges()
			_options.append({"text": str(s["text"]), "label": label.strip_edges(), "ok": str(s["ok"]), "fail": str(s["fail"]),
				"check": check, "check_info": info, "who": who, "enabled": enabled,
				"reason": "" if enabled else "Not enough gold", "ends": _ends_names(s),
				"xp_key": "%s:%s:%d" % [file.key, node, int(s["n"])]})
		elif t in ["if", "elif", "else", "endif"]:
			if t == "if":
				if StoryConditions.check(str(s["cond"]), st):
					pc += 1
				else:
					_skip_branch()
			elif t == "endif":
				pc += 1
			else:
				_skip_to_endif()
		else:
			break


## The names of the quests choosing this option closes, for the menu's mark (`[ends:<quest>]`, F4 of the Side Quest
## Failure Plan): each tag's condition has to hold now, and a quest that has already ended has nothing left to close.
func _ends_names(opt: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e: Variant in opt.get("ends", []) as Array:
		var tag := e as Dictionary
		var id := str(tag["quest"])
		if str(tag["cond"]) != "" and not StoryConditions.check(str(tag["cond"]), st):
			continue
		if st.quest_ended(id):
			continue
		var entry := Compendium.shared().get_entry("quests", id)
		if not entry.is_empty():
			out.append(str(entry.get("name", id)))
	return out


## An option's check as the menu shows it: who rolls, their bonus and the chance.
func _check_info(shown: Character, check: Dictionary) -> Dictionary:
	if check.is_empty() or shown == null:
		return {}
	var bonus := _bonus(shown, str(check["skill"]))
	var dc := int(check["dc"])
	return {"skill": str(check["skill"]), "dc": dc, "bonus": bonus,
		"chance": clampf((21.0 - (dc - bonus)) / 20.0, 0.05, 1.0), "who": shown.name}


## Q13: the player picks who speaks for the party. Party lines and the menu's checks (those no tag gives to someone
## else) go to them, and the options on screen show their bonus and chance.
func set_speaker(who: Character) -> void:
	if who == null or who.dead:
		return
	speaker = who
	for o in _options:
		if o["who"] == null:
			o["check_info"] = _check_info(who, o["check"] as Dictionary)


## What going to `ref` costs: the gold paid by its first statements (before any line or option), or 0.
func _price_of(ref: String) -> float:
	if ref == "END" or ref.contains(":"):
		return 0.0
	var list := file.nodes.get(ref, []) as Array
	for st_: Variant in list:
		var d := st_ as Dictionary
		match str(d["t"]):
			"gold":
				return maxf(0.0, -float(d["amount"]))
			"set", "give", "take", "quest", "attitude":
				continue
		break
	return 0.0


## Whether every option on the menu closes the same quests (two or more options): the menu is a beat, not a choice.
func _uniform_menu() -> bool:
	if _options.size() < 2 or (_options[0]["ends"] as Array).is_empty():
		return false
	for o in _options:
		if (o["ends"] as Array) != (_options[0]["ends"] as Array):
			return false
	return true


func _options_beat() -> Dictionary:
	var out: Array[Dictionary] = []
	var beat_only := not MARK_UNIFORM_MENUS and _uniform_menu()
	for o in _options:
		out.append({"text": o["text"], "label": o["label"], "check": o["check_info"], "enabled": o["enabled"],
			"reason": o["reason"], "ends": [] as Array[String] if beat_only else o["ends"],
			"who": (o["who"] as Character).name if o["who"] != null else ""})
	return {"kind": "options", "options": out}


## From a false `if` (or `elif`): moves to the next branch that holds, or past the matching endif.
func _skip_branch() -> void:
	var list := _stmts()
	var depth := 0
	var j := pc + 1
	while j < list.size():
		var t := str(list[j]["t"])
		if t == "if":
			depth += 1
		elif t == "endif":
			if depth == 0:
				pc = j + 1
				return
			depth -= 1
		elif depth == 0 and t == "elif":
			if StoryConditions.check(str(list[j]["cond"]), st):
				pc = j + 1
				return
		elif depth == 0 and t == "else":
			pc = j + 1
			return
		j += 1
	pc = list.size()


func _skip_to_endif() -> void:
	var list := _stmts()
	var depth := 0
	var j := pc + 1
	while j < list.size():
		var t := str(list[j]["t"])
		if t == "if":
			depth += 1
		elif t == "endif":
			if depth == 0:
				pc = j + 1
				return
			depth -= 1
		j += 1
	pc = list.size()


func _apply_set(s: Dictionary) -> void:
	var flag := str(s["flag"])
	var value: Variant = s["value"]
	match str(s["op"]):
		"+=":
			st.set_flag(flag, float(st.get_flag(flag, 0)) + float(value) if value is float else int(st.get_flag(flag, 0)) + int(value))
		"-=":
			st.set_flag(flag, int(st.get_flag(flag, 0)) - int(value))
		_:
			if value is String and value == "now":
				st.set_flag(flag, st.total_minutes())   # `set flag = now` stamps the game minute, for `days_since.flag`
			else:
				st.set_flag(flag, value)


func _line_beat(speaker_name: String, mood: String, text: String) -> Dictionary:
	var low := speaker_name.to_lower()
	if low == "narrator":
		return {"kind": "line", "speaker_id": "narrator", "name": "Narrator", "portrait": NARRATOR_PORTRAIT, "mood": "", "text": _fill(text),
			"narrator": true, "party": false}
	if low == "player":
		return _party_line(speaker, text)
	var npc := _npc_for(low)
	var nid := str(npc.get("id", low))
	var face := _face_of(npc)
	var portrait := NpcLooks.portrait(face, st) if not face.is_empty() else nid   # Rictavio becomes Van Richten
	if mood != "" and mood != "neutral" and ResourceLoader.exists("res://art/portraits/%s_%s.png" % [portrait, mood]):
		portrait = "%s_%s" % [portrait, mood]
	return {"kind": "line", "speaker_id": nid, "name": str(npc.get("name", speaker_name)), "portrait": portrait, "mood": mood,
		"text": _fill(text), "narrator": false, "party": false}


func _party_line(who: Character, text: String) -> Dictionary:
	if who == null:
		return {"kind": "line", "speaker_id": "player", "name": "You", "portrait": "", "mood": "", "text": _fill(text), "narrator": false, "party": true}
	return {"kind": "line", "speaker_id": who.id, "name": who.name, "portrait": portrait_of(who), "mood": "",
		"text": _fill(text), "narrator": false, "party": true}


## A party member's portrait (art/portraits/<id>.png): the look picked in the creator, else one named after them.
static func portrait_of(who: Character) -> String:
	var look := str((who.build.get("appearance", {}) as Dictionary).get("art", ""))
	return look if look != "" else Character.id_for_name(who.name)


## Whose face a speaker's line shows: the one being spoken to when they share the speaker's name, else the speaker.
## Every Belview says "Belview:" in one voice, but the sweeper wears the sweeper's portrait (owner, 2026-10-13).
func _face_of(npc: Dictionary) -> Dictionary:
	if npc_id == "" or npc.is_empty() or str(npc.get("id", "")) == npc_id:
		return npc
	var spoken_to := Compendium.shared().get_entry("npcs", npc_id)
	if not spoken_to.is_empty() and str(spoken_to.get("name", "")) == str(npc.get("name", "")):
		return spoken_to
	return npc


static func _npc_for(low: String) -> Dictionary:
	var comp := Compendium.shared()
	var direct := comp.get_entry("npcs", low.replace(" ", "_"))
	if not direct.is_empty():
		return direct
	# Of the NPCs a name fits, the one with the lowest id: all() sorts by name only, so which of two "A Pale Courtier"s
	# came first was luck, and tools/audio/voice_lines.py voices a line under the lowest id (the order of the files),
	# so a line spoken as the other one found no clip and stayed silent.
	var best := {}
	for n in comp.all("npcs"):
		var name := str(n.get("name", "")).to_lower()
		if (name == low or name.get_slice(" ", 0) == low) and (best.is_empty() or str(n.get("id", "")) < str(best.get("id", ""))):
			best = n
	return best


func _fill(text: String) -> String:
	var who := speaker if speaker != null else st.leader_character()
	return text.replace("{name}", _first(who)).replace("{leader}", _first(st.leader_character()))


static func _first(ch: Character) -> String:
	return ch.name.get_slice(" ", 0) if ch != null else "you"


static func _skill_key(skill: String) -> StringName:
	if ABILITIES.has(skill):
		return ABILITIES[skill] as StringName
	return StringName(skill)


## `exhaust <+n|-n> [party|failed]`: levels of Exhaustion gained (through immunity's refusal) or lost, by the hero in the
## conversation, every living hero, or those who failed the last party save. Returns the notice, or "".
func _exhaust(s: Dictionary) -> String:
	var n := int(s["levels"])
	var got: Array[String] = []
	for ch in _receivers(bool(s["party"]), bool(s.get("failed", false))):
		var before := ch.exhaustion
		if n > 0:
			ch.add_exhaustion(n)
		else:
			ch.exhaustion = maxi(0, ch.exhaustion + n)
		if ch.exhaustion != before:
			got.append(_first(ch))
	if got.is_empty():
		return ""
	var amount := absi(n)
	return "%s %s %d level%s of Exhaustion" % [_names(got), ("gains" if n > 0 else "loses") if got.size() == 1 else ("gain" if n > 0 else "lose"),
		amount, "" if amount == 1 else "s"]


## `condition <Condition> <minutes> [party|failed]`: the condition on the hero in the conversation, every living hero or
## those who failed the last party save, for that many minutes of the clock (immunities turn it away). Returns the notice.
func _timed_condition(s: Dictionary) -> String:
	var cond := StringName(str(s["condition"]))
	var got: Array[String] = []
	for ch in _receivers(bool(s["party"]), bool(s.get("failed", false))):
		var fx := Effect.new(str(cond).capitalize(), &"story", "story_condition").with_condition(cond)
		fx.ends = Effect.Ends.MINUTES
		fx.minutes_left = int(s["minutes"])
		if ch.add_effect(fx) and ch.has_condition(cond):
			got.append(_first(ch))
	if got.is_empty():
		return ""
	var mins := int(s["minutes"])
	var span := ("%d hour%s" % [mins / 60, "" if mins == 60 else "s"]) if mins % 60 == 0 else "%d minutes" % mins
	return "%s %s %s for %s" % [_names(got), "is" if got.size() == 1 else "are", str(cond).capitalize(), span]


## `save <Ability> DC <n> party [unless resists <type>]`: every living hero makes the saving throw (one with Resistance
## or Immunity to that damage type passes untouched: fire resistance through a burning door); check.last is whether all
## of them saved, and those who failed are the `failed` receivers of the lines after it. Returns the notice naming each roll.
func _party_save(s: Dictionary) -> String:
	var ab := ABILITIES[str(s["ability"])] as StringName
	var dc := int(s["dc"])
	_failed_save.clear()
	var said: Array[String] = []
	var resists := StringName(str(s.get("resists", "")))
	for ch in _living():
		if resists != &"" and (ch.resistance_source(resists) != "" or ch.immunity_source(resists) != ""):
			said.append("%s passes (%s Resistance)" % [_first(ch), str(resists).capitalize()])
			continue
		var t := ch.roll_save(dice, ab, dc)
		if not t.success:
			_failed_save.append(ch)
		said.append("%s %d%s" % [_first(ch), t.total, "" if t.success else " (fails)"])
	st.last_check = _failed_save.is_empty()
	return "%s save, DC %d: %s." % [Creature.ABILITY_NAMES[ab], dc, ", ".join(said)]


## The weapon attack a dialogue check names (`ranged_attack`, `melee_attack`: a dart thrown at a board, a swing at a
## post): `ch`'s best such attack, or null for any other skill.
static func attack_for(ch: Character, skill: String) -> WeaponProfile:
	if not skill in ["ranged_attack", "melee_attack"]:
		return null
	var best: WeaponProfile = null
	for p in ch.attacks():
		var fits := (not p.melee or p.thrown) if skill == "ranged_attack" else p.melee
		if fits and (best == null or p.attack.total() > best.attack.total()):
			best = p
	return best


## A hero with no such weapon throws or swings what comes to hand: the ability modifier alone (no Proficiency Bonus).
static func _improvised(ch: Character, skill: String) -> Breakdown:
	var ab := &"dex" if skill == "ranged_attack" else &"str"
	var b := Breakdown.new("Attack")
	b.add("%s modifier (improvised)" % Creature.ABILITY_SHORT[ab], ch.ability_mod(ab))
	return b


static func _bonus(ch: Character, skill: String) -> int:
	if skill in ["ranged_attack", "melee_attack"]:
		var p := attack_for(ch, skill)
		return p.attack.total() if p != null else _improvised(ch, skill).total()
	var key := _skill_key(skill)
	if Abilities.SKILLS.has(key):
		return ch.skill_bonus(key).total()
	return ch.ability_check_bonus(key).total()


## `cast <spell>`: the one speaking for the party casts an exploring spell in the scene (FieldCasting.cast_utility: as
## a Ritual when it is one, else a feature's free casting or their lowest slot), or, if they can't, whoever in the party
## can; they speak for the party after it. check.last says whether it worked, and the notice says what it cost or why
## not. A casting still running (cast from the character sheet a few minutes ago) needs no new one.
func _cast(spell_id: String) -> String:
	if st.spell_active(spell_id):
		st.last_check = true
		return ""
	var data := Compendium.shared().spell_data(spell_id)
	var casters: Array[Character] = []
	if speaker != null:
		casters.append(speaker)
	for ch in st.party:
		if not ch in casters:
			casters.append(ch)
	var why := ""
	for ch in casters:
		if not ch.known_spells().any(func(k: Dictionary) -> bool: return str(k["id"]) == spell_id):
			continue
		var res := FieldCasting.cast_utility(st, ch, spell_id, bool(data.get("ritual", false)))
		if bool(res["ok"]):
			st.last_check = true
			speaker = ch
			return str(res["text"])
		if why == "":
			why = "%s can't cast %s: %s." % [_first(ch), str(data.get("name", spell_id)), str(res["text"]).trim_suffix(".")]
	st.last_check = false
	return why if why != "" else "Nobody here can cast %s." % str(data.get("name", spell_id))


## `reveal <prop>`: a hidden find (a search prop, docs/story/found_magic_items.md) shows itself, as if the party had
## searched it out: someone told them where to look (a Tip). Its label, or "" if it was already found or doesn't exist.
func _reveal(prop_id: String) -> String:
	var where := ""
	var label := ""
	var trap := false
	var ids: Array[String] = [st.location]
	for loc: Dictionary in Compendium.shared().all("locations"):
		if str(loc.get("id", "")) != st.location:
			ids.append(str(loc.get("id", "")))
	for loc_id in ids:
		var loc := Compendium.shared().get_entry("locations", loc_id)
		for p: Variant in loc.get("props", []):
			var prop := p as Dictionary
			if str(prop["id"]) == prop_id and str(prop.get("kind", "")) == "search":
				where = loc_id
				label = str(prop.get("label", "something"))
				break
		if where != "":
			break
		# A trap someone warned of shows as found, as a successful search would show it.
		for t: Variant in loc.get("traps", []):
			if str((t as Dictionary)["id"]) == prop_id:
				where = loc_id
				label = str((t as Dictionary).get("label", "a trap"))
				trap = true
				break
		if where != "":
			break
	if where == "":
		return ""
	if trap:
		var traps := st.loc_state(where)["traps"] as Dictionary
		if traps.has(prop_id):
			return ""
		traps[prop_id] = "found"
		return label
	var found := st.loc_state(where)["found"] as Dictionary
	if bool(found.get(prop_id, false)):
		return ""
	found[prop_id] = true
	return label


func _best_for(skill: String) -> Character:
	var best: Character = null
	for ch in st.party:
		if ch.hp <= 0:
			continue
		if best == null or _bonus(ch, skill) > _bonus(best, skill):
			best = ch
	return best if best != null else speaker


## A check about to be rolled: Guidance first when someone could cast it and the screen asks (offer_guidance), as a
## `guidance` beat that answer_guidance() follows up; otherwise it's rolled now, with Guidance from a caster whose rule
## is Automatic. `then` takes the check's beat, does what follows the roll (the branch to take) and returns the beat.
## `edge`: the check's own "adv" or "dis" (`[Persuasion DC 12 adv]`), or "".
func _check(who: Character, skill: String, dc: int, said: String, then: Callable, edge: String = "") -> Dictionary:
	var extra: Array = []
	if offer_guidance and who != null and not skill in ["ranged_attack", "melee_attack"]:   # Guidance is for checks
		var offer := GuidanceOffer.offer(st, who, _skill_key(skill), dc)
		if GuidanceOffer.asks(offer):
			_guidance_wait = {"offer": offer, "who": who, "skill": skill, "dc": dc, "said": said, "then": then, "edge": edge}
			return {"kind": "guidance", "offer": offer}
		extra = GuidanceOffer.automatic(offer)
	return then.call(_roll(who, skill, dc, said, extra, edge))


## The Guidance prompt's answer: the offer's caster `index` casts it (-1: nobody), and `rule` is the casters' answer
## from now on (GuidanceOffer.answer). Rolls the waiting check and returns its beat.
func answer_guidance(index: int, rule: String = "") -> Dictionary:
	if _guidance_wait.is_empty():
		return next()
	var w := _guidance_wait
	_guidance_wait = {}
	var extra := GuidanceOffer.answer(w["offer"] as Dictionary, index, rule)
	return (w["then"] as Callable).call(_roll(w["who"] as Character, str(w["skill"]), int(w["dc"]), str(w["said"]), extra, str(w.get("edge", ""))))


## `edge`: the check's own Advantage ("adv") or Disadvantage ("dis"); the story's granted ones (CheckEdges) count too.
func _roll(who: Character, skill: String, dc: int, said: String, extra: Array = [], edge: String = "") -> Dictionary:
	if who == null:
		st.last_check = false
		return {"kind": "check", "who": "Nobody", "skill": skill, "dc": dc, "total": 0, "success": false, "detail": "", "said": said}
	var adv := CheckAids.before_check(who, _skill_key(skill))
	var dis: Array[String] = []
	var granted := CheckEdges.take(st, skill)
	adv.append_array(granted["adv"] as Array[String])
	dis.append_array(granted["dis"] as Array[String])
	if edge == "adv":
		adv.append("The moment favours it")
	elif edge == "dis":
		dis.append("The odds are against it")
	var test: D20Test
	var weapon := attack_for(who, skill)
	if skill in ["ranged_attack", "melee_attack"]:
		# An attack roll against the DC (a target's AC), with the hero's best such weapon (or an improvised throw).
		var bonus := weapon.attack if weapon != null else _improvised(who, skill)
		var keys: Array[String] = ["attack", "attack:ranged" if skill == "ranged_attack" else "attack:melee"]
		test = who.roll_d20(dice, D20Test.Kind.ATTACK_ROLL, bonus, dc, keys, adv, dis, "")
	else:
		test = who.roll_check(dice, _skill_key(skill), dc, adv, dis, "", [], extra)
	st.last_check = test.success
	_last_check = {"who": who, "test": test, "skill": skill, "said": said}
	return _check_beat()


## The beat for the last check, with what the roller could still spend on it (CheckAids).
func _check_beat() -> Dictionary:
	var who := _last_check["who"] as Character
	var test := _last_check["test"] as D20Test
	var parts: Array = []
	if test.breakdown != null:
		for part: Dictionary in test.breakdown.parts:
			parts.append({"label": str(part["label"]), "value": int(part["value"])})
	return {"kind": "check", "who": who.name, "portrait": portrait_of(who),
		"skill": str(_last_check["skill"]).replace("_", " ").capitalize(), "dc": test.target, "total": test.total, "success": test.success, "detail": test.describe(), "said": str(_last_check["said"]),
		"aids": CheckAids.options(who, test),
		# The dice themselves, for the big d20 (G11): both dice under Advantage or Disadvantage, the one kept, the bonuses.
		"rolls": test.rolls.duplicate(), "kept": test.kept, "modifier": test.modifier, "parts": parts, "extra": test.extra,
		"extra_label": test.extra_label, "advantage": test.advantage, "disadvantage": test.disadvantage,
		"auto_failed": test.auto_failed,
		# What was rolled again and what was added after the first throw, for the big d20 to show in turn (D20Test).
		"rerolls": test.rerolls.duplicate(true), "added": test.added.duplicate(true)}


## XP levelling (story/xp.gd): a check passed is worth a little, once for each line that asks it (`key`: file:node:line).
## The beat carries what it earned for the screen to show (Xp.tag); failures give nothing.
func _pay_check(beat: Dictionary, key: String) -> void:
	_xp_key = key
	if bool(beat["success"]):
		var n := Xp.award(st, "check", key)
		if n > 0:
			beat["xp"] = n


## The key of the check just rolled, for an aid that turns it into a success (use_aid).
var _xp_key := ""


## Spends an aid on the last (failed) check: Heroic Inspiration or Tactical Mind. The branch follows the new result.
func use_aid(id: String) -> Dictionary:
	if _last_check.is_empty():
		return next()
	var test := CheckAids.apply(id, _last_check["who"] as Character, _last_check["test"] as D20Test, dice)
	st.last_check = test.success
	if test.success and _last_option_key != "":
		st.flags.erase(_last_option_key)
	if _check_jumps.size() == 2:
		_pending_jump = str(_check_jumps[0]) if test.success or str(_check_jumps[1]) == "" else str(_check_jumps[1])
	var beat := _check_beat()
	_pay_check(beat, _xp_key)   # the aid turned a failure round
	return beat
