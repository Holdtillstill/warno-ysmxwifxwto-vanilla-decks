# Troubleshooting

## The String Does Not Represent A Valid Battlegroup

Use `-Mode Limited`. This was the tested working path.

`OfficialIcons` and `ModdedOfficialIcons` may fail depending on how WARNO validates divisions under the active mod.

## Macro Clicks Import Before Naming

Re-run calibration:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Calibrate
```

When asked for a separate code confirm button, skip it unless WARNO truly has a separate validation button before the battlegroup-name field.

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
