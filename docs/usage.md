# Usage

## Requirements

- Windows PowerShell.
- WARNO installed through Steam.
- YSM x WiF x WTO active in WARNO.
- WARNO open to `Armory -> Battlegroups` before running the importer.

## Back Up First

Close WARNO for the cleanest backup, then run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_profile_backup.ps1"
```

The default backup folder is:

```text
%USERPROFILE%\Documents\WARNO_Profile_Backups
```

## Calibrate

Run calibration once after cloning/downloading the project:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Calibrate
```

The script will ask you to hover over WARNO UI controls and press Enter in PowerShell. Keep WARNO in the same window position and resolution after calibration.

Calibration is saved to:

```text
warno_deck_ui_macro_calibration.json
```

This file is personal and should not be committed.

## Import All Recommended Decks

Use `Limited` mode:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Mode Limited -StartDelaySeconds 5
```

Switch focus to WARNO before the countdown ends. Leave the Battlegroups screen visible.

## Import a Small Test Batch

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Mode Limited -Count 1 -StartDelaySeconds 5
```

Resume from a later row:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Mode Limited -StartAt 20 -Count 10 -StartDelaySeconds 5
```

## Modes

- `Limited`: recommended. Uses YSM/WiF/WTO-compatible limited Freedom divisions.
- `Unlimited`: uses YSM/WiF/WTO-compatible unlimited Freedom divisions.
- `OfficialIcons`: experimental normal vanilla deck codes with original vanilla division IDs. These can be rejected while the mod is active and require `-AllowExperimentalOfficialIcons`.
- `ModdedOfficialIcons`: experimental and guarded because it was observed to fail in WARNO.

## Speed Controls

The default timings are conservative. If the macro is stable on your machine, lower these values gradually:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Mode Limited -AfterImportClickMs 200 -AfterPasteMs 40 -AfterNameConfirmMs 300
```

If WARNO misses clicks or text, raise the delays again.
