# Narration and dialogue: the craft

How Curse of Strahd's Narrator and dialogue were written, split into what any game on this engine can keep (the
craft) and what was Barovia's own (the voice). Written 2026-10-29 from the game's voice guide
(`docs/voice/narrator.md`, copied to [reference/voice/narrator.md](../reference/voice/narrator.md)), its casting sheet
and voice bibles, the drafting records under its `docs/plans/gemini_*/` and `docs/story/`, and the principles
(Parts 1.3, 6 and 9 of [game_design_principles.md](game_design_principles.md)). The file format is
[reference/contracts/dialogue.md](../reference/contracts/dialogue.md); the drafting pipeline is
[handbook/pipelines.md](../handbook/pipelines.md) section 7.

## 1. What the Narrator is for

The Narrator is the game's unseen storyteller, in the manner of Baldur's Gate 3's: a voice that speaks for the world
when the party arrives somewhere, looks at something, finds something, rolls, rests, fights, or loses someone. It is
part of a pillar ("Fully voiced"), so it is everywhere: Curse of Strahd's Narrator has close to 7,000 voiced lines,
nearly four in every ten lines the game speaks.

**Decide the Narrator's persona first, before any content**, in one short paragraph: who the storyteller is, how they
feel about the party, what they never do. Barovia's is in section 4; a new world writes its own.

## 2. The craft: rules every Narrator line follows (reusable)

1. **Second person, present tense.** "You step inside." Never "the party steps inside", never the past tense. A line
   about one hero uses `{name}`: "{name} catches the glint first."
2. **One or two sentences.** The second is usually the turn: the irony, the dread, the joke.
3. **The world can be cruel; the Narrator isn't.** Laugh at the place, the dark, the situation, never at the player
   for a bad roll or a death. **Respect the dead**: wry about a corpse's furniture, never about the corpse.
4. **No facts the party hasn't earned.** Describe what the characters can perceive; hidden things come only with a
   passed check or a discovery.
5. **No modern slang, no winks at the player, no game terms** ("HP", "roll", "level"). A result is what happened in the
   world: "your fingers find the catch", never "you passed". Never comment on game systems, saves, menus or the
   player's real-world choices.
6. **Concrete senses over adjectives.** A smell, a sound, a temperature. "Cold" is a word; "your breath fogs indoors"
   is a scene.
7. **Tone follows the place.** The most frightening places get the thinnest humour and some lines with no joke at all.
   Silence is a tool.
8. **Combat is fast.** One sentence, under 15 words, rare (a cooldown of 3 rounds or more).
9. **Variety.** Common triggers get two or more variants, and variants for who is acting (`[class:]`, `[species:]`,
   `[background:]`, `[tag:]`, `[name:]`). The engine prefers an eligible conditioned variant over a plain one, so
   condition only what is truly specific.
10. **Never tell the player what to feel** ("you are terrified"): show the cold and let them be terrified. Never
    "suddenly". Never repeat an NPC's line or explain a joke.

### What each trigger gets

| Trigger | Length | What the line does |
|---|---|---|
| `enter:<location>` | 1-2 sentences | First sight of a place: a mood and one detail worth walking toward. `once` for rooms, a `cooldown` for places re-entered, so story flags can change the line later |
| `enter:<area>` | 1-2 sentences | A room: one sensory detail, one hint of what to examine |
| `examine:<prop>` | 1-2 sentences | What the thing is, and what it implies; the second sentence is the payoff |
| `search:<prop>` | 1 sentence | The moment of finding the hidden thing |
| `check:<skill>:<prop>:success/failure` | 1 sentence | What the check showed, or failed to. A failure is never a dead end in the prose: the world was not kind this time |
| `trap:<id>:found/triggered` | 1 sentence | Found: the tell that gave it away. Triggered: the moment of impact, not the damage |
| `rest:short/long` | 1-2 sentences | The texture of resting somewhere unsafe |
| `combat:*` | 1 short sentence | A critical hit, a natural 1, a fall, a kill; no gloating |
| `death:<character>` | 2 sentences | Sincere; no joke |

## 3. The craft: everyone else's lines (reusable)

- **Every speaker has a voice bible** before any line is written: age, timbre, accent, rhythm, temperament; how they
  talk (sentence length, contractions, pet phrases and how often to use them, what they call the villain); what they
  want, what they fear, a secret never stated flatly; and ten or so of their existing lines to match. The same bible
  designs their recorded voice. Nobody's voice is cloned from a real person.
