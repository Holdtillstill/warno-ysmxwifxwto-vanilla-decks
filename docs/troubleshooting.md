# Troubleshooting

## The String Does Not Represent A Valid Battlegroup

Use `-Mode Limited`. This was the tested working path.

`OfficialIcons` and `ModdedOfficialIcons` may fail depending on how WARNO validates divisions under the active mod.
The UI macro blocks both modes unless you pass `-AllowExperimentalOfficialIcons`.

If `-Mode Limited` also fails, fully close WARNO and reopen it. WARNO reads the active-mod config at startup, so changing/enabling the mod while the game is already open can leave the current session unable to import modded deck codes.

If this starts immediately after a YSM x WiF x WTO update, the mod may have changed its Workshop deck header, Freedom division IDs, unit IDs, or several of them together. Re-run the maintainer generator with `WARNO_YSMXWIFXWTO_DIVISION_NDFBIN` set to the current Workshop `Division.ndfbin`, then compare the generated format with a fresh deck exported by the game.

If a deck imports but contains only a few incorrect units, regenerate from the current WARNO base deck data. Vanilla cards must use the current base-game `UnitIds`; the mod's compiled build-time unit table is only authoritative for mod-added units.

## Macro Clicks Import Before Naming

Re-run calibration:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Calibrate
```

When asked for a separate code confirm button, skip it unless WARNO truly has a separate validation button before the battlegroup-name field.

The current calibration format includes visual screen markers. Old calibration files are rejected so the macro cannot continue clicking after WARNO lands on the wrong tab or an error dialog.

## Text Does Not Paste Or Clicks Are Missed

Increase delays:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Mode Limited -AfterImportClickMs 600 -AfterPasteMs 150 -AfterNameConfirmMs 800
```

## I Need To Stop Mid-Import

Press `Ctrl+C` in PowerShell. Then resume with `-StartAt`.

Example:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Mode Limited -StartAt 34
```

## My Old Custom Decks Disappeared

Check for older backups of `PROFILE.profile2` first. If Steam Cloud has already overwritten the profile and there are no exported deck codes or older backups, recovery may not be possible.
