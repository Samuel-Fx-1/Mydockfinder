# Manual steps

These settings are **manual until they are verified against your installed MyDockFinder version**. Menu names and locations can change between releases. Use the closest matching label if yours is different.

The kit's scripts do not edit MyDockFinder's own files. Make these changes in the app's own settings window.

## Before you start

1. Buy and install MyDockFinder from its official Steam page: [app 1787090](https://store.steampowered.com/app/1787090/).
2. Start MyDockFinder.
3. Right-click the dock and choose **Settings**, **Preferences**, or the similarly named menu item. If there is no right-click menu, open the MyDockFinder tray icon and choose its settings entry.

The exact page names below are examples. A version may call them **General**, **Dock**, **Behavior**, **Appearance**, or something similar.

## Auto-hide the dock

1. Open MyDockFinder's settings.
2. Open the **Dock** or **General** page.
3. Find **Auto-hide**, **Automatically hide the dock**, or **Hide the dock when not in use**.
4. Turn it on.
5. Move the mouse to the screen edge where the dock appears and confirm that it comes back.

If the dock hides but leaves a gap, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Hide the dock when a window is maximized or full screen

1. Open the **Behavior**, **General**, or **Dock** page.
2. Find the option named **Hide when a window is maximized**, **Hide in full screen**, or similar.
3. If the app separates maximized windows and full-screen apps into two options, enable both.
4. Maximize a normal window, then open a full-screen video or game, and check that the dock stays out of the way.

Your version may only offer one of these options. That is normal.

## Reserved space and the bottom gap

1. Open the **Dock**, **Position**, or **Screen** page.
2. Find **Reserve screen space**, **Reserve space for the dock**, or **Use work area**.
3. Turn reservation **on** if you want maximized windows to stop above the dock.
4. Turn reservation **off** if you want maximized windows to use the full screen, or if the dock is auto-hidden and leaves an empty strip at the bottom.
5. Apply the change and look at a maximized window.

If turning the option off leaves a gap, sign out and back in, or restart Explorer from Task Manager. See the troubleshooting page if the gap remains.

## Pin applications to the dock

1. Open the application you want to keep.
2. Right-click its icon in the dock.
3. Choose **Keep in Dock**, **Pin to Dock**, or **Add to Dock**.
4. To remove a pinned app, right-click it and choose **Remove from Dock**, **Unpin**, or the matching option.
5. To reorder icons, drag them along the dock.

Dragging an application shortcut onto the dock may also work, depending on the MyDockFinder version.

## Install Inter manually (optional)

The setup script does not download or install fonts. At the time of this release, no Inter package with a verified official source was found in winget, so `-InstallFont` only prints these instructions.

1. Open the official Inter project page: [https://rsms.me/inter/](https://rsms.me/inter/).
2. Follow the official download link from that page.
3. Extract the downloaded archive to a temporary folder.
4. Select `Inter.ttc`, `InterVariable.ttf`, and `InterVariable-Italic.ttf`.
5. Right-click the selected files and choose **Install for all users**.
6. If Windows shows a UAC prompt, review it before accepting. The kit does not trigger this prompt for you.
7. Restart apps that were already open so they can see the new font.

Inter is distributed under the SIL Open Font License. Check the license file that comes with the official download. Do not install Inter from an unofficial font pack.

## Verify the result

1. Run `scripts\Check-Setup.ps1` to confirm the detected screen size, work area, and dock processes.
2. Check that the dock hides and returns, maximized windows do not overlap it, and pinned apps survive a restart.
3. If something is wrong, use the app's own reset or settings controls first. Do not replace MyDockFinder with an unofficial copy.
