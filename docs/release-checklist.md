# Release Checklist

Use this before the first GitHub push and before each public release.

## Before Commit

- Confirm `warno_deck_ui_macro_calibration.json` is not present in the commit.
- Confirm no `PROFILE.profile2`, `.sav3`, Steam `remotecache.vdf`, or backup folders are included.
- Confirm no extracted WARNO files, `.ndfbin` files, Workshop files, screenshots with personal data, or copied image assets are included.
- Run a quick search for local usernames or machine paths.
- Confirm `LICENSE` is present.

## Smoke Test

From the project root:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_profile_backup.ps1"
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Calibrate
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_deck_ui_macro.ps1" -Mode Limited -Count 1 -StartDelaySeconds 5
```

Delete the calibration file before committing:

```powershell
Remove-Item ".\warno_deck_ui_macro_calibration.json"
```

## Suggested First Release

- Tag: `v0.1.0`
- Release title: `Initial vanilla deck import pack`
- Include the repository as a ZIP attachment for users who do not use Git.
- Mention that `Limited` mode is the recommended path.
- Mention that this project is unofficial and does not include WARNO or Workshop assets.
