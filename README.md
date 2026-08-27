# WARNO Vanilla Deck Imports for YSM x WiF x WTO

PowerShell helpers and generated deck codes for importing WARNO vanilla starting battlegroups while running the Steam Workshop mod **YSM x WiF x WTO**.

This is an unofficial community companion utility. The YSM x WiF x WTO authors already did the hard part by building and maintaining the mod; this project just keeps a familiar vanilla starting-deck list available as importable deck codes.

This repository does not include WARNO game files, profile saves, official image assets, or mod source. It only includes generated deck-code data and helper scripts.

## Why This Exists

Maintaining premade battlegroups inside a WARNO mod can be tedious across game updates. Keeping these decks as import codes lets players restore a familiar starting point locally without adding more maintenance burden to the Workshop mod.

The recommended codes use the mod's Freedom divisions so the decks can import while YSM x WiF x WTO is active.

## What Works

- `Limited` mode: recommended, tested path. Imports vanilla starting decks using YSM/WiF/WTO-compatible Freedom limited divisions.
- `Unlimited` mode: same deck contents, but targets Freedom unlimited divisions.
- Profile backup script: backs up `PROFILE.profile2`, Steam `remotecache.vdf`, WARNO mod config, and `Option.ini`.

## Notes And Limitations

- Per-division official emblems are not reliably available through deck import alone.
- `OfficialIcons` mode uses normal vanilla deck codes and is guarded as experimental because it can be rejected while the mod is active.
- `ModdedOfficialIcons` is experimental and may be rejected by WARNO with: `The string does not represent a valid Battlegroup`.

## Quick Start

Back up your WARNO profile first:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_profile_backup.ps1"
```

Calibrate the UI macro once:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Calibrate
```

Import all recommended decks:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Mode Limited -StartDelaySeconds 5
```

## Project Layout

- `data/ysmxwifxwto_vanilla_starting_deck_codes.csv`: import data used by the macro.
- `docs/deck-codes.md`: human-readable deck-code table.
- `docs/usage.md`: calibration and import workflow.
- `docs/backup-and-restore.md`: profile backup notes.
- `docs/technical-notes.md`: deck-code and icon limitations.
- `docs/backlog.md`: possible future improvements.
- `scripts/warno_deck_ui_macro.ps1`: automated UI importer.
- `scripts/warno_profile_backup.ps1`: profile backup helper.
- `scripts/warno_deck_clipboard_importer.ps1`: manual clipboard fallback.
- `tools/regenerate_ysmxwifxwto_vanilla_deck_codes.py`: maintainer-only generator.
- `tools/extract_ysmxwifxwto_division_ids.py`: maintainer helper for reading current YSM Freedom division and unit IDs from `Division.ndfbin`.
- `docs/release-checklist.md`: pre-publish safety checklist.

## Publishing Notes

This project is released under the MIT License. Do not commit personal WARNO profile backups, `warno_deck_ui_macro_calibration.json`, extracted WARNO data, or copied game/mod assets.

## Credits

All WARNO content belongs to Eugen Systems. YSM x WiF x WTO, Yokaiste's Sandbox Mod, and A World in Flames belong to their respective mod authors. This repository is only a helper for importing deck codes and backing up local profiles.
