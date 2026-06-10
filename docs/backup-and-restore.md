# Backup And Restore

## What The Backup Script Copies

`scripts/warno_profile_backup.ps1` copies:

- WARNO `PROFILE.profile2`
- Steam `remotecache.vdf`
- WARNO mod `Config.ini`
- WARNO `Option.ini`

By default it backs up the most recently modified Steam user profile for WARNO.

## Back Up

Close WARNO, then run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_profile_backup.ps1"
```

To back up every Steam user folder found under Steam `userdata`:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\warno_profile_backup.ps1" -AllSteamUsers
```

## Restore Notes

Restore only while WARNO is closed. Copy the backed-up `PROFILE.profile2` back into the matching Steam user folder:

```text
C:\Program Files (x86)\Steam\userdata\<steam-user-id>\1611600\remote\PROFILE.profile2
```

If Steam Cloud asks whether to keep local or cloud files, choose the restored local files.

## Steam Cloud Reality Check

If Steam Cloud has already synced an overwritten `PROFILE.profile2`, old custom decks may not be recoverable unless you exported their deck codes, shared them somewhere, or have an older local/cloud backup.
