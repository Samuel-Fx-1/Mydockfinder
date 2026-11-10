# Troubleshooting

Start by running the read-only check:

```powershell
.\scripts\Check-Setup.ps1
```

It reports the Windows version, display size and work area, taskbar auto-hide state, MyDockFinder detection, dock processes, and any matching service. It does not change settings.

## There is a gap at the bottom of the screen

A bottom gap usually comes from reserved dock space, display scaling, or more than one dock process.

1. Open MyDockFinder's settings.
2. Find the **Reserve screen space** or **Reserve space for the dock** option.
3. Turn it off, apply, and maximize a window.
4. If the gap remains, turn it on and off again to refresh the setting.
5. Check the Windows display scale in **Settings > System > Display**. A non-default scale can make a correctly reserved work area look larger than expected.
6. Run `Check-Setup.ps1` and compare **Screen size** with **Work area**. A smaller work area is expected when the taskbar or dock reserves space.
7. Sign out and back in, or restart Explorer from Task Manager. Do not terminate random processes; restart Explorer only.
8. If the gap is still there, look for a second dock process or an old installation and follow the next section.

## Two docks appear

1. Open Task Manager and look for more than one dock process.
2. Quit the extra dock from its own tray menu or settings window first.
3. Check **Settings > Apps > Startup** and Task Manager's **Startup apps** page for duplicate MyDockFinder entries.
4. Check whether an old copy was installed in another folder. Remove any unofficial copy of MyDockFinder and keep only the copy installed from the official Steam page.
5. If both docks belong to the same installation, exit the app completely and start it again once. Do not run two instances at the same time.

The kit does not install, copy, or launch MyDockFinder, so it cannot create a second dock by itself.

## The dock does not start with Windows

1. Open MyDockFinder's settings and look for **Start with Windows**, **Launch at login**, or a similar option. Enable it there first.
2. Open **Settings > Apps > Startup** and make sure MyDockFinder is allowed to start.
3. Open Task Manager's **Startup apps** tab and check that the MyDockFinder entry is enabled.
4. If the app has a service, open **Services** and check whether it is running. Do not change a service's startup type unless the app's documentation tells you to.
5. Start the app once manually. Some versions only create their startup entry after the first successful run.
6. If Windows blocks the app at startup, check Windows Security's protection history and restore it only if you trust the official installation.

## A dock keeps restarting

1. Use the dock's own **Quit** or **Exit** command. Closing the visible dock window may not stop the background process.
2. Open Task Manager, find the dock process, and choose **End task**.
3. Check **Settings > Apps > Startup** and the **Startup apps** tab for an entry that starts it again.
4. Check **Task Scheduler** for a MyDockFinder task only if you or the installer created one. Do not delete unrelated tasks.
5. If a second copy exists, remove the unofficial copy of MyDockFinder. A duplicate installation can make it look as though the dock is restarting itself.
6. Restart Windows once, then start only the official installation.
7. If it still restarts, collect the `Check-Setup.ps1` output and the app's version number, then ask in the app's official support channel. The kit's maintainer cannot fix MyDockFinder itself.

## The setup script is blocked by the execution policy

Use a process-scoped policy for the current PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Check-Setup.ps1
```

This does not change the machine-wide policy. Do not use `irm ... | iex`, and do not paste scripts from chat into an elevated shell.

## A setting did not change

1. Open `%LOCALAPPDATA%\MacThemeKit\setup.log` and check which step ran.
2. Re-run with `-WhatIf` to confirm the planned values.
3. Sign out and back in, or restart Explorer, for appearance changes that Windows caches.
4. Use `Revert-MacTheme.ps1 -WhatIf` to see which original values were saved.
5. Do not edit the JSON backups by hand unless you understand the registry value types.

## Something looks like a security problem

Read [../SECURITY.md](../SECURITY.md). Do not post credentials, tokens, or personal information in a public issue.
