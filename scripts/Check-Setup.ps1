[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DockPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
    throw 'USERPROFILE is not set. This kit needs a normal Windows user profile.'
}
if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    throw 'LOCALAPPDATA is not set. This kit needs a normal Windows user profile.'
}

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host "== $Title ==" -ForegroundColor Cyan
}

function Write-Value {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $false)]$Value
    )
    Write-Host ('{0,-30} {1}' -f ($Label + ':'), $Value)
}

function Format-YesNo {
    param([Parameter(Mandatory = $false)]$Value)
    if ($null -eq $Value) {
        return 'Unknown'
    }
    if ($Value) {
        return 'Yes'
    }
    return 'No'
}

function Get-DockExecutableNames {
    return @(
        'MyDock.exe',
        'Dock_64.exe',
        'Dock.exe',
        'Dockmod.exe',
        'Dockmod64.exe',
        'ScreenRound.exe',
        'UiAccess.exe'
    )
}

function Get-DockExecutablesInFolder {
    param([Parameter(Mandatory = $false)][string]$Folder)

    if ([string]::IsNullOrWhiteSpace($Folder)) {
        return @()
    }

    $found = @()
    foreach ($name in (Get-DockExecutableNames)) {
        $candidate = Join-Path $Folder $name
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $found += $candidate
        }
    }
    return @($found)
}

function Get-SteamRoots {
    $roots = New-Object 'System.Collections.Generic.List[string]'

    $registryCandidates = @(
        @{ Path = 'HKCU:\Software\Valve\Steam'; Name = 'SteamPath' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'; Name = 'InstallPath' },
        @{ Path = 'HKLM:\SOFTWARE\Valve\Steam'; Name = 'InstallPath' }
    )

    foreach ($entry in $registryCandidates) {
        try {
            $item = Get-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction Stop
            $candidate = $item.($entry.Name)
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $candidate = [Environment]::ExpandEnvironmentVariables($candidate)
                if (-not $roots.Contains($candidate)) {
                    $roots.Add($candidate)
                }
            }
        }
        catch {
            # This Steam registry location is not present.
        }
    }

    $initialRoots = @($roots.ToArray())
    foreach ($root in $initialRoots) {
        $libraryFile = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $libraryFile -PathType Leaf) {
            try {
                $text = Get-Content -LiteralPath $libraryFile -Raw -ErrorAction Stop
                foreach ($match in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                    $libraryPath = $match.Groups[1].Value.Replace('\\', '\')
                    if (-not [string]::IsNullOrWhiteSpace($libraryPath) -and -not $roots.Contains($libraryPath)) {
                        $roots.Add($libraryPath)
                    }
                }
            }
            catch {
                # A malformed Steam library file is reported by Steam itself.
            }
        }
    }

    return @($roots.ToArray())
}

function Find-SteamInstall {
    foreach ($root in (Get-SteamRoots)) {
        $commonFolder = Join-Path $root 'steamapps\common\MyDockFinder'
        if (Test-Path -LiteralPath $commonFolder -PathType Container) {
            return [pscustomobject]@{
                Path   = $commonFolder
                Source = 'Steam library'
            }
        }

        $manifest = Join-Path $root 'steamapps\appmanifest_1787090.acf'
        if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            try {
                $manifestText = Get-Content -LiteralPath $manifest -Raw -ErrorAction Stop
                $match = [regex]::Match($manifestText, '"installdir"\s+"([^"]+)"')
                if ($match.Success) {
                    $installFolder = Join-Path $root ('steamapps\common\' + $match.Groups[1].Value)
                    if (Test-Path -LiteralPath $installFolder -PathType Container) {
                        return [pscustomobject]@{
                            Path   = $installFolder
                            Source = 'Steam appmanifest 1787090'
                        }
                    }
                }
            }
            catch {
                # Ignore an unreadable manifest; the folder check above may still work.
            }
        }
    }

    return $null
}

function Get-TaskbarAutoHideState {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    $item = Get-ItemProperty -Path $path -Name Settings -ErrorAction SilentlyContinue
    if ($null -eq $item -or $null -eq $item.Settings) {
        return $null
    }

    $bytes = [byte[]]$item.Settings
    if ($bytes.Length -le 8) {
        return $null
    }

    return (($bytes[8] -band 1) -ne 0)
}

function Get-DisplayInfo {
    if (-not ('MacThemeKit.DisplayInfo' -as [type])) {
        Add-Type -TypeDefinition @'
namespace MacThemeKit {
    public static class DisplayInfo {
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern int GetSystemMetrics(int nIndex);

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref RECT pvParam, uint fWinIni);

        [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
        public struct RECT {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }
    }
}
'@
    }

    try {
        [MacThemeKit.DisplayInfo]::SetProcessDPIAware() | Out-Null
    }
    catch {
        # Some hosts have already set DPI awareness.
    }

    $width = [MacThemeKit.DisplayInfo]::GetSystemMetrics(0)
    $height = [MacThemeKit.DisplayInfo]::GetSystemMetrics(1)

    $rect = New-Object MacThemeKit.DisplayInfo+RECT
    $workArea = [MacThemeKit.DisplayInfo]::SystemParametersInfo(0x0030, 0, [ref]$rect, 0)

    if ($workArea) {
        $workWidth = $rect.Right - $rect.Left
        $workHeight = $rect.Bottom - $rect.Top
    }
    else {
        $workWidth = $null
        $workHeight = $null
    }

    return [pscustomobject]@{
        Width      = $width
        Height     = $height
        WorkWidth  = $workWidth
        WorkHeight = $workHeight
    }
}

