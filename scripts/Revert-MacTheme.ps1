[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param()

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
    throw 'USERPROFILE is not set. This kit needs a normal Windows user profile.'
}
if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    throw 'LOCALAPPDATA is not set. This kit needs a normal Windows user profile.'
}

$script:DataRoot = Join-Path $env:LOCALAPPDATA 'MacThemeKit'
$script:BackupDir = Join-Path $script:DataRoot 'backup'
$script:LogPath = Join-Path $script:DataRoot 'revert.log'
$isWhatIf = [bool]$WhatIfPreference

if (-not (Test-Path -LiteralPath $script:DataRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null
}

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

Write-Host 'MacThemeKit revert'
Write-Host 'Only values present in the JSON backups are restored.'
Write-Host 'Anything not in a backup is left untouched.'
Write-Host 'Use -WhatIf to preview this restore.'
Write-Log ("Revert started | whatif={0}" -f [bool]$isWhatIf)

if (-not (Test-Path -LiteralPath $script:BackupDir -PathType Container)) {
    Write-Log 'No backup directory was found. Nothing was changed.' -Level WARN
    Write-Host ''
    Write-Host 'No backup directory was found. Nothing was changed.'
    return
}

$backupFiles = @(Get-ChildItem -LiteralPath $script:BackupDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
if ($backupFiles.Count -eq 0) {
    Write-Log 'No JSON backup files were found. Nothing was changed.' -Level WARN
    Write-Host ''
    Write-Host 'No JSON backup files were found. Nothing was changed.'
    return
}

$restoredCount = 0
$skippedCount = 0

foreach ($backupFile in $backupFiles) {
    Write-Host ''
    Write-Host ('== ' + $backupFile.Name + ' ==') -ForegroundColor Cyan

    try {
        $document = Get-Content -LiteralPath $backupFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
    }
    catch {
        Write-Log ("Skipped {0}: it is not valid JSON." -f $backupFile.Name) -Level WARN
        $skippedCount++
        continue
    }

    if ($null -eq $document -or $null -eq $document.schemaVersion -or [int]$document.schemaVersion -ne 1) {
        Write-Log ("Skipped {0}: unsupported or missing schemaVersion." -f $backupFile.Name) -Level WARN
        $skippedCount++
        continue
    }

    if ($null -eq $document.changes) {
        Write-Log ("Skipped {0}: it contains no changes." -f $backupFile.Name) -Level WARN
        $skippedCount++
        continue
    }

    foreach ($change in @($document.changes)) {
        if ($null -eq $change -or [string]::IsNullOrWhiteSpace($change.Path) -or [string]::IsNullOrWhiteSpace($change.Name) -or [string]::IsNullOrWhiteSpace($change.Type)) {
            Write-Log ("Skipped an incomplete entry in {0}." -f $backupFile.Name) -Level WARN
            $skippedCount++
            continue
        }

        $target = $change.Path + '\' + $change.Name
        $existed = [bool]$change.Existed

        if ($existed) {
            $valueToRestore = $change.Value
            if ($change.Type -eq 'Binary') {
                $valueToRestore = [Convert]::FromBase64String([string]$change.Value)
            }

            if ($isWhatIf) {
                Write-Log "WHATIF restore $target to its original value" -Level DRY
                continue
            }

            if ($PSCmdlet.ShouldProcess($target, 'Restore the original registry value')) {
                Set-RegistryValue -Path $change.Path -Name $change.Name -Value $valueToRestore -Type $change.Type
                Write-Log "Restored: $target"
                $restoredCount++
            }
            else {
                Write-Log "Skipped by confirmation: $target" -Level WARN
                $skippedCount++
            }
        }
        else {
            if ($isWhatIf) {
                Write-Log "WHATIF remove $target (it did not exist before setup)" -Level DRY
                continue
            }

            if ($PSCmdlet.ShouldProcess($target, 'Remove the value that did not exist before setup')) {
                if (Test-Path -LiteralPath $change.Path) {
                    $key = Get-Item -LiteralPath $change.Path
                    if ($key.GetValueNames() -contains $change.Name) {
                        Remove-ItemProperty -LiteralPath $change.Path -Name $change.Name
                        Write-Log "Removed: $target"
                        $restoredCount++
                    }
                    else {
                        Write-Log "Already absent: $target"
                    }
                }
                else {
                    Write-Log "Already absent: $target"
                }
            }
            else {
                Write-Log "Skipped by confirmation: $target" -Level WARN
                $skippedCount++
            }
        }
    }
}

Write-Host ''
if ($isWhatIf) {
    Write-Host 'Preview complete. No settings were changed.'
    Write-Log 'Preview complete. No settings were changed.'
}
else {
    Write-Host ("Restore complete. Applied: {0}; skipped: {1}." -f $restoredCount, $skippedCount)
    Write-Log ("Restore complete. Applied: {0}; skipped: {1}." -f $restoredCount, $skippedCount)
}
Write-Host 'Backup files were kept so the restore can be previewed or repeated.'
