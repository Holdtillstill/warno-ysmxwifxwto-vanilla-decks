param(
    [ValidateSet("Limited", "Unlimited")]
    [string]$Mode = "Limited",

    [string]$CsvPath = "",

    [int]$StartAt = 1,

    [switch]$AutoPaste,

    [switch]$CopyNameAfterCode,

    [int]$AutoPasteDelayMs = 1500
)

$ErrorActionPreference = "Stop"

$ScriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ProjectRoot = Split-Path -Parent $ScriptDirectory
if ([string]::IsNullOrWhiteSpace($CsvPath)) {
    $CsvPath = Join-Path $ProjectRoot "data\ysmxwifxwto_vanilla_starting_deck_codes.csv"
}

if (!(Test-Path -LiteralPath $CsvPath)) {
    throw "CSV not found: $CsvPath"
}

$rows = Import-Csv -LiteralPath $CsvPath
if ($rows.Count -eq 0) {
    throw "No deck rows found in $CsvPath"
}

if ($StartAt -lt 1 -or $StartAt -gt $rows.Count) {
    throw "StartAt must be between 1 and $($rows.Count)"
}

$codeColumn = if ($Mode -eq "Limited") {
    "ysmxwifxwto_limited_code"
} else {
    "ysmxwifxwto_unlimited_code"
}

if ($AutoPaste) {
    Add-Type -AssemblyName System.Windows.Forms
    Write-Host "AutoPaste is enabled. After each prompt, focus WARNO's import field within $AutoPasteDelayMs ms."
}

Write-Host "Mode: $Mode"
Write-Host "Decks: $($rows.Count)"
Write-Host ""
Write-Host "Important: this script does NOT write to WARNO's profile."
Write-Host "For each deck, it copies the code. In WARNO, open Armory -> Battlegroups -> Import."
Write-Host "WARNO should read the code from your clipboard; then give it a name and confirm/save it."
Write-Host ""
Write-Host "Press Enter here to copy each deck code. Type q and press Enter to quit."
Write-Host ""

for ($index = $StartAt - 1; $index -lt $rows.Count; $index++) {
    $row = $rows[$index]
    $number = $index + 1
    $prompt = "[$number/$($rows.Count)] $($row.alliance) - $($row.name)"
    $answer = Read-Host "$prompt"
    if ($answer -eq "q") {
        break
    }

    $code = $row.$codeColumn
    Set-Clipboard -Value $code
    Write-Host "Copied $Mode code for $($row.name)."
    Write-Host "Now switch to WARNO and use the Import button. The deck will not appear until WARNO confirms/saves the import."

    if ($AutoPaste) {
        Start-Sleep -Milliseconds $AutoPasteDelayMs
        [System.Windows.Forms.SendKeys]::SendWait("^v")
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        Write-Host "Sent Ctrl+V and Enter."
    }

    if ($CopyNameAfterCode) {
        $nameAnswer = Read-Host "After WARNO accepts the code, press Enter to copy the deck name, or type s to skip"
        if ($nameAnswer -ne "s") {
            Set-Clipboard -Value $row.name
            Write-Host "Copied deck name: $($row.name)"
        }
    }
}

Write-Host "Done."
