param(
    [switch]$Calibrate,

    [ValidateSet("Limited", "Unlimited", "OfficialIcons", "ModdedOfficialIcons")]
    [string]$Mode = "Limited",

    [string]$CsvPath = "",

    [string]$CalibrationPath = "",

    [int]$StartAt = 1,

    [int]$Count = 0,

    [int]$StartDelaySeconds = 3,

    [int]$AfterImportClickMs = 350,

    [int]$AfterPasteMs = 90,

    [int]$AfterCodeConfirmMs = 500,

    [int]$AfterNameConfirmMs = 550,

    [int]$ScreenStateTimeoutSeconds = 10,

    [double]$ScreenMarkerTolerance = 0.16,

    [switch]$DisableScreenStateGuard,

    [switch]$SkipName,

    [switch]$ConfirmCodeBeforeName,

    [switch]$AllowExperimentalOfficialIcons,

    [switch]$ConfirmEach
)

$ErrorActionPreference = "Stop"

$ScriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ProjectRoot = Split-Path -Parent $ScriptDirectory
if ([string]::IsNullOrWhiteSpace($CsvPath)) {
    $CsvPath = Join-Path $ProjectRoot "data\ysmxwifxwto_vanilla_starting_deck_codes.csv"
}
if ([string]::IsNullOrWhiteSpace($CalibrationPath)) {
    $CalibrationPath = Join-Path $ProjectRoot "warno_deck_ui_macro_calibration.json"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class WarnoInput {
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    public const uint LEFTDOWN = 0x0002;
    public const uint LEFTUP = 0x0004;
    public const uint KEYUP = 0x0002;
}
"@

function New-PointObject {
    param([int]$X, [int]$Y)
    [pscustomobject]@{ X = $X; Y = $Y }
}

function Resolve-CalibrationPoint {
    param(
        $Point,
        [string]$Name
    )

    $resolved = @($Point) | Where-Object {
        $null -ne $_ -and
        $null -ne $_.PSObject.Properties["X"] -and
        $null -ne $_.PSObject.Properties["Y"]
    } | Select-Object -Last 1

    if ($null -eq $resolved) {
        throw "Calibration point '$Name' is missing or invalid. Re-run with -Calibrate."
    }
    return New-PointObject -X ([int]$resolved.X) -Y ([int]$resolved.Y)
}

function Get-ForegroundProcessName {
    $window = [WarnoInput]::GetForegroundWindow()
    if ($window -eq [IntPtr]::Zero) {
        return $null
    }

    [uint32]$foregroundProcessId = 0
    [WarnoInput]::GetWindowThreadProcessId($window, [ref]$foregroundProcessId) | Out-Null
    if ($foregroundProcessId -eq 0) {
        return $null
    }

    try {
        return (Get-Process -Id $foregroundProcessId -ErrorAction Stop).ProcessName
    } catch {
        return $null
    }
}

function Wait-ForWarnoForeground {
    $deadline = [DateTime]::UtcNow.AddSeconds($ScreenStateTimeoutSeconds)
    do {
        if ((Get-ForegroundProcessName) -ieq "WARNO") {
            return
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "WARNO is not the foreground window. The importer stopped before sending any more clicks or keystrokes."
}

function Get-ScreenMarker {
    param(
        $Point,
        [int]$Radius = 28,
        [int]$Step = 4
    )

    $size = ($Radius * 2) + 1
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen(
            ([int]$Point.X - $Radius),
            ([int]$Point.Y - $Radius),
            0,
            0,
            $bitmap.Size
        )

        $pixels = [System.Collections.Generic.List[int]]::new()
        for ($y = 0; $y -lt $size; $y += $Step) {
            for ($x = 0; $x -lt $size; $x += $Step) {
                $color = $bitmap.GetPixel($x, $y)
                $pixels.Add((([int]$color.R -shl 16) -bor ([int]$color.G -shl 8) -bor [int]$color.B))
            }
        }
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }

    return [pscustomobject]@{
        radius = $Radius
        step = $Step
        pixels = @($pixels)
    }
}

function Get-ScreenMarkerDifference {
    param(
        $Expected,
        $Actual
    )

    $expectedPixels = @($Expected.pixels)
    $actualPixels = @($Actual.pixels)
    if ($expectedPixels.Count -eq 0 -or $expectedPixels.Count -ne $actualPixels.Count) {
        return [double]::PositiveInfinity
    }

    [double]$difference = 0
    for ($index = 0; $index -lt $expectedPixels.Count; $index++) {
        $expectedRgb = [int]$expectedPixels[$index]
        $actualRgb = [int]$actualPixels[$index]
        foreach ($shift in @(16, 8, 0)) {
            $expectedChannel = ($expectedRgb -shr $shift) -band 0xff
            $actualChannel = ($actualRgb -shr $shift) -band 0xff
            $difference += [Math]::Abs($expectedChannel - $actualChannel)
        }
    }

    return $difference / ($expectedPixels.Count * 3 * 255)
}

function New-ScreenMarker {
    param($Point)

    Write-Host "Switch focus back to WARNO. Capturing the screen marker when WARNO is foreground."
    Wait-ForWarnoForeground
    [WarnoInput]::SetCursorPos(0, 0) | Out-Null
    Start-Sleep -Milliseconds 300
    return Get-ScreenMarker -Point $Point
}

function Wait-ForScreenState {
    param(
        [string]$Name,
        $Point,
        $Marker
    )

    Wait-ForWarnoForeground
    if ($DisableScreenStateGuard) {
        return
    }

    [WarnoInput]::SetCursorPos(0, 0) | Out-Null
    $deadline = [DateTime]::UtcNow.AddSeconds($ScreenStateTimeoutSeconds)
    [double]$lastDifference = [double]::PositiveInfinity
    do {
        $actual = Get-ScreenMarker -Point $Point -Radius ([int]$Marker.radius) -Step ([int]$Marker.step)
        $lastDifference = Get-ScreenMarkerDifference -Expected $Marker -Actual $actual
        if ($lastDifference -le $ScreenMarkerTolerance) {
            return
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)

    throw ("WARNO did not reach the expected '{0}' screen. The importer stopped before continuing. Marker difference: {1:N3}; tolerance: {2:N3}." -f $Name, $lastDifference, $ScreenMarkerTolerance)
}

function Capture-Point {
    param(
        [string]$Name,
        [string]$Instructions,
        [switch]$Optional
    )

    Write-Host ""
    Write-Host $Instructions
    if ($Optional) {
        $answer = Read-Host "Hover over '$Name' and press Enter here, or type s then Enter to skip"
        if ($answer -eq "s") {
            return $null
        }
    } else {
        $null = Read-Host "Hover over '$Name' and press Enter here"
    }

    $position = [System.Windows.Forms.Cursor]::Position
    Write-Host "Captured $Name at X=$($position.X), Y=$($position.Y)"
    return New-PointObject -X $position.X -Y $position.Y
}

function Click-Point {
    param($Point)
    if ($null -eq $Point) {
        return
    }
    [WarnoInput]::SetCursorPos([int]$Point.X, [int]$Point.Y) | Out-Null
    Start-Sleep -Milliseconds 80
    [WarnoInput]::mouse_event([WarnoInput]::LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [WarnoInput]::mouse_event([WarnoInput]::LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
}

function Send-KeyDownUp {
    param([byte]$VirtualKey)
    [WarnoInput]::keybd_event($VirtualKey, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 35
    [WarnoInput]::keybd_event($VirtualKey, 0, [WarnoInput]::KEYUP, [UIntPtr]::Zero)
}

function Send-CtrlKey {
    param([byte]$VirtualKey)
    [WarnoInput]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 35
    Send-KeyDownUp -VirtualKey $VirtualKey
    Start-Sleep -Milliseconds 35
    [WarnoInput]::keybd_event(0x11, 0, [WarnoInput]::KEYUP, [UIntPtr]::Zero)
}

function Paste-ClipboardText {
    param([string]$Text)
    Set-Clipboard -Value $Text
    Start-Sleep -Milliseconds 100
    Send-CtrlKey -VirtualKey 0x41
    Start-Sleep -Milliseconds 80
    Send-CtrlKey -VirtualKey 0x56
}

function Warn-IfWarnoNeedsRestart {
    $modConfigPath = Join-Path $env:USERPROFILE "Saved Games\EugenSystems\WARNO\mod\Config.ini"
    if (!(Test-Path -LiteralPath $modConfigPath)) {
        return
    }

    $modConfig = Get-Item -LiteralPath $modConfigPath
    $warnoProcesses = @(Get-CimInstance Win32_Process -Filter "name = 'WARNO.exe'" -ErrorAction SilentlyContinue)
    foreach ($process in $warnoProcesses) {
        $startedAt = $process.CreationDate
        if ($startedAt -is [string]) {
            $startedAt = [Management.ManagementDateTimeConverter]::ToDateTime($process.CreationDate)
        }
        if ($startedAt -lt $modConfig.LastWriteTime) {
            Write-Warning "WARNO.exe started before WARNO's mod Config.ini was last written. If modded deck codes are rejected, fully close WARNO and reopen it so the active mod is loaded."
        }
    }
}

if ($Calibrate) {
    Write-Host "WARNO deck UI macro calibration"
    Write-Host "Put WARNO in windowed or borderless mode. Do not move or resize the window after calibration."
    Write-Host "Start on Armory -> Battlegroups, where the Import button is visible."

    $calibration = [ordered]@{
        version = 2
    }
    $calibration.importButton = Capture-Point `
        -Name "Import button" `
        -Instructions "Hover over the Battlegroups Import button."
    $calibration.battlegroupsMarker = New-ScreenMarker -Point $calibration.importButton

    Write-Host ""
    Write-Host "Now manually click WARNO's Import button so the code-entry dialog is open."
    $calibration.codeField = Capture-Point `
        -Name "Deck code text field" `
        -Instructions "Hover over the deck-code text field."
    $calibration.importDialogMarker = New-ScreenMarker -Point $calibration.codeField

    $calibration.codeConfirm = Capture-Point `
        -Name "Separate code confirm button" `
        -Instructions "Only capture this if WARNO has a separate button that validates the deck code before naming. Otherwise skip it." `
        -Optional

    Write-Host ""
    Write-Host "Capture the battlegroup-name field and final Import/Save button."
    Write-Host "If you want WARNO to auto-name decks, skip the name field and capture only the final button."
    $calibration.nameField = Capture-Point `
        -Name "Deck name text field" `
        -Instructions "Hover over the deck-name text field." `
        -Optional

    $calibration.nameConfirm = Capture-Point `
        -Name "Final save/confirm button" `
        -Instructions "Hover over the final save/confirm button." `
        -Optional

    $calibration | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $CalibrationPath -Encoding UTF8
    Write-Host ""
    Write-Host "Saved calibration to $CalibrationPath"
    Write-Host "Run again without -Calibrate to import decks."
    exit 0
}

if (!(Test-Path -LiteralPath $CsvPath)) {
    throw "CSV not found: $CsvPath"
}
if (!(Test-Path -LiteralPath $CalibrationPath)) {
    throw "Calibration not found. Run this first with -Calibrate."
}

$rows = Import-Csv -LiteralPath $CsvPath -Encoding UTF8
if ($rows.Count -eq 0) {
    throw "No deck rows found in $CsvPath"
}
if ($StartAt -lt 1 -or $StartAt -gt $rows.Count) {
    throw "StartAt must be between 1 and $($rows.Count)"
}

$calibration = Get-Content -LiteralPath $CalibrationPath -Raw | ConvertFrom-Json
$calibration.importButton = Resolve-CalibrationPoint -Point $calibration.importButton -Name "Import button"
$calibration.codeField = Resolve-CalibrationPoint -Point $calibration.codeField -Name "Deck code text field"
if ($null -ne $calibration.codeConfirm) {
    $calibration.codeConfirm = Resolve-CalibrationPoint -Point $calibration.codeConfirm -Name "Code confirm button"
}
if ($null -ne $calibration.nameField) {
    $calibration.nameField = Resolve-CalibrationPoint -Point $calibration.nameField -Name "Deck name text field"
}
if ($null -ne $calibration.nameConfirm) {
    $calibration.nameConfirm = Resolve-CalibrationPoint -Point $calibration.nameConfirm -Name "Final save/confirm button"
}

if (!$DisableScreenStateGuard) {
    if ([int]$calibration.version -lt 2 -or $null -eq $calibration.battlegroupsMarker -or $null -eq $calibration.importDialogMarker) {
        throw "Calibration predates the screen-state safety guard. Re-run with -Calibrate before importing."
    }
}
$codeColumn = switch ($Mode) {
    "Limited" { "ysmxwifxwto_limited_code" }
    "Unlimited" { "ysmxwifxwto_unlimited_code" }
    "OfficialIcons" { "vanilla_official_icon_code" }
    "ModdedOfficialIcons" { "ysmxwifxwto_official_icon_code" }
}

if (!$rows[0].PSObject.Properties.Name.Contains($codeColumn)) {
    throw "CSV does not contain column '$codeColumn'. Regenerate the deck-code CSV before using mode '$Mode'."
}

if (($Mode -eq "OfficialIcons" -or $Mode -eq "ModdedOfficialIcons") -and !$AllowExperimentalOfficialIcons) {
    throw "$Mode mode is experimental and can fail in WARNO with 'The string does not represent a valid Battlegroup' while YSM x WiF x WTO is active. Use -Mode Limited for normal imports, or pass -AllowExperimentalOfficialIcons if you are intentionally testing official-emblem codes one deck at a time."
}

if ($Mode -eq "OfficialIcons") {
    Write-Warning "OfficialIcons uses normal non-modded vanilla deck codes so WARNO can use each original division emblem. Test one deck first under the active mod before bulk importing."
}

$endExclusive = $rows.Count
if ($Count -gt 0) {
    $endExclusive = [Math]::Min($rows.Count, ($StartAt - 1) + $Count)
}

Write-Host "Mode: $Mode"
Write-Host "Rows: $StartAt through $endExclusive of $($rows.Count)"
Warn-IfWarnoNeedsRestart
Write-Host "Starting in $StartDelaySeconds seconds. Switch focus to WARNO and leave the Battlegroups screen visible."
Start-Sleep -Seconds $StartDelaySeconds
Wait-ForScreenState -Name "Battlegroups list" -Point $calibration.importButton -Marker $calibration.battlegroupsMarker

for ($index = $StartAt - 1; $index -lt $endExclusive; $index++) {
    $row = $rows[$index]
    $number = $index + 1
    Write-Host "Importing [$number/$($rows.Count)] $($row.alliance) - $($row.name)"

    Wait-ForScreenState -Name "Battlegroups list" -Point $calibration.importButton -Marker $calibration.battlegroupsMarker
    Click-Point $calibration.importButton
    Start-Sleep -Milliseconds $AfterImportClickMs

    Wait-ForScreenState -Name "Battlegroup import dialog" -Point $calibration.codeField -Marker $calibration.importDialogMarker
    Click-Point $calibration.codeField
    Start-Sleep -Milliseconds 150
    Paste-ClipboardText -Text $row.$codeColumn
    Start-Sleep -Milliseconds $AfterPasteMs

    if ($ConfirmCodeBeforeName) {
        if ($null -ne $calibration.codeConfirm) {
            Click-Point $calibration.codeConfirm
        } else {
            Send-KeyDownUp -VirtualKey 0x0D
        }
        Start-Sleep -Milliseconds $AfterCodeConfirmMs
    }

    if (!$SkipName -and $null -ne $calibration.nameField) {
        Click-Point $calibration.nameField
        Start-Sleep -Milliseconds 150
        Paste-ClipboardText -Text $row.name
        Start-Sleep -Milliseconds $AfterPasteMs
    }

    if ($null -ne $calibration.nameConfirm) {
        Click-Point $calibration.nameConfirm
    } else {
        Send-KeyDownUp -VirtualKey 0x0D
    }
    Start-Sleep -Milliseconds $AfterNameConfirmMs
    Wait-ForScreenState -Name "Battlegroups list after saving '$($row.name)'" -Point $calibration.importButton -Marker $calibration.battlegroupsMarker

    if ($ConfirmEach -and $index -lt ($endExclusive - 1)) {
        $answer = Read-Host "Press Enter for next deck, then switch back to WARNO; or type q to stop"
        if ($answer -eq "q") {
            break
        }
    }
}

Write-Host "Done."
