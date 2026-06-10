param(
    [string]$SteamUserDataRoot = "C:\Program Files (x86)\Steam\userdata",

    [string]$BackupRoot = "$env:USERPROFILE\Documents\WARNO_Profile_Backups",

    [switch]$AllSteamUsers
)

$ErrorActionPreference = "Stop"

$appId = "1611600"
$savedGamesWarno = Join-Path $env:USERPROFILE "Saved Games\EugenSystems\WARNO"

function Copy-IfExists {
    param(
        [string]$Source,
        [string]$DestinationDirectory,
        [string]$DestinationName
    )

    if (Test-Path -LiteralPath $Source) {
        Copy-Item -LiteralPath $Source -Destination (Join-Path $DestinationDirectory $DestinationName) -Force
        return $true
    }
    return $false
}

$warnoProcess = Get-Process -Name "WARNO" -ErrorAction SilentlyContinue
if ($warnoProcess) {
    Write-Warning "WARNO is currently running. Close WARNO first for the cleanest backup; the in-memory profile may not be flushed yet."
}

$profileFiles = Get-ChildItem -Path $SteamUserDataRoot -Recurse -File -Filter "PROFILE.profile2" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -like "*\$appId\remote\PROFILE.profile2" }

if (!$profileFiles) {
    throw "Could not find any WARNO PROFILE.profile2 under $SteamUserDataRoot"
}

if (!$AllSteamUsers) {
    $profileFiles = $profileFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $BackupRoot "WARNO-profile-$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$manifest = [ordered]@{
    created_at = (Get-Date).ToString("o")
    app_id = $appId
    warning = "Restore only while WARNO is closed. If Steam Cloud conflict appears, choose the local/restored files."
    files = @()
}

foreach ($profile in $profileFiles) {
    $accountDir = Split-Path (Split-Path (Split-Path $profile.FullName -Parent) -Parent) -Leaf
    $accountBackupDir = Join-Path $backupDir "steam-user-$accountDir"
    New-Item -ItemType Directory -Path $accountBackupDir -Force | Out-Null

    $remoteCache = Join-Path (Split-Path (Split-Path $profile.FullName -Parent) -Parent) "remotecache.vdf"

    Copy-Item -LiteralPath $profile.FullName -Destination (Join-Path $accountBackupDir "PROFILE.profile2") -Force
    $manifest.files += [ordered]@{
        source = $profile.FullName
        backup = (Join-Path $accountBackupDir "PROFILE.profile2")
        size = $profile.Length
        last_write_time = $profile.LastWriteTime.ToString("o")
    }

    if (Copy-IfExists -Source $remoteCache -DestinationDirectory $accountBackupDir -DestinationName "remotecache.vdf") {
        $cacheInfo = Get-Item -LiteralPath $remoteCache
        $manifest.files += [ordered]@{
            source = $remoteCache
            backup = (Join-Path $accountBackupDir "remotecache.vdf")
            size = $cacheInfo.Length
            last_write_time = $cacheInfo.LastWriteTime.ToString("o")
        }
    }
}

$modConfig = Join-Path $savedGamesWarno "mod\Config.ini"
if (Copy-IfExists -Source $modConfig -DestinationDirectory $backupDir -DestinationName "WARNO-mod-Config.ini") {
    $info = Get-Item -LiteralPath $modConfig
    $manifest.files += [ordered]@{
        source = $modConfig
        backup = (Join-Path $backupDir "WARNO-mod-Config.ini")
        size = $info.Length
        last_write_time = $info.LastWriteTime.ToString("o")
    }
}

$optionIni = Join-Path $savedGamesWarno "Option.ini"
if (Copy-IfExists -Source $optionIni -DestinationDirectory $backupDir -DestinationName "WARNO-Option.ini") {
    $info = Get-Item -LiteralPath $optionIni
    $manifest.files += [ordered]@{
        source = $optionIni
        backup = (Join-Path $backupDir "WARNO-Option.ini")
        size = $info.Length
        last_write_time = $info.LastWriteTime.ToString("o")
    }
}

$manifestPath = Join-Path $backupDir "manifest.json"
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "WARNO profile backup complete:"
Write-Host $backupDir
Write-Host ""
Write-Host "Backed up $($manifest.files.Count) file records. Manifest:"
Write-Host $manifestPath
