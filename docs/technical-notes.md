# Technical Notes

## Target Mod

The generated compatibility codes are intended for Steam Workshop item:

```text
3554281691
```

Current in-game exports from YSM x WiF x WTO were observed to use no Workshop header:

```text
modded flag = 0
division IDs = YSM Freedom division IDs
unit ID width = 17 bits
```

Older Workshop-shared codes used a Workshop header with `workshop_id = 3554281691` and `deck_format_version = 242`, but those strings are rejected by the current mod/game combination.

## Working Division IDs

The reliable import modes use YSM Freedom division IDs:

```text
NATO Limited    = 1632  Descriptor_Deck_Division_YSM_SIDE_NATO_BALANCED
NATO Unlimited  = 1633  Descriptor_Deck_Division_YSM_SIDE_NATO_UNLIMITED
PACT Limited    = 1634  Descriptor_Deck_Division_YSM_SIDE_PACT_BALANCED
PACT Unlimited  = 1635  Descriptor_Deck_Division_YSM_SIDE_PACT_UNLIMITED
```

Older versions of the mod used four generic YSM division IDs, `932` through `935`. The August 2026 mod update replaced those descriptors with side-wide balanced/unlimited descriptors. It also reordered the mod's unit serializer table. Deck codes need both the current division ID and the current mod unit IDs; mixing the new division IDs with vanilla unit IDs is still rejected as an invalid battlegroup.

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

Point the generator at the compiled YSM `Division.ndfbin` so it can read the current Freedom division IDs and the mod's complete unit-ID table:

```powershell
$env:WARNO_YSMXWIFXWTO_DIVISION_NDFBIN = "C:\SteamLibrary\steamapps\workshop\content\1611600\3554281691\Gen\NDF\GFX\Division.ndfbin"
python .\tools\regenerate_ysmxwifxwto_vanilla_deck_codes.py
```

You can inspect the extracted Freedom division IDs and unit-table size with:

```powershell
python .\tools\extract_ysmxwifxwto_division_ids.py "C:\SteamLibrary\steamapps\workshop\content\1611600\3554281691\Gen\NDF\GFX\Division.ndfbin"
```

Do not commit extracted WARNO data.
