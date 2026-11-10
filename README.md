# MacThemeKit for MyDockFinder

MacThemeKit is a small Windows 11 setup kit that applies a macOS-like appearance and walks you through the MyDockFinder dock settings that are not automated yet.

## What this kit is — and is not

- **It is** a collection of our own PowerShell scripts and documentation.
- **It is not** MyDockFinder, and it does not contain any MyDockFinder files, installers, or binaries.
- It is not affiliated with the developer of MyDockFinder.
- It does not include wallpapers, cursors, icons, fonts, or audio files. Those must be obtained from their official sources.

MyDockFinder must be bought and installed separately from its official Steam page: [MyDockFinder on Steam](https://store.steampowered.com/app/1787090/) (app **1787090**).

## License scope

The MIT license in this repository covers **only this kit's scripts and documentation**. It does **not** cover MyDockFinder, which has its own terms and must be obtained from its official Steam page.

## Requirements

- Windows 11.
- MyDockFinder purchased and installed from the official Steam page (app 1787090).
- Windows PowerShell 5.1 or later.
- The kit extracted to a normal folder. Do not run it from inside another application's install folder.

## Install and verify

1. Download the release ZIP from this repository's Releases page.
2. Verify the ZIP's SHA-256 checksum against `SHA256SUMS.txt` before extracting it:

   ```powershell
   Get-FileHash .\MacThemeKit-v1.0.0.zip -Algorithm SHA256
   Get-Content .\SHA256SUMS.txt
   ```

   The hash printed by `Get-FileHash` must match the hash in `SHA256SUMS.txt`. If it does not match, stop and download the release again.

3. Extract the ZIP to a folder you control.
4. Review every script in `scripts\` in a text editor before running anything. In particular, check the backup path, registry paths, and the commands that would be run.
5. Open Windows PowerShell in the extracted folder and run the read-only check:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Check-Setup.ps1
   ```

   If automatic Steam detection fails, pass the MyDockFinder folder explicitly:

   ```powershell
   .\scripts\Check-Setup.ps1 -DockPath "$env:USERPROFILE\path\to\MyDockFinder"
   ```

6. Preview the appearance changes:

   ```powershell
   .\scripts\Setup-MacTheme.ps1 -WhatIf
   ```

   Add `-DockPath` if you want the script to validate a specific MyDockFinder folder:

   ```powershell
   .\scripts\Setup-MacTheme.ps1 -WhatIf -DockPath "$env:USERPROFILE\path\to\MyDockFinder"
   ```

7. Run the setup for real:

   ```powershell
   .\scripts\Setup-MacTheme.ps1
   ```

   Optional switches:

   ```powershell
   .\scripts\Setup-MacTheme.ps1 -EnableAutoHide
   .\scripts\Setup-MacTheme.ps1 -InstallFont
   ```

   `-EnableAutoHide` changes the Windows taskbar auto-hide setting. Explorer may need to be restarted or you may need to sign out and back in before the change is visible. The script does not restart Explorer for you.

   `-InstallFont` is optional and off by default. At the time of this release, no Inter package with a verified official source was found in winget. When `-InstallFont` is passed, the script prints the official Inter link and the manual installation steps, and it downloads nothing. See `docs\MANUAL-STEPS.md` for the manual steps.

## Safety warning

**Never run a script with `irm ... | iex`.** That pattern executes downloaded text without letting you inspect it. Download the release, verify the checksum, read the scripts, and run the local files deliberately.

The setup script marks steps that need administrator rights and never elevates itself. If you need to install fonts for all users, Windows may show a UAC prompt during the manual font installation; review the prompt before accepting it.

The kit does not modify MyDockFinder's own files. Use MyDockFinder's built-in settings for dock behavior.

## How to revert

Preview the revert:

```powershell
.\scripts\Revert-MacTheme.ps1 -WhatIf
```

Then restore the values that were saved during setup:

```powershell
.\scripts\Revert-MacTheme.ps1
```

The revert script reads JSON backups under `%LOCALAPPDATA%\MacThemeKit\backup` and restores each original value exactly. It skips anything that is not in the backup and leaves unknown settings untouched. It never writes Windows defaults over a value that was not backed up.

If you installed Inter manually, uninstall it through **Settings > Apps** or the font's own uninstall option. The kit does not silently remove fonts.

## Manual dock steps

These settings are **manual until they are verified against the current MyDockFinder version**. Menu names can vary by release. See [docs/MANUAL-STEPS.md](docs/MANUAL-STEPS.md) for click-by-click notes.

- Auto-hide the dock.
- Hide the dock when a window is maximized or full screen.
- Reserve screen space for the dock (or turn reservation off to remove a bottom gap).
- Pin applications to the dock.
- Install Inter from the official source if you want the intended typeface.

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for a bottom gap, two docks, starting with Windows, and a dock that keeps restarting.

## Contributors

- **Samuel-Fx-1** — maintainer.
- See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Built with

Built with **Claude**, **opencode**, and **Freebuff**. These are the tools used to build the kit. They are not GitHub contributors, and commits are made under the repository owner's GitHub account.

## Credits

- **MyDockFinder** — by its developer. Buy it from the official Steam page; this kit does not redistribute it.
- **Inter** — by Rasmus Andersson and the Inter Project Authors, under the SIL Open Font License. The official source is [https://rsms.me/inter/](https://rsms.me/inter/). No font files are included in this kit.
- **PowerToys** and **Rainmeter** — optional, and available from their official sources. They are not required by this kit and are not bundled with it.

## Security

Please read [SECURITY.md](SECURITY.md) before reporting a security problem. Do not post credentials or personal information in a public issue.
