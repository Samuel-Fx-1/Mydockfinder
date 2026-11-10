[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [string]$DockPath,

    [Parameter(Mandatory = $false)]
    [switch]$EnableAutoHide,

    [Parameter(Mandatory = $false)]
    [switch]$InstallFont
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
    throw 'USERPROFILE is not set. This kit needs a normal Windows user profile.'
}
if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    throw 'LOCALAPPDATA is not set. This kit needs a normal Windows user profile.'
}

$script:DataRoot = Join-Path $env:LOCALAPPDATA 'MacThemeKit'
$script:BackupDir = Join-Path $script:DataRoot 'backup'
$script:LogPath = Join-Path $script:DataRoot 'setup.log'

if (-not (Test-Path -LiteralPath $script:DataRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $script:BackupDir -PathType Container)) {
    New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$script:IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isWhatIf = [bool]$WhatIfPreference

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DRY')][string]$Level = 'INFO'
    )

    $line = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8

    switch ($Level) {
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'DRY' { Write-Host $line -ForegroundColor DarkCyan }
        default { Write-Host $line }
    }
}

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host "== $Title ==" -ForegroundColor Cyan
}

function Get-RegistrySnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $snapshot = [ordered]@{
        Path    = $Path
        Name    = $Name
        Existed = $false
        Type    = $null
        Value   = $null
    }

    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($key.GetValueNames() -contains $Name) {
            $snapshot.Existed = $true
            $kind = $key.GetValueKind($Name).ToString()
            $snapshot.Type = $kind

            $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($kind -eq 'Binary') {
                $snapshot.Value = [Convert]::ToBase64String([byte[]]$value)
            }
            else {
                $snapshot.Value = $value
            }
        }
    }
    catch {
        # The key does not exist, so there is no original value to save.
    }

    return [pscustomobject]$snapshot
}

function Save-StepBackup {
    param(
        [Parameter(Mandatory = $true)][string]$Step,
        [Parameter(Mandatory = $true)][object[]]$Changes
    )

    $backupPath = Join-Path $script:BackupDir ($Step + '.json')
    if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
        Write-Log "Keeping the existing backup for '$Step': $backupPath"
        return $backupPath
    }

    $document = [ordered]@{
        schemaVersion = 1
        step          = $Step
        createdUtc    = (Get-Date).ToUniversalTime().ToString('o')
        changes       = @($Changes)
    }

    $json = $document | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $backupPath -Value $json -Encoding UTF8
    Write-Log "Saved original values before changing '$Step': $backupPath"
    return $backupPath
}

function Set-RegistryValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $false)]$Value,
        [Parameter(Mandatory = $true)][string]$Type
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    $key = Get-Item -LiteralPath $Path
    if ($key.GetValueNames() -contains $Name) {
        Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type $Type
    }
    else {
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type | Out-Null
    }
}

function Invoke-RegistryStep {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true)][string]$Step,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][hashtable[]]$Values,
        [Parameter(Mandatory = $false)][bool]$AdminRequired = $false
    )

    Write-Step $Description
    Write-Log ("Step '{0}' | admin_required={1}" -f $Description, $AdminRequired)

    if ($AdminRequired -and -not $script:IsAdmin) {
        Write-Log 'This step may require Administrator. The script will not elevate itself.' -Level WARN
    }

    $snapshots = @()
    foreach ($value in $Values) {
        $snapshots += Get-RegistrySnapshot -Path $value.Path -Name $value.Name
    }

    if ($isWhatIf) {
        foreach ($value in $Values) {
            $displayValue = $value.Value
            if ($value.Type -eq 'Binary') {
                $displayValue = 'binary data'
            }
            Write-Log ("WHATIF set {0}\{1} = {2} ({3})" -f $value.Path, $value.Name, $displayValue, $value.Type) -Level DRY
        }
        return
    }

    Save-StepBackup -Step $Step -Changes $snapshots | Out-Null

    foreach ($value in $Values) {
        $target = $value.Path + '\' + $value.Name
        if ($PSCmdlet.ShouldProcess($target, 'Set the selected MyDockFinder theme value')) {
            Set-RegistryValue -Path $value.Path -Name $value.Name -Value $value.Value -Type $value.Type
            Write-Log "Applied: $target"
        }
        else {
            Write-Log "Skipped by confirmation: $target" -Level WARN
        }
    }
}

