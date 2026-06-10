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

    public const uint LEFTDOWN = 0x0002;
    public const uint LEFTUP = 0x0004;
    public const uint KEYUP = 0x0002;
}
"@

function New-PointObject {
    param([int]$X, [int]$Y)
    [pscustomobject]@{ X = $X; Y = $Y }
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
        Read-Host "Hover over '$Name' and press Enter here"
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

if ($Calibrate) {
    Write-Host "WARNO deck UI macro calibration"
    Write-Host "Put WARNO in windowed or borderless mode. Do not move or resize the window after calibration."
    Write-Host "Start on Armory -> Battlegroups, where the Import button is visible."

    $calibration = [ordered]@{}
    $calibration.importButton = Capture-Point `
        -Name "Import button" `
        -Instructions "Hover over the Battlegroups Import button."

    Write-Host ""
    Write-Host "Now manually click WARNO's Import button so the code-entry dialog is open."
    $calibration.codeField = Capture-Point `
        -Name "Deck code text field" `
        -Instructions "Hover over the deck-code text field."

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

$rows = Import-Csv -LiteralPath $CsvPath
if ($rows.Count -eq 0) {
    throw "No deck rows found in $CsvPath"
}
if ($StartAt -lt 1 -or $StartAt -gt $rows.Count) {
    throw "StartAt must be between 1 and $($rows.Count)"
}

$calibration = Get-Content -LiteralPath $CalibrationPath -Raw | ConvertFrom-Json
$codeColumn = switch ($Mode) {
    "Limited" { "ysmxwifxwto_limited_code" }
    "Unlimited" { "ysmxwifxwto_unlimited_code" }
    "OfficialIcons" { "vanilla_official_icon_code" }
    "ModdedOfficialIcons" { "ysmxwifxwto_official_icon_code" }
}

if (!$rows[0].PSObject.Properties.Name.Contains($codeColumn)) {
    throw "CSV does not contain column '$codeColumn'. Regenerate the deck-code CSV before using mode '$Mode'."
}

if ($Mode -eq "ModdedOfficialIcons" -and !$AllowExperimentalOfficialIcons) {
    throw "ModdedOfficialIcons mode is experimental and was observed to fail in WARNO with 'The string does not represent a valid Battlegroup'. Use -Mode Limited, or pass -AllowExperimentalOfficialIcons if you are intentionally retesting."
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
Write-Host "Starting in $StartDelaySeconds seconds. Switch focus to WARNO and leave the Battlegroups screen visible."
Start-Sleep -Seconds $StartDelaySeconds

for ($index = $StartAt - 1; $index -lt $endExclusive; $index++) {
    $row = $rows[$index]
    $number = $index + 1
    Write-Host "Importing [$number/$($rows.Count)] $($row.alliance) - $($row.name)"

    Click-Point $calibration.importButton
    Start-Sleep -Milliseconds $AfterImportClickMs

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

    if ($ConfirmEach -and $index -lt ($endExclusive - 1)) {
        $answer = Read-Host "Press Enter for next deck, or type q to stop"
        if ($answer -eq "q") {
            break
        }
    }
}

Write-Host "Done."
