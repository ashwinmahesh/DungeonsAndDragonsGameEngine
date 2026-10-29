# Start here

Everything the Curse of Strahd project learned that a new game on this engine needs: how the game was meant to play,
the design principles behind it, the HD-2D look and how to retheme it, how the agents ran the work (models and effort
included), what to test and when, how assets and releases are made, and what went wrong along the way. Written
2026-10-29, when Curse of Strahd was at game main `ef29e6278` and this engine at `6777c47`.

## Reading order for a new game

1. **[design/game_design_principles.md](design/game_design_principles.md)**: the rules the game was built on, each
   with why and a Barovia example, the open decisions, a new-world checklist and every owner decision by date.
2. **[design/how_it_plays.md](design/how_it_plays.md)**: the play loop and the feel targets in numbers.
3. **[handbook/new_game.md](handbook/new_game.md)**: what this engine gives you, what the game must bring, the host
   contract, the Barovia leftovers still hard-wired, and the first steps of a new game.
4. **[design/hd2d_look.md](design/hd2d_look.md)**: which parts of the look are in the engine, which are Barovia's, and
   the recipe for a new palette and a new vibe.
   **[design/narration.md](design/narration.md)**: the Narrator's rules and the craft of every line, split from
   Barovia's own voice, and how lines were drafted and edited.
5. **[handbook/orchestration.md](handbook/orchestration.md)**: the coordinator, threads, lanes and the builder; the
   plan-first protocol; models and effort; hand-offs; approvals; pausing and resuming; QA; Codex pull requests.
6. **[handbook/testing.md](handbook/testing.md)**: what to run while working, before a hand-off, per batch and before
   a release; what each guard catches; fight series and balance.
7. **[handbook/pipelines.md](handbook/pipelines.md)**: images, sprites, video animation, models, icons, voice,
   dialogue drafting, music, the wiki, releases and the site.
8. **[handbook/gotchas.md](handbook/gotchas.md)**: what bit us, and what to do instead.
9. **[handbook/claude_md_template.md](handbook/claude_md_template.md)**: the agent rules file to put at the root of
   the new game's repo.

## Reference

- **[reference/](reference/README.md)**: the engine's decision records, data contracts, art and UI guides, rules
  coverage and deviations, and the system plans, copied from the game.
- **[assets/THIRD_PARTY.md](assets/THIRD_PARTY.md)**: third-party assets in this repo and their licences.
- **[platforms/ios.md](platforms/ios.md)**: the iPhone and iPad port.
- **[../CLAUDE.md](../CLAUDE.md)**: the rules for agents working in this repo.

## Keeping this current

- A new standing decision by the owner goes into the principles document (its part and the dated appendix); an open
  question he answers moves out of its "Open decisions" table.
- A process change goes into the handbook page it changes; a new lesson into the gotchas.
- Engine decisions and contracts are still kept in the game repo's `docs/`; refresh the reference copy when they
  change, or move them here for good.
- Nothing secret, nothing about paid accounts: this repo is public.
