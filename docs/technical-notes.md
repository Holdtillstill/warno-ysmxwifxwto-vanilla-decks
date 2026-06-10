# Technical Notes

## Target Mod

The generated modded codes target Steam Workshop item:

```text
3554281691
```

The mod header used during generation was:

```text
workshop_id = 3554281691
deck_format_version = 242
```

## Working Division IDs

The reliable import modes use YSM Freedom division IDs:

```text
NATO Unlimited  = 932
PACT Unlimited  = 933
NATO Limited    = 934
PACT Limited    = 935
```

## Why Official Division Emblems Are Hard

The leftmost battlegroup emblem is not stored as a free image field in the deck code. It comes from the division descriptor used by the deck. In WARNO data this is the division's `EmblemTexture`.

The reliable codes point at YSM Freedom divisions so they import under the mod. That means WARNO uses those division descriptors and their emblems.

Copying official image assets into the project would not make WARNO select a different emblem for each imported battlegroup. It would also be inappropriate for an open-source repository because those assets belong to Eugen/WARNO.

## Possible Future Fix

A real official-emblem solution would likely require a compatibility mod that adds valid import-only divisions, one per vanilla division, each using:

- YSM/WiF/WTO-compatible rules or cost matrix
- the original vanilla `EmblemTexture`
- stable serializer division IDs

That is separate from this UI import helper.

## Regenerating Codes

`tools/regenerate_ysmxwifxwto_vanilla_deck_codes.py` is for maintainers. It expects extracted WARNO deck data at:

```text
source-data/base-decks/GameData/Generated/Gameplay/Decks
```

You can override that path:

```powershell
$env:WARNO_BASE_DECK_DIR = "C:\path\to\GameData\Generated\Gameplay\Decks"
python .\tools\regenerate_ysmxwifxwto_vanilla_deck_codes.py
```

Do not commit extracted WARNO data.
