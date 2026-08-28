# Technical Notes

## Target Mod

The generated compatibility codes are intended for Steam Workshop item:

```text
3554281691
```

Current in-game exports from YSM x WiF x WTO use the Workshop header:

```text
modded flag = 1
workshop ID = 3554281691
deck format version = 242
division IDs = YSM Freedom division IDs
unit ID width = 17 bits
```

Older YSM versions were observed accepting no-header strings. The August 2026 update requires the current Workshop header and current Freedom division IDs.

## Working Division IDs

The reliable import modes use YSM Freedom division IDs:

```text
NATO Limited    = 1632  Descriptor_Deck_Division_YSM_SIDE_NATO_BALANCED
NATO Unlimited  = 1633  Descriptor_Deck_Division_YSM_SIDE_NATO_UNLIMITED
PACT Limited    = 1634  Descriptor_Deck_Division_YSM_SIDE_PACT_BALANCED
PACT Unlimited  = 1635  Descriptor_Deck_Division_YSM_SIDE_PACT_UNLIMITED
```

Older versions of the mod used four generic YSM division IDs, `932` through `935`. The August 2026 mod update replaced those descriptors with side-wide balanced/unlimited descriptors.

For vanilla units, imported deck codes must keep WARNO's current base-game unit IDs. The compiled mod contains its own build-time `UnitIds` table, but WARNO's runtime merge preserves current base serializer IDs for base units. Encoding vanilla cards with the mod's build-time IDs produces the wrong units and silently drops cards that are invalid in the target Freedom division.

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

Point the generator at the compiled YSM `Division.ndfbin` so it can read the current Freedom division IDs:

```powershell
$env:WARNO_YSMXWIFXWTO_DIVISION_NDFBIN = "C:\SteamLibrary\steamapps\workshop\content\1611600\3554281691\Gen\NDF\GFX\Division.ndfbin"
python .\tools\regenerate_ysmxwifxwto_vanilla_deck_codes.py
```

The generator requires every non-challenge official deck in `Decks.ndf` to be tracked. If a WARNO update adds another official battlegroup, regeneration stops and lists the untracked descriptor instead of producing an incomplete deck pack.

You can inspect the extracted Freedom division IDs and unit-table size with:

```powershell
python .\tools\extract_ysmxwifxwto_division_ids.py "C:\SteamLibrary\steamapps\workshop\content\1611600\3554281691\Gen\NDF\GFX\Division.ndfbin"
```

Do not commit extracted WARNO data.
