extends TestCase
## Bonded companions (story/companions.gd, EncounterSetup.bring_companions, `companion bond|release`): bonded to one
## hero in the story's flags, brought into a fight beside its hero on the party's side and played by the player.


func _st() -> StoryState:
	var st := StoryState.new()
	for id: String in ["hedda_ironvow", "thistle"]:
		var ch := TestChars.pregen(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	return st


func test_a_bond_is_kept_in_the_story_and_ends() -> void:
	var st := _st()
	var hero := st.party[1]
	Companions.bond(st, hero.id, "wolf", "Test Pup")
	assert_eq(Companions.of(st, hero.id), {"monster": "wolf", "name": "Test Pup"})
	assert_true(st.flags.has(Companions.KEY), "in the flags a save keeps")
	var mon := Companions.creature_for(st, hero.id)
	assert_eq(mon.name, "Test Pup")
	assert_eq(mon.id, "companion_" + hero.id)
	assert_true(Companions.release(st, hero.id))
	assert_true(Companions.of(st, hero.id).is_empty())
	assert_false(Companions.release(st, hero.id), "nothing left to release")


func test_it_joins_the_fight_beside_its_hero_for_the_player() -> void:
	var st := _st()
	var e := TestCombat.open_field(3)
	var a := e.add(st.party[0], &"party", Vector2i(2, 3))
	var b := e.add(st.party[1], &"party", Vector2i(5, 3))
	Companions.bond(st, st.party[1].id, "wolf", "Test Pup")
	var party: Array[Combatant] = [a, b]
	EncounterSetup.bring_companions(e, party, {st.party[1].id: Companions.creature_for(st, st.party[1].id)})
	var pup: Combatant = null
	for c in e.combatants:
		if c.has_meta("companion_of"):
			pup = c
	assert_true(pup != null, "it came")
	assert_eq(pup.side, &"party")
	assert_eq(pup.controller, &"player", "the player plays it")
	assert_eq(str(pup.get_meta("companion_of")), b.id, "its hero's")
	assert_true(e.distance(pup, b) <= 5, "beside its hero")


func test_a_conversation_bonds_and_releases() -> void:
	var st := _st()
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.file = DialogueFile.parse("~ start\ncompanion bond wolf Test Pup\n", "test/companion")
	r.start("start")
	r.speaker = st.party[0]
	var beat := r.next()
	assert_true(str(beat.get("text", "")).begins_with("Test Pup is bound to"), str(beat))
	assert_eq(str(Companions.of(st, st.party[0].id)["monster"]), "wolf")
	r.file = DialogueFile.parse("~ start\ncompanion release\n", "test/companion2")
	r.start("start")
	r.speaker = st.party[0]
	r.next()
	assert_true(Companions.of(st, st.party[0].id).is_empty())
