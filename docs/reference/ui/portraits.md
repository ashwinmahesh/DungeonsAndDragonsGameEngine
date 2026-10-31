# Portraits: the turn order, the party frames and the Bestiary

A creature's portrait is one picture in a gilt frame (`UiParts.framed_portrait`, `framed_portrait_of`, `framed_art`). Which
picture is `PortraitArt`'s question, answered from `art/portrait_sets.json` (the core's file, a game's merged over it by
`ArtPaths.json`).

## The key

`"photoreal": false` (the core's default) keeps what every game had: `art/portraits/<art id>.png`, an empty frame when there
is none, a Bestiary entry with the 132 px framed token art. A game that sets it `true` gets:

| For | Looked up in this order (each also tries a `.png` of the same name) |
|---|---|
| a monster (a foe or a neutral creature) | `<monster_dir>/<stat block id>.webp` (default `art/portraits/monsters`), then as a character |
| a character, a story ally, a custom hero | `<character_dir>/<art id>.webp` (default `art/portraits/characters`), then `art/portraits/<art id>.webp` |

- The **stat block id** is the data file's name (`data/monsters/<id>.json`), not the sprite's art id, so a variant
  (`wildpyre_large`) or a villain wearing another creature's sprite has its own portrait. A monster that borrows a hero's look
  (`look_of`, an echo) and the party's and guests' creatures are characters: `PortraitArt.monster_id_of`.
- The **art id** is `CombatToken.portrait_id`: a story ally's own look (`NpcLooks`), a pregen's id, a custom hero's registered
  look. It is the same id the old `art/portraits/<id>.png` has, so a game adds a better picture of a character beside the old
  one and only the chips that ask for it (the turn order, the party frames, the Bestiary) change.
- A game's file in its own `art/` wins over the core's (`ArtPaths.of`).
- The first file that exists wins, so portraits can arrive one creature at a time.

## What a chip shows

- A portrait that isn't square (a 7:9 photograph) goes into a chip as the largest square cut from its **top** (30% of the
  spare height is cut above), so the face stays; a wide one from its middle (`PortraitArt.square`). A square one is used whole.
- A creature with no portrait shows a drawn head and shoulders (`PortraitArt.placeholder`) in the frame, not an empty hole.
- Down creatures are greyed, dead ones faded, as before.

## The Bestiary

With `photoreal` on, an entry leads with the large portrait (`UiParts.large_portrait`): 240 px wide, its height following the
picture's shape within 0.85 to 1.3 of the width (a square monster portrait is a 240 px square), a silhouette the same size
until the picture exists. The entry's words wrap narrower beside it. The list rows keep their 40 px chips, now the
monster's own portrait too.

## Tests

`tests/unit/test_portrait_art.gd` (the lookup order, the default behaviour, the crop, the placeholder, the large size);
a game adds its own for its folders and layout checks for the Bestiary page.