- **People worth talking to** (principles 6.4): everyone with lines has something unique, something they want and a
  secret; not everyone gives information (some don't know, are wrong, lie, refuse, or tell a joke that dies).
- **Comedy in its place**: recurring comic characters and running gags give the dread relief; the Narrator and the
  serious scenes stay straight.
- **The villain's tone is chosen once** and every writer follows it (Barovia's "velvet knife", principles 1.3).
- **Conversation rules** (principles 6.2): every conversation keeps an exit, failed social checks are spent, no menu
  hangs on a single social check, a failed check never locks a quest, the player picks who speaks, party members speak
  through interjections and banter while the player chooses every option.
- **Options are short and in the party's voice** (under about 12 words), work at any hour and in any state the scene
  can be in, and are never voiced.

## 4. Barovia's voice (the worked example, not the rule)

- **The persona:** an old gothic storyteller who has watched a great many adventurers walk into the valley and very few
  walk out. Neither the party's enemy nor its friend, fond of it "the way a gravedigger is fond of the weather: with
  interest, without illusions". Never gloats over a failure, never cheers a success. It notices.
- **The dial by place:** the haunted house, the abbey and the temple are "scary first", with the humour at its
  thinnest.
- **The recorded voice:** a mature woman's low alto with a refined English accent, precise diction, intimate and
  confiding, dryly witty, ominous but warm, slow with dramatic pauses. It stays on the voice model of its original lines,
  with no mood tags: the lines another model made sounded "horrible" next to them (owner, 2026-10-08). A long-running
  voice keeps its model.
- **Sample lines**, to set the register for a new world's own:
  - "The road narrows, the trees lean closer, and the fog behind you thickens like a door swinging shut."
  - "The hall smells of beeswax and old smoke. Somebody kept this house beautifully, right up until they didn't."
  - "Behind the third shelf, your fingers find a seam that the dust has been politely ignoring."
  - "The room keeps its secrets. It has had a great deal of practice." (a failed Perception check)
  - "You sit with your backs to the wall. The wall, to its credit, stays a wall." (a Short Rest)
  - "The blow lands like a verdict." (a critical hit)
  - "{name} is gone. The house does not mark it, but you will, every time you count to four." (a death)
- **The setting's speech:** locals with a strong, clearly audible Romanian accent; outsiders (the party) with their
  own. A new world picks its own accents and writes them into each bible and each line's direction tag.

For a new world, keep sections 2 and 3 as they are and replace this section: a new persona, a new dial, a new voice,
new samples.

## 5. How the lines were written (reusable method)

All new or rewritten dialogue and narration was drafted by a second model (Gemini, through the owner's own AI bridge
on his own subscription, never an API key; owner, 2026-10-18) and then edited by the lane. Mechanical fixes (typos,
flags, speaker ids) skip the draft. The method:

1. **Write a brief per batch.** It holds: what the game is, in one paragraph; the scene and what the conversation is
   for (and what it is not, such as "not a quest; nothing in it is a choice"); every node to fill, by name, with a line
   count and a length target (one line is 1-2 short sentences, under about 25 words); the option texts wanted; the
   speaker's voice bible and existing lines to match and not repeat; the canon limits (the names that may be used, no
   new people, places, monsters or history, no stage directions or placeholders); and the exact output format (the
   dialogue file's own `Speaker [mood]: Text` rows under `~ node` names, plain punctuation). Big jobs go as several
   short messages in one conversation, so the voice holds.
2. **Keep the brief and the raw reply** untouched beside the work, with a README listing each brief and what it asked.
3. **Edit the draft for canon, voice and length**, and record every edit in the README. What came up most: formal
   phrasing in a speaker who talks plainly (contractions restored); new facts, places or details the data doesn't have
   (cut); a line that assumed one state of the story in a scene that can be in several (sent back for a redraft); a
   repeated joke; option texts that didn't work at night or in every state; one long sentence split in two. In one
   batch about a third of the lines went in exactly as drafted.
4. **Lint it** (the dialogue lint and flag lint), and keep the new lines **unvoiced** until a voice job is quoted and
   approved. Add lines rather than editing voiced ones: a voiced line's clip is keyed by its text, so an edit throws
   the clip away.

Worked examples in the game repo (public): the companion check-in batch
[`docs/plans/gemini_allies/I1/`](https://github.com/ashwinmahesh/CurseOfStrahd/tree/main/docs/plans/gemini_allies/I1)
(a full brief and an edit log) and the crypts batch
[`docs/story/gemini_drafts/castle_crypts/`](https://github.com/ashwinmahesh/CurseOfStrahd/tree/main/docs/story/gemini_drafts/castle_crypts)
(an edit list slot by slot).