function Test-DockPath {
    if ([string]::IsNullOrWhiteSpace($DockPath)) {
        Write-Log 'No -DockPath supplied. The appearance changes do not require it.'
        return
    }

    if (-not (Test-Path -LiteralPath $DockPath -PathType Container)) {
        throw "The -DockPath folder does not exist: $DockPath"
    }

    Write-Log "Validated -DockPath folder: $DockPath"
}

Write-Host 'MacThemeKit setup'
Write-Host 'Preview with -WhatIf before changing anything.'
Write-Host 'This script never elevates itself.'
Write-Log ("Setup started | admin={0} | whatif={1}" -f $script:IsAdmin, [bool]$isWhatIf)

Test-DockPath

Invoke-RegistryStep -Step 'dark-mode' -Description 'Dark mode' -AdminRequired $false -Values @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Value = [int]0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; Value = [int]0; Type = 'DWord' }
)

Invoke-RegistryStep -Step 'accent-color' -Description 'Accent color' -AdminRequired $false -Values @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'AccentColor'; Value = ([Convert]::ToUInt32('FF0A84FF', 16)); Type = 'DWord' }
)

Invoke-RegistryStep -Step 'desktop-icons' -Description 'Show desktop icons' -AdminRequired $false -Values @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideIcons'; Value = [int]0; Type = 'DWord' }
)

if ($EnableAutoHide) {
    Write-Step 'Taskbar auto-hide'
    Write-Log 'Taskbar auto-hide | admin_required=False'

    $stuckRectsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    $stuckRects = Get-ItemProperty -Path $stuckRectsPath -Name Settings -ErrorAction SilentlyContinue
    if ($null -eq $stuckRects -or $null -eq $stuckRects.Settings) {
        Write-Log 'Skipped taskbar auto-hide: Settings was not found. Change it in Windows Settings instead.' -Level WARN
    }
    else {
        $settingsBytes = [byte[]]$stuckRects.Settings
        if ($settingsBytes.Length -le 8) {
            Write-Log 'Skipped taskbar auto-hide: Settings has an unexpected format. Change it in Windows Settings instead.' -Level WARN
        }
        else {
            $modifiedSettings = [byte[]]$settingsBytes.Clone()
            $modifiedSettings[8] = [byte]($modifiedSettings[8] -bor 1)

            Invoke-RegistryStep -Step 'taskbar-autohide' -Description 'Taskbar auto-hide' -AdminRequired $false -Values @(
                @{ Path = $stuckRectsPath; Name = 'Settings'; Value = $modifiedSettings; Type = 'Binary' }
            )

            Write-Log 'Taskbar auto-hide requires an Explorer restart or a sign-out to refresh. Explorer was not restarted.' -Level WARN
        }
    }
}
else {
    Write-Log 'Taskbar auto-hide: skipped (use -EnableAutoHide to opt in).'
}

if ($InstallFont) {
    Write-Step 'Inter font (optional)'
    Write-Log 'Inter was requested, but no winget package with a verified official source was found. No download or install will be performed.' -Level WARN
    Write-Log 'Admin required for a manual "Install for all users" font install: yes. The script does not elevate.' -Level WARN
    Write-Host 'Official source: https://rsms.me/inter/'
    Write-Host 'Manual steps:'
    Write-Host '  1. Open https://rsms.me/inter/ in a browser.'
    Write-Host '  2. Download the official Inter release and extract it.'
    Write-Host '  3. Select Inter.ttc, InterVariable.ttf, and InterVariable-Italic.ttf.'
    Write-Host '  4. Right-click the selected files and choose "Install for all users".'
    Write-Host '  5. Read docs\MANUAL-STEPS.md for the same steps and license notes.'
    Write-Log 'Printed the official Inter link and manual steps. No files were downloaded.'
}
else {
    Write-Log 'Inter font: skipped (optional and off by default).'
}

Write-Log 'Setup finished.'
Write-Host ''
Write-Host 'Setup finished. Review the log at:'
Write-Host ('  ' + $script:LogPath)
Write-Host 'Use Revert-MacTheme.ps1 -WhatIf to preview a restore.'