Write-Host 'MacThemeKit - read-only environment check'
Write-Host 'This script changes nothing.'
Write-Host ('Run time: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Write-Section 'Windows'
$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($null -ne $os) {
    $build = [int]$os.BuildNumber
    Write-Value 'Name' $os.Caption
    Write-Value 'Version' $os.Version
    Write-Value 'Build' $os.BuildNumber
    Write-Value 'Architecture' $os.OSArchitecture
    Write-Value 'Windows 11' (Format-YesNo ($build -ge 22000))
}
else {
    Write-Value 'Windows' 'Could not read Win32_OperatingSystem'
}

Write-Section 'Display'
$display = Get-DisplayInfo
Write-Value 'Screen size' (('{0} x {1}' -f $display.Width, $display.Height))
if ($null -ne $display.WorkWidth) {
    Write-Value 'Work area' (('{0} x {1}' -f $display.WorkWidth, $display.WorkHeight))
}
else {
    Write-Value 'Work area' 'Could not read the work area'
}

$dpi = 96
$desktop = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name LogPixels -ErrorAction SilentlyContinue
if ($null -ne $desktop -and $null -ne $desktop.LogPixels -and [int]$desktop.LogPixels -gt 0) {
    $dpi = [int]$desktop.LogPixels
}
$scaleMap = @{
    96  = '100%'
    120 = '125%'
    144 = '150%'
    168 = '175%'
    192 = '200%'
    216 = '225%'
    240 = '250%'
    288 = '300%'
    384 = '400%'
}
$scale = $scaleMap[$dpi]
if ($null -eq $scale) {
    $scale = 'custom'
}
Write-Value 'DPI' (('{0} ({1})' -f $dpi, $scale))

Write-Section 'Taskbar'
$autoHide = Get-TaskbarAutoHideState
if ($null -eq $autoHide) {
    Write-Value 'Auto-hide' 'Unknown (registry value not found or not readable)'
}
else {
    Write-Value 'Auto-hide' (Format-YesNo $autoHide)
}

Write-Section 'MyDockFinder'
$dockInstall = Find-SteamInstall
$dockFolder = $null
$dockSource = $null

if ($null -ne $dockInstall) {
    $dockFolder = $dockInstall.Path
    $dockSource = $dockInstall.Source
}
elseif (-not [string]::IsNullOrWhiteSpace($DockPath)) {
    if (Test-Path -LiteralPath $DockPath -PathType Container) {
        $dockFolder = $DockPath
        $dockSource = 'DockPath parameter'
    }
    else {
        Write-Value 'DockPath' 'Supplied path is not an existing folder'
    }
}

if (-not [string]::IsNullOrWhiteSpace($dockFolder)) {
    $dockExecutables = @(Get-DockExecutablesInFolder -Folder $dockFolder)
    if ($dockExecutables.Count -gt 0) {
        Write-Value 'Installed' 'Yes'
    }
    else {
        Write-Value 'Installed' 'Unconfirmed (folder found, known executable not found)'
    }
    Write-Value 'Detected from' $dockSource
    Write-Value 'Folder' $dockFolder
    if ($dockExecutables.Count -gt 0) {
        Write-Value 'Executables found' $dockExecutables.Count
        foreach ($executable in $dockExecutables) {
            Write-Host ('  ' + $executable)
        }
    }
    else {
        Write-Value 'Executables found' 'None of the known names were found'
    }
}
else {
    Write-Value 'Installed' 'No'
    Write-Value 'Next step' 'Use -DockPath if the Steam library was not detected'
}

Write-Section 'Dock processes'
$exeNames = Get-DockExecutableNames
$allProcesses = @(Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue)
$dockProcesses = @($allProcesses | Where-Object { $null -ne $_.Name -and ($exeNames -contains $_.Name) })
if ($dockProcesses.Count -eq 0) {
    Write-Value 'Running' 'No'
}
else {
    Write-Value 'Running' 'Yes'
    foreach ($process in $dockProcesses) {
        $processPath = $process.ExecutablePath
        if ([string]::IsNullOrWhiteSpace($processPath)) {
            $processPath = '(path not readable)'
        }
        Write-Host ('  PID {0,-8} {1}  {2}' -f $process.ProcessId, $process.Name, $processPath)
    }
}

Write-Section 'MyDock service'
$services = @(Get-Service -Name 'MyDock*' -ErrorAction SilentlyContinue)
if ($services.Count -eq 0) {
    Write-Value 'Service found' 'No'
}
else {
    Write-Value 'Service found' 'Yes'
    foreach ($service in $services) {
        Write-Value $service.Name (('{0} / {1}' -f $service.Status, $service.StartType))
    }
}

Write-Host ''
Write-Host 'Read-only check complete. No settings were changed.'
